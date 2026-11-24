--[[
============================================================
  TEN HUB Game Module: Cultivation Unbound
  Fitur: Auto Quest + Auto Kill (Shen → Core Disciple)
  Catatan: Anchor_CoreDisciple = quest marker (muncul saat quest aktif)
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
        SEARCH_RADIUS = 250,
        ATTACK_REACH  = 3,
        KILL_TICK     = 0.05,
        LOOP_TICK     = 0.3,
        ACCEPT_WAIT   = 1.5,
    }

    -- === REFS ===
    local refs = { shen = nil, prompt = nil, anchor = nil }

    -- Cari anchor secara fleksibel (nama exact atau contains)
    local function findAnchor()
        local anchorsFolder = workspace:FindFirstChild("QuestTargetAnchors")
        if not anchorsFolder then return nil end

        local exact = anchorsFolder:FindFirstChild(CONFIG.ANCHOR_NAME)
        if exact then return exact end

        local mobKey = CONFIG.MOB_NAME:lower():gsub("%s", "")
        for _, child in ipairs(anchorsFolder:GetChildren()) do
            if child.Name:lower():find(mobKey, 1, true) then
                return child
            end
        end
        return nil
    end

    -- Init refs. Anchor opsional (muncul saat quest aktif).
    local function initRefs()
        pcall(function()
            refs.shen = workspace:FindFirstChild("Shen")
            if refs.shen then
                refs.prompt = refs.shen:FindFirstChild("QuestPrompt", true)
            end
            refs.anchor = findAnchor()
        end)
        return refs.shen and refs.prompt
    end

    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function isQuestActive()
        if not refs.anchor then
            refs.anchor = findAnchor()
        end
        if not refs.anchor then return false end
        local marker = refs.anchor:FindFirstChild(CONFIG.MARKER_NAME)
        return marker and marker:IsA("BillboardGui") and marker.Enabled
    end

    local function fireQuestPrompt()
        if not refs.prompt then return end
        local ok = pcall(function() fireproximityprompt(refs.prompt) end)
        if not ok then
            pcall(function()
                refs.prompt:InputHoldBegin()
                task.wait(refs.prompt.HoldDuration + 0.1)
                refs.prompt:InputHoldEnd()
            end)
        end
    end

    local function acceptDialog()
        task.wait(CONFIG.ACCEPT_WAIT)

        -- Legacy Dialog
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Dialog") and d.Enabled then
                for _, choice in ipairs(d:GetChildren()) do
                    if choice:IsA("DialogChoice") then
                        local txt = (choice.UserDialog or ""):lower()
                        if txt:find("accept") or txt:find("ambil")
                           or txt:find("terima") or txt:find("yes")
                           or txt:find("ok") then
                            local hum = player.Character
                                and player.Character:FindFirstChildOfClass("Humanoid")
                            if hum then
                                d:Show(hum, choice)
                                return
                            end
                        end
                    end
                end
            end
        end

        -- Custom ScreenGui button
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") then
                        local txt = desc.Text:lower()
                        if txt:find("accept") or txt:find("ambil")
                           or txt:find("terima") or txt:find("yes")
                           or txt:find("ok") then
                            pcall(function() desc:Activate() end)
                            pcall(function() desc.MouseButton1Click:Fire() end)
                            return
                        end
                    end
                end
            end
        end
    end

    local function findTargetMob()
        if not refs.anchor then
            refs.anchor = findAnchor()
        end
        if not refs.anchor then return nil end

        local anchorPos = refs.anchor.Position
        local closest, closestDist = nil, CONFIG.SEARCH_RADIUS

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model")
               and obj.Name:lower() == CONFIG.MOB_NAME:lower() then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and hrp then
                    local dist = (hrp.Position - anchorPos).Magnitude
                    if dist < closestDist then
                        closest = obj
                        closestDist = dist
                    end
                end
            end
        end
        return closest
    end

    local function killMob(mob)
        local hits = 0
        while state.running and mob and mob.Parent do
            local hum = mob:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then break end

            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if not mobHRP or not hrp then break end

            hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)
            VU:Button1Down(Vector2.new())
            task.wait(0.05)
            VU:Button1Up(Vector2.new())
            task.wait(CONFIG.KILL_TICK)

            hits = hits + 1
            if hits > 100 then break end
        end

        pcall(function()
            local hum = mob and mob:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                state.totalKills = state.totalKills + 1
            end
        end)
    end

    local function autoLoop()
        local wasActive = false

        while state.running do
            pcall(function()
                if not initRefs() then
                    Logger.warn("[AUTO] Shen/prompt hilang, tunggu...")
                    return
                end

                local active = isQuestActive()

                if wasActive and not active then
                    state.questCleared = state.questCleared + 1
                    Logger.success(string.format(
                        "[AUTO] Quest #%d COMPLETE! Total kills: %d",
                        state.questCleared, state.totalKills))
                    wasActive = false
                end

                if not active then
                    fireQuestPrompt()
                    acceptDialog()
                    task.wait(2)
                    return
                end

                wasActive = true
                local target = findTargetMob()
                if target then
                    Logger.info("[AUTO] Killing: " .. target.Name)
                    killMob(target)
                else
                    Logger.warn("[AUTO] Mob target belum spawn")
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

    window:AddButton("▶ START Auto Quest", function()
        if state.running then
            Logger.warn("[AUTO] Udah jalan, stop dulu")
            return
        end

        -- Cek Shen + prompt aja. Anchor opsional.
        if not initRefs() then
            Logger.error("[AUTO] Shen/QuestPrompt belum ketemu")
            if statusLabel then
                statusLabel.Text = "  Status: FAILED (Shen missing)"
                statusLabel.TextColor3 = P.ERROR
            end
            return
        end

        state.running = true
        Logger.success("[AUTO] ▶ STARTED")
        if statusLabel then
            statusLabel.Text = "  Status: RUNNING"
            statusLabel.TextColor3 = P.SUCCESS
        end

        task.spawn(autoLoop)
    end)

    window:AddButton("⏹ STOP Auto Quest", function()
        if not state.running then
            Logger.warn("[AUTO] Belum jalan")
            return
        end
        state.running = false
        Logger.info("[AUTO] ⏹ STOPPED")
        if statusLabel then
            statusLabel.Text = "  Status: STOPPED"
            statusLabel.TextColor3 = P.WARN
        end
    end)

    window:AddButton("🔍 Check Refs", function()
        local basic = initRefs()
        Logger.info(string.format(
            "Shen:%s prompt:%s anchor:%s (anchor opsional)",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil)
        ))
        if basic then
            ctx.GuiUtil.Notify("TEN HUB", "Shen+Prompt OK", 2)
        else
            ctx.GuiUtil.Notify("TEN HUB", "Shen/Prompt missing", 3)
        end
    end)

    window:AddButton("📋 Dump Anchors", function()
        local anchors = workspace:FindFirstChild("QuestTargetAnchors")
        if not anchors then
            Logger.warn("QuestTargetAnchors folder nggak ada")
            return
        end
        Logger.info("=== QuestTargetAnchors children ===")
        for _, child in ipairs(anchors:GetChildren()) do
            Logger.info("  [" .. child.ClassName .. "] " .. child.Name)
        end
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
