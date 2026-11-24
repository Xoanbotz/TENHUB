--[[
============================================================
  TEN HUB Game Module: Cultivation Unbound
  Fitur: START → auto interact Shen + accept + kill mobs
============================================================
]]

local Players = game:GetService("Players")
local VU      = game:GetService("VirtualUser")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui")

local Game = {
    name    = "Cultivation Unbound",
    gameIds = { 110725234112010 },
}

function Game.build(window, ctx)
    local Logger = ctx.Logger
    local P      = ctx.GuiUtil.Palette

    local state = {
        running      = false,
        totalKills   = 0,
        questCleared = 0,
    }

    local CONFIG = {
        MOB_NAME      = "Core Disciple",
        ANCHOR_NAME   = "Anchor_CoreDisciple",
        MARKER_NAME   = "QuestTarget_CoreDisciple",
        SEARCH_RADIUS = 500,   -- radius besar buat deteksi mob
        ATTACK_REACH  = 3,
        KILL_TICK     = 0.05,
        LOOP_TICK     = 0.3,
        ACCEPT_RETRY  = 5,
    }

    local refs = { shen = nil, prompt = nil, anchor = nil }

    -- ============================================================
    -- REFS
    -- ============================================================
    local function findAnchor()
        local f = workspace:FindFirstChild("QuestTargetAnchors")
        if not f then return nil end
        local exact = f:FindFirstChild(CONFIG.ANCHOR_NAME)
        if exact then return exact end
        local key = CONFIG.MOB_NAME:lower():gsub("%s", "")
        for _, c in ipairs(f:GetChildren()) do
            if c.Name:lower():find(key, 1, true) then return c end
        end
        return nil
    end

    local function initRefs()
        pcall(function()
            refs.shen = workspace:FindFirstChild("Shen")
            if refs.shen then
                refs.prompt = refs.shen:FindFirstChild("QuestPrompt", true)
            end
            refs.anchor = findAnchor()
        end)
        return refs.shen ~= nil and refs.prompt ~= nil
    end

    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    -- ============================================================
    -- CARI MOB HIDUP (deteksi quest aktif alternatif)
    -- ============================================================
    local function countAliveMobs()
        local n = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower() == CONFIG.MOB_NAME:lower() then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then n = n + 1 end
            end
        end
        return n
    end

    local function isQuestActive()
        -- Cara 1: marker anchor
        if not refs.anchor then refs.anchor = findAnchor() end
        if refs.anchor then
            local marker = refs.anchor:FindFirstChild(CONFIG.MARKER_NAME)
            if marker and marker:IsA("BillboardGui") and marker.Enabled then
                return true
            end
        end
        -- Cara 2: ada mob hidup (fallback)
        return countAliveMobs() > 0
    end

    -- ============================================================
    -- INTERACT SHEN
    -- ============================================================
    local function fireQuestPrompt()
        if not refs.prompt then return false end
        local ok = pcall(function() fireproximityprompt(refs.prompt) end)
        if not ok then
            pcall(function()
                refs.prompt:InputHoldBegin()
                task.wait((refs.prompt.HoldDuration or 0) + 0.1)
                refs.prompt:InputHoldEnd()
            end)
        end
        return true
    end

    -- ============================================================
    -- ACCEPT DIALOG (multi-pattern, retry, agresif)
    -- ============================================================
    local function tryClickAccept()
        local keywords = {
            "accept", "terima", "ambil", "yes", "ok", "confirm",
            "start", "begin", "mulai", "iya", "yakin", "quest"
        }

        local function matches(txt)
            txt = (txt or ""):lower()
            for _, k in ipairs(keywords) do
                if txt:find(k, 1, true) then return true end
            end
            return false
        end

        -- 1) Legacy Dialog
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Dialog") and d.Enabled then
                for _, choice in ipairs(d:GetChildren()) do
                    if choice:IsA("DialogChoice") and matches(choice.UserDialog) then
                        local hum = player.Character
                            and player.Character:FindFirstChildOfClass("Humanoid")
                        if hum then
                            d:Show(hum, choice)
                            Logger.info("[ACCEPT] Legacy dialog: " .. choice.Name)
                            return true
                        end
                    end
                end
            end
        end

        -- 2) ScreenGui TextButton
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") and desc.Visible then
                        if matches(desc.Text) or matches(desc.Name) then
                            pcall(function() desc:Activate() end)
                            pcall(function()
                                if desc.MouseButton1Click then
                                    desc.MouseButton1Click:Fire()
                                end
                            end)
                            Logger.info("[ACCEPT] Button: " .. desc:GetFullName())
                            return true
                        end
                    end
                end
            end
        end

        -- 3) ImageButton dengan nama accept
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("ImageButton") and desc.Visible and matches(desc.Name) then
                        pcall(function() desc:Activate() end)
                        Logger.info("[ACCEPT] ImageButton: " .. desc:GetFullName())
                        return true
                    end
                end
            end
        end

        return false
    end

    local function acceptDialog()
        for attempt = 1, CONFIG.ACCEPT_RETRY do
            if not state.running then return false end
            task.wait(0.5)
            if tryClickAccept() then return true end
        end
        return false
    end

    -- ============================================================
    -- CARI & KILL MOB
    -- ============================================================
    local function findClosestMob()
        local hrp = getHRP()
        if not hrp then return nil end

        local anchorPos
        if refs.anchor then anchorPos = refs.anchor.Position end

        local closest, closestDist = nil, math.huge
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower() == CONFIG.MOB_NAME:lower() then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local mobHRP = obj:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and mobHRP then
                    -- Utamakan deket anchor kalau ada
                    local dist = anchorPos
                        and (mobHRP.Position - anchorPos).Magnitude
                        or (mobHRP.Position - hrp.Position).Magnitude
                    if dist < closestDist then
                        closest = obj
                        closestDist = dist
                    end
                end
            end
        end

        if closest and closestDist <= CONFIG.SEARCH_RADIUS then
            return closest
        end
        return nil
    end

    local function killMob(mob)
        local hits = 0
        while state.running and mob and mob.Parent do
            local hum = mob:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then break end

            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if not mobHRP or not hrp then break end

            -- Teleport ke mob (agresif, tiap hit)
            hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)

            -- Attack
            VU:Button1Down(Vector2.new())
            task.wait(0.05)
            VU:Button1Up(Vector2.new())
            task.wait(CONFIG.KILL_TICK)

            hits = hits + 1
            if hits > 200 then
                Logger.warn("[KILL] Mob nggak mati dalam 200 hit, skip")
                break
            end
        end

        pcall(function()
            local hum = mob and mob:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                state.totalKills = state.totalKills + 1
                Logger.success("[KILL] Mob killed. Total: " .. state.totalKills)
            end
        end)
    end

    -- ============================================================
    -- LOOP UTAMA
    -- ============================================================
    local function autoLoop()
        local wasActive = false
        local acceptAttempts = 0

        while state.running do
            pcall(function()
                initRefs()

                local active = isQuestActive()

                -- Quest complete detection
                if wasActive and not active then
                    state.questCleared = state.questCleared + 1
                    Logger.success(string.format(
                        "[AUTO] Quest #%d COMPLETE! Kills: %d",
                        state.questCleared, state.totalKills))
                    wasActive = false
                    acceptAttempts = 0
                    task.wait(1)
                    return
                end

                -- Quest nggak aktif → interact Shen + accept
                if not active then
                    if acceptAttempts < 3 then
                        Logger.info("[AUTO] Interact Shen + accept quest")
                        fireQuestPrompt()
                        acceptDialog()
                        acceptAttempts = acceptAttempts + 1
                    else
                        Logger.warn("[AUTO] Gagal accept 3x, retry...")
                        acceptAttempts = 0
                    end
                    task.wait(1)
                    return
                end

                -- Quest aktif → kill mobs
                wasActive = true
                acceptAttempts = 0

                local target = findClosestMob()
                if target then
                    Logger.info("[AUTO] Kill: " .. target.Name)
                    killMob(target)
                else
                    Logger.warn("[AUTO] Mob belum spawn")
                end
            end)

            task.wait(CONFIG.LOOP_TICK)
        end
    end

    -- ============================================================
    -- GUI
    -- ============================================================
    window:AddSection("Auto Quest — Cultivation Unbound")
    window:AddLabel("Quest Giver: Shen", P.TEXT)
    window:AddLabel("Target: Core Disciple", P.TEXT)

    local statusLabel = window:AddLabel("Status: IDLE", P.GRAY)
    local killsLabel  = window:AddLabel("Kills: 0", P.TEXT)
    local questsLabel = window:AddLabel("Quest cleared: 0", P.TEXT)

    task.spawn(function()
        while statusLabel and statusLabel.Parent do
            task.wait(0.5)
            if killsLabel and killsLabel.Parent then
                killsLabel.Text = "  Kills: " .. state.totalKills
            end
            if questsLabel and questsLabel.Parent then
                questsLabel.Text = "  Quest cleared: " .. state.questCleared
            end
        end
    end)

    window:AddButton("▶ START (Auto All)", function()
        if state.running then
            Logger.warn("[AUTO] Udah jalan")
            return
        end
        if not initRefs() then
            Logger.error("[AUTO] Shen/QuestPrompt nggak ketemu")
            if statusLabel then
                statusLabel.Text = "  Status: FAILED (Shen missing)"
                statusLabel.TextColor3 = P.ERROR
            end
            return
        end

        state.running = true
        Logger.success("[AUTO] ▶ STARTED — auto interact + kill")
        if statusLabel then
            statusLabel.Text = "  Status: RUNNING"
            statusLabel.TextColor3 = P.SUCCESS
        end
        task.spawn(autoLoop)
    end)

    window:AddButton("⏹ STOP", function()
        state.running = false
        Logger.info("[AUTO] ⏹ STOPPED")
        if statusLabel then
            statusLabel.Text = "  Status: STOPPED"
            statusLabel.TextColor3 = P.WARN
        end
    end)

    window:AddButton("🔍 Check Refs", function()
        initRefs()
        Logger.info(string.format(
            "Shen:%s prompt:%s anchor:%s mobsAlive:%d",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil),
            countAliveMobs()
        ))
        ctx.GuiUtil.Notify("TEN HUB", "Cek console", 2)
    end)

    window:AddButton("📋 Dump Active GUIs (debug dialog)", function()
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                Logger.info("GUI: " .. gui.Name)
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextButton") and d.Visible then
                        Logger.info("  [BTN] " .. d:GetFullName() .. " | " .. d.Text)
                    end
                end
            end
        end
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
