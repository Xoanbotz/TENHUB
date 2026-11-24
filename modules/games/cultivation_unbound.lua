--[[
============================================================
  TEN HUB Game Module: Cultivation Unbound
  Fitur: START → auto interact Shen + accept + kill 5 mobs
============================================================
]]

local Players = game:GetService("Players")
local VU      = game:GetService("VirtualUser")
local UIS     = game:GetService("UserInputService")
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
        currentWeapon = nil,
    }

    local CONFIG = {
        MOB_NAME      = "Core Disciple",
        ANCHOR_NAME   = "Anchor_CoreDisciple",
        MARKER_NAME   = "QuestTarget_CoreDisciple",
        SEARCH_RADIUS = 500,
        ATTACK_REACH  = 3,
        KILL_TICK     = 0.08,
        LOOP_TICK     = 0.3,
        ACCEPT_RETRY  = 5,
        MAX_HITS_PER_MOB = 300,
    }

    local refs = { shen = nil, prompt = nil, anchor = nil }

    -- ============================================================
    -- HELPERS DASAR
    -- ============================================================
    local function getChar() return player.Character end
    local function getHRP()
        local c = getChar()
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function getHum()
        local c = getChar()
        return c and c:FindFirstChildOfClass("Humanoid")
    end

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

    -- ============================================================
    -- CARI MOB
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
        if not refs.anchor then refs.anchor = findAnchor() end
        if refs.anchor then
            local marker = refs.anchor:FindFirstChild(CONFIG.MARKER_NAME)
            if marker and marker:IsA("BillboardGui") and marker.Enabled then
                return true
            end
        end
        return countAliveMobs() > 0
    end

    local function findClosestMob(exclude)
        local hrp = getHRP()
        if not hrp then return nil end
        local anchorPos = refs.anchor and refs.anchor.Position

        local closest, closestDist = nil, math.huge
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= exclude
               and obj.Name:lower() == CONFIG.MOB_NAME:lower() then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local mobHRP = obj:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and mobHRP then
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

    -- ============================================================
    -- WEAPON HANDLER
    -- ============================================================
    local function equipBestWeapon()
        local char = getChar()
        local hum = getHum()
        if not char or not hum then return nil end

        -- Cek tool yang udah dipegang
        local current = char:FindFirstChildOfClass("Tool")
        if current then
            state.currentWeapon = current
            return current
        end

        -- Cari tool di backpack
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return nil end

        local best
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                best = tool
                break
            end
        end
        if best then
            pcall(function() hum:EquipTool(best) end)
            task.wait(0.2)
            state.currentWeapon = best
            return best
        end
        return nil
    end

    -- ============================================================
    -- MULTI-METHOD ATTACK
    -- ============================================================
    local function attackMethod1_Activate()
        local tool = state.currentWeapon
            or (getChar() and getChar():FindFirstChildOfClass("Tool"))
        if not tool then return false end
        local ok = pcall(function() tool:Activate() end)
        return ok
    end

    local function attackMethod2_VUClick()
        pcall(function()
            VU:Button1Down(Vector2.new())
            task.wait(0.02)
            VU:Button1Up(Vector2.new())
        end)
        return true
    end

    local function attackMethod3_MouseClick()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.02)
            vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
        return true
    end

    local function attackMethod4_Keypress()
        pcall(function()
            VU:CaptureController()
            keypress(0x45)  -- E key (umum buat skill)
            task.wait(0.02)
            keyrelease(0x45)
        end)
        return true
    end

    local function doAttack()
        -- Prioritas: activate tool dulu (paling reliable kalau ada weapon)
        if state.currentWeapon then
            if attackMethod1_Activate() then return end
        end
        -- Fallback: klik virtual
        attackMethod2_VUClick()
        -- Bonus: klik via VirtualInputManager (kadang lebih works)
        pcall(attackMethod3_MouseClick)
    end

    -- ============================================================
    -- KILL LOOP (satu mob sampe mati)
    -- ============================================================
    local function killMob(mob)
        local hits = 0
        local char = getChar()
        local hum = getHum()
        local hrp = getHRP()
        if not hum or not hrp then return false end

        while state.running and mob and mob.Parent do
            local mobHum = mob:FindFirstChildOfClass("Humanoid")
            local mobHRP = mob:FindFirstChild("HumanoidRootPart")
            if not mobHum or mobHum.Health <= 0 or not mobHRP then break end

            -- Teleport deket mob (tiap hit, biar tetep nempel)
            hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)

            -- Attack pakai multi method
            doAttack()

            task.wait(CONFIG.KILL_TICK)
            hits = hits + 1

            if hits % 10 == 0 then
                Logger.info(string.format("[KILL] Hits: %d | Mob HP: %d",
                    hits, math.floor(mobHum.Health)))
            end

            if hits >= CONFIG.MAX_HITS_PER_MOB then
                Logger.warn("[KILL] Mob nggak mati dalam " .. CONFIG.MAX_HITS_PER_MOB .. " hit")
                break
            end
        end

        local dead = pcall(function()
            local h = mob and mob:FindFirstChildOfClass("Humanoid")
            return h and h.Health <= 0
        end)
        local isDead = false
        pcall(function()
            local h = mob and mob:FindFirstChildOfClass("Humanoid")
            isDead = h and h.Health <= 0
        end)

        if isDead then
            state.totalKills = state.totalKills + 1
            Logger.success("[KILL] ✔ Killed. Total: " .. state.totalKills)
            return true
        end
        return false
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

        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Dialog") and d.Enabled then
                for _, choice in ipairs(d:GetChildren()) do
                    if choice:IsA("DialogChoice") and matches(choice.UserDialog) then
                        local h = getHum()
                        if h then
                            d:Show(h, choice)
                            Logger.info("[ACCEPT] Legacy: " .. choice.Name)
                            return true
                        end
                    end
                end
            end
        end

        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") and desc.Visible
                       and (matches(desc.Text) or matches(desc.Name)) then
                        pcall(function() desc:Activate() end)
                        pcall(function()
                            if desc.MouseButton1Click then
                                desc.MouseButton1Click:Fire()
                            end
                        end)
                        Logger.info("[ACCEPT] Btn: " .. desc:GetFullName())
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
    -- LOOP UTAMA
    -- ============================================================
    local function autoLoop()
        local wasActive = false
        local acceptAttempts = 0

        -- Equip weapon sekali di awal
        equipBestWeapon()

        while state.running do
            pcall(function()
                initRefs()
                local active = isQuestActive()

                -- Quest complete
                if wasActive and not active then
                    state.questCleared = state.questCleared + 1
                    Logger.success(string.format(
                        "[AUTO] QUEST #%d COMPLETE! Kills: %d",
                        state.questCleared, state.totalKills))
                    wasActive = false
                    acceptAttempts = 0
                    task.wait(1.5)
                    return
                end

                -- Ambil quest
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

                -- Quest aktif → kill mobs satu-satu
                wasActive = true
                acceptAttempts = 0

                -- Equip weapon kalau belum
                if not state.currentWeapon
                   or not state.currentWeapon.Parent then
                    equipBestWeapon()
                end

                local target = findClosestMob()
                if target then
                    Logger.info("[AUTO] Target mob ditemukan, kill...")
                    killMob(target)
                else
                    local alive = countAliveMobs()
                    if alive > 0 then
                        Logger.info("[AUTO] Mob ada " .. alive .. " tapi jauh, cari ulang")
                    else
                        Logger.warn("[AUTO] Nggak ada mob hidup, tunggu spawn")
                    end
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
    window:AddLabel("Target: Core Disciple (5 kill)", P.TEXT)

    local statusLabel = window:AddLabel("Status: IDLE", P.GRAY)
    local killsLabel  = window:AddLabel("Kills: 0", P.TEXT)
    local questsLabel = window:AddLabel("Quest cleared: 0", P.TEXT)
    local weaponLabel = window:AddLabel("Weapon: (none)", P.GRAY)

    task.spawn(function()
        while statusLabel and statusLabel.Parent do
            task.wait(0.5)
            if killsLabel and killsLabel.Parent then
                killsLabel.Text = "  Kills: " .. state.totalKills
            end
            if questsLabel and questsLabel.Parent then
                questsLabel.Text = "  Quest cleared: " .. state.questCleared
            end
            if weaponLabel and weaponLabel.Parent then
                local w = state.currentWeapon
                weaponLabel.Text = "  Weapon: " .. (w and w.Name or "(none)")
            end
        end
    end)

    window:AddButton("▶ START", function()
        if state.running then return end
        if not initRefs() then
            Logger.error("[AUTO] Shen/QuestPrompt nggak ketemu")
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
        equipBestWeapon()
        Logger.info(string.format(
            "Shen:%s prompt:%s anchor:%s mobsAlive:%d weapon:%s",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil),
            countAliveMobs(),
            state.currentWeapon and state.currentWeapon.Name or "none"
        ))
    end)

    window:AddButton("🗡️ Force Equip Weapon", function()
        local w = equipBestWeapon()
        Logger.info("[WEAPON] Equipped: " .. (w and w.Name or "none"))
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
