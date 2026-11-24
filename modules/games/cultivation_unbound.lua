--[[
============================================================
  TEN HUB Game Module: Cultivation Unbound
  Combat via CombatHit:FireServer(mob, combo 1-4)
============================================================
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
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
        combo        = 1,
        lastHitTime  = 0,
    }

    local CONFIG = {
        MOB_NAME         = "Core Disciple",
        ENEMIES_FOLDER   = "CultivatorCamps",   -- 🔥 path baru
        ANCHOR_NAME      = "Anchor_CoreDisciple",
        MARKER_NAME      = "QuestTarget_CoreDisciple",
        SEARCH_RADIUS    = 500,
        ATTACK_REACH     = 4,
        HIT_INTERVAL     = 0.35,   -- match observed
        LOOP_TICK        = 0.15,
        ACCEPT_RETRY     = 5,
        MAX_HITS_PER_MOB = 300,
    }

    -- === REFS ===
    local refs = { shen = nil, prompt = nil, anchor = nil, combatHit = nil }

    local function initRefs()
        pcall(function()
            refs.shen = workspace:FindFirstChild("Shen")
            if refs.shen then
                refs.prompt = refs.shen:FindFirstChild("QuestPrompt", true)
            end
            local f = workspace:FindFirstChild("QuestTargetAnchors")
            if f then
                refs.anchor = f:FindFirstChild(CONFIG.ANCHOR_NAME)
            end
            local events = RS:FindFirstChild("CultivationEvents")
            if events then
                refs.combatHit = events:FindFirstChild("CombatHit")
            end
        end)
        return refs.shen ~= nil and refs.combatHit ~= nil
    end

    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    -- === CARI MOB (path CultivatorCamps) ===
    local function findFolderMobs()
        local folder = workspace:FindFirstChild(CONFIG.ENEMIES_FOLDER)
        if not folder then return {} end

        local list = {}
        for _, obj in ipairs(folder:GetChildren()) do
            if obj:IsA("Model") and obj.Name:lower():find(
                CONFIG.MOB_NAME:lower(), 1, true) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    table.insert(list, obj)
                end
            end
        end
        return list
    end

    local function countAliveMobs()
        return #findFolderMobs()
    end

    local function isQuestActive()
        -- 1) marker
        if refs.anchor then
            local marker = refs.anchor:FindFirstChild(CONFIG.MARKER_NAME)
            if marker and marker:IsA("BillboardGui") and marker.Enabled then
                return true
            end
        end
        -- 2) fallback: ada mob hidup
        return countAliveMobs() > 0
    end

    local function findClosestMob()
        local hrp = getHRP()
        if not hrp then return nil end

        local closest, closestDist = nil, math.huge
        for _, mob in ipairs(findFolderMobs()) do
            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            if mobHRP then
                local d = (mobHRP.Position - hrp.Position).Magnitude
                if d < closestDist and d <= CONFIG.SEARCH_RADIUS then
                    closest = mob
                    closestDist = d
                end
            end
        end
        return closest
    end

    -- === ATTACK: CombatHit + combo counter ===
    local function attackMob(mob)
        if not mob or not mob.Parent then return false end
        local hrp = getHRP()
        local mobHRP = mob:FindFirstChild("HumanoidRootPart")
        if not hrp or not mobHRP then return false end

        -- Teleport deket mob (proximity, server cek range)
        hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)

        -- Fire CombatHit dengan combo number (1-4 rotate)
        local ok, err = pcall(function()
            refs.combatHit:FireServer(mob, state.combo)
        end)
        if not ok then
            Logger.warn("[ATTACK] FireServer error: " .. tostring(err))
            return false
        end

        -- Rotate combo 1→2→3→4→1
        state.combo = state.combo + 1
        if state.combo > 4 then state.combo = 1 end

        return true
    end

    -- === ACCEPT DIALOG ===
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

    local function tryClickAccept()
        local kws = {"accept", "terima", "ambil", "yes", "ok",
            "confirm", "start", "begin", "mulai", "iya", "yakin", "quest"}
        local function match(txt)
            txt = (txt or ""):lower()
            for _, k in ipairs(kws) do
                if txt:find(k, 1, true) then return true end
            end
            return false
        end

        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Dialog") and d.Enabled then
                for _, c in ipairs(d:GetChildren()) do
                    if c:IsA("DialogChoice") and match(c.UserDialog) then
                        local h = player.Character
                            and player.Character:FindFirstChildOfClass("Humanoid")
                        if h then d:Show(h, c); return true end
                    end
                end
            end
        end

        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, b in ipairs(gui:GetDescendants()) do
                    if (b:IsA("TextButton") or b:IsA("ImageButton"))
                       and b.Visible and (match(b.Name)
                       or (b:IsA("TextButton") and match(b.Text))) then
                        pcall(function() b:Activate() end)
                        pcall(function()
                            if b.MouseButton1Click then
                                b.MouseButton1Click:Fire()
                            end
                        end)
                        return true
                    end
                end
            end
        end
        return false
    end

    local function acceptDialog()
        for _ = 1, CONFIG.ACCEPT_RETRY do
            if not state.running then return false end
            task.wait(0.5)
            if tryClickAccept() then return true end
        end
        return false
    end

    -- === LOOP UTAMA ===
    local function autoLoop()
        local wasActive = false
        local acceptAttempts = 0

        while state.running do
            pcall(function()
                initRefs()
                local active = isQuestActive()

                -- quest complete
                if wasActive and not active then
                    state.questCleared = state.questCleared + 1
                    Logger.success(string.format(
                        "[AUTO] ✅ QUEST #%d COMPLETE! Kills: %d",
                        state.questCleared, state.totalKills))
                    wasActive = false
                    acceptAttempts = 0
                    state.combo = 1
                    task.wait(1.5)
                    return
                end

                -- ambil quest
                if not active then
                    if acceptAttempts < 3 then
                        Logger.info("[AUTO] Interact Shen + accept")
                        fireQuestPrompt()
                        acceptDialog()
                        acceptAttempts = acceptAttempts + 1
                    else
                        acceptAttempts = 0
                    end
                    task.wait(1)
                    return
                end

                -- kill mobs
                wasActive = true
                acceptAttempts = 0

                local target = findClosestMob()
                if target then
                    local mobHum = target:FindFirstChildOfClass("Humanoid")
                    if mobHum then
                        attackMob(target)
                        if mobHum.Health <= 0 then
                            state.totalKills = state.totalKills + 1
                            Logger.success("[KILL] ✔ Total: " .. state.totalKills)
                            state.combo = 1
                        end
                    end
                else
                    Logger.warn("[AUTO] Nggak ada mob, tunggu spawn")
                end
            end)

            task.wait(CONFIG.LOOP_TICK)
        end
    end

    -- ============================================================
    -- GUI
    -- ============================================================
    window:AddSection("Auto Quest — Cultivation Unbound")
    window:AddLabel("Giver: Shen | Target: Core Disciple (5x)", P.TEXT)

    local statusLabel = window:AddLabel("Status: IDLE", P.GRAY)
    local killsLabel  = window:AddLabel("Kills: 0", P.TEXT)
    local questsLabel = window:AddLabel("Quest cleared: 0", P.TEXT)
    local comboLabel  = window:AddLabel("Combo: 1", P.GRAY)

    task.spawn(function()
        while statusLabel and statusLabel.Parent do
            task.wait(0.5)
            if killsLabel and killsLabel.Parent then
                killsLabel.Text = "  Kills: " .. state.totalKills
            end
            if questsLabel and questsLabel.Parent then
                questsLabel.Text = "  Quest cleared: " .. state.questCleared
            end
            if comboLabel and comboLabel.Parent then
                comboLabel.Text = "  Combo: " .. state.combo
            end
        end
    end)

    window:AddButton("▶ START", function()
        if state.running then return end
        if not initRefs() then
            Logger.error("[AUTO] Refs missing (Shen/prompt/CombatHit)")
            return
        end
        state.running = true
        state.combo = 1
        Logger.success("[AUTO] ▶ STARTED")
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
            "Shen:%s prompt:%s anchor:%s CombatHit:%s mobsAlive:%d",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil),
            tostring(refs.combatHit ~= nil),
            countAliveMobs()
        ))
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
