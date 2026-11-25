
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
        running       = false,
        totalKills    = 0,
        questCleared  = 0,
        combo         = 1,
        lastAccept    = 0,
        acceptAttempts = 0,
    }

    local CONFIG = {
        MOB_NAME         = "Core Disciple",
        ENEMIES_FOLDER   = "CultivatorCamps",
        ANCHOR_NAME      = "Anchor_CoreDisciple",
        MARKER_NAME      = "QuestTarget_CoreDisciple",
        SEARCH_RADIUS    = 500,
        ATTACK_REACH     = 4,
        SHEN_REACH       = 5,      -- jarak deket Shen buat prompt
        HIT_INTERVAL     = 0.35,
        LOOP_TICK        = 0.15,
        ACCEPT_COOLDOWN  = 2.0,    -- jeda antar attempt accept (detik)
        ACCEPT_RETRY     = 5,      -- retry dalam 1 attempt
        MAX_HITS_PER_MOB = 300,
    }

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
            local ev = RS:FindFirstChild("CultivationEvents")
            if ev then
                refs.combatHit = ev:FindFirstChild("CombatHit")
            end
        end)
        return refs.shen and refs.prompt and refs.combatHit
    end

    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    -- ============================================================
    -- QUEST STATE: MARKER ONLY (no mob-alive fallback)
    -- ============================================================
    local function isQuestActive()
        if not refs.anchor then
            -- re-fetch
            local f = workspace:FindFirstChild("QuestTargetAnchors")
            if f then
                refs.anchor = f:FindFirstChild(CONFIG.ANCHOR_NAME)
            end
        end
        if not refs.anchor then return false end

        local marker = refs.anchor:FindFirstChild(CONFIG.MARKER_NAME)
        return marker and marker:IsA("BillboardGui") and marker.Enabled
    end

    -- ============================================================
    -- MOB FINDING
    -- ============================================================
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

    local function countAliveMobs() return #findFolderMobs() end

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

    -- ============================================================
    -- TELEPORT KE SHEN
    -- ============================================================
    local function teleportToShen()
        local hrp = getHRP()
        if not hrp or not refs.shen then return false end
        local shenRoot = refs.shen:FindFirstChild("HumanoidRootPart")
            or refs.shen:FindFirstChild("Torso")
            or refs.shen.PrimaryPart
            or refs.shen:FindFirstChildWhichIsA("BasePart", true)

        if not shenRoot then return false end

        hrp.CFrame = shenRoot.CFrame * CFrame.new(0, 0, -CONFIG.SHEN_REACH)
        task.wait(0.3)  -- tunggu posisi sync
        return true
    end

    -- ============================================================
    -- ATTACK
    -- ============================================================
    local function attackMob(mob)
        if not mob or not mob.Parent then return false end
        local hrp = getHRP()
        local mobHRP = mob:FindFirstChild("HumanoidRootPart")
        if not hrp or not mobHRP then return false end

        hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)

        local ok = pcall(function()
            refs.combatHit:FireServer(mob, state.combo)
        end)
        if not ok then return false end

        state.combo = state.combo + 1
        if state.combo > 4 then state.combo = 1 end
        return true
    end

    -- ============================================================
    -- ACCEPT DIALOG
    -- ============================================================
    local function tryClickAccept()
        local kws = {"accept", "terima", "ambil", "yes", "ok",
            "confirm", "start", "begin", "mulai", "iya", "yakin"}

        local function match(txt)
            txt = (txt or ""):lower()
            for _, k in ipairs(kws) do
                if txt:find(k, 1, true) then return true end
            end
            return false
        end

        -- Legacy Dialog
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Dialog") and d.Enabled then
                for _, c in ipairs(d:GetChildren()) do
                    if c:IsA("DialogChoice") and match(c.UserDialog) then
                        local h = player.Character
                            and player.Character:FindFirstChildOfClass("Humanoid")
                        if h then
                            d:Show(h, c)
                            Logger.info("[ACCEPT] Legacy dialog: " .. c.Name)
                            return true
                        end
                    end
                end
            end
        end

        -- GUI Button
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, b in ipairs(gui:GetDescendants()) do
                    if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Visible then
                        local txt = b:IsA("TextButton") and b.Text or ""
                        if match(txt) or match(b.Name) then
                            pcall(function() b:Activate() end)
                            pcall(function()
                                if b.MouseButton1Click then
                                    b.MouseButton1Click:Fire()
                                end
                            end)
                            Logger.info("[ACCEPT] Btn: " .. b:GetFullName()
                                .. " | " .. txt)
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function attemptAcceptQuest()
        -- Teleport ke Shen dulu
        if not teleportToShen() then
            Logger.warn("[ACCEPT] Nggak bisa teleport ke Shen")
            return false
        end

        -- Fire prompt
        local fireOk = pcall(function()
            fireproximityprompt(refs.prompt)
        end)
        if not fireOk then
            pcall(function()
                refs.prompt:InputHoldBegin()
                task.wait((refs.prompt.HoldDuration or 0) + 0.1)
                refs.prompt:InputHoldEnd()
            end)
        end
        Logger.info("[ACCEPT] QuestPrompt fired")

        -- Retry accept dialog
        for i = 1, CONFIG.ACCEPT_RETRY do
            if not state.running then return false end
            task.wait(0.6)
            if tryClickAccept() then
                Logger.success("[ACCEPT] ✅ Quest accepted")
                task.wait(1)  -- biar server kirim marker
                return true
            end
        end
        Logger.warn("[ACCEPT] ❌ Gagal accept setelah " .. CONFIG.ACCEPT_RETRY .. "x")
        return false
    end

    -- ============================================================
    -- LOOP UTAMA
    -- ============================================================
    local function autoLoop()
        local wasActive = false

        while state.running do
            pcall(function()
                initRefs()

                local active = isQuestActive()

                -- Quest complete
                if wasActive and not active then
                    state.questCleared = state.questCleared + 1
                    Logger.success(string.format(
                        "[AUTO] ✅ QUEST #%d COMPLETE! Kills: %d",
                        state.questCleared, state.totalKills))
                    wasActive = false
                    state.combo = 1
                    task.wait(1.5)
                    return
                end

                -- Ambil quest kalau belum aktif
                if not active then
                    -- Cooldown biar nggak spam
                    if tick() - state.lastAccept < CONFIG.ACCEPT_COOLDOWN then
                        return
                    end
                    state.lastAccept = tick()

                    Logger.info("[AUTO] Quest nggak aktif, ambil dari Shen")
                    attemptAcceptQuest()
                    return
                end

                -- Quest aktif → kill mobs
                wasActive = true

                local target = findClosestMob()
                if target then
                    local mobHum = target:FindFirstChildOfClass("Humanoid")
                    if mobHum then
                        attackMob(target)
                        if mobHum.Health <= 0 then
                            state.totalKills = state.totalKills + 1
                            Logger.success("[KILL] ✔ Total: " .. state.totalKills)
                            state.combo = 1
                            task.wait(0.3)
                        end
                    end
                else
                    local alive = countAliveMobs()
                    Logger.warn("[AUTO] Mob target nggak ada (alive: " .. alive .. ")")
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
    local phaseLabel  = window:AddLabel("Phase: -", P.GRAY)

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
            if phaseLabel and phaseLabel.Parent then
                local phase = "IDLE"
                if state.running then
                    phase = isQuestActive() and "KILLING" or "ACCEPTING"
                end
                phaseLabel.Text = "  Phase: " .. phase
            end
        end
    end)

    window:AddButton("▶ START", function()
        if state.running then return end
        if not initRefs() then
            Logger.error("[AUTO] Refs missing")
            return
        end
        state.running = true
        state.combo = 1
        state.lastAccept = 0
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
            "Shen:%s prompt:%s anchor:%s CombatHit:%s questActive:%s mobsAlive:%d",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil),
            tostring(refs.combatHit ~= nil),
            tostring(isQuestActive()),
            countAliveMobs()
        ))
    end)

    window:AddButton(" Force Accept (manual)", function()
        if not initRefs() then
            Logger.error("Refs missing"); return
        end
        attemptAcceptQuest()
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
