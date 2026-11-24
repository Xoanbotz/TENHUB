--[[
  TEN HUB Game Module: Cultivation Unbound (FIXED / OPTIMIZED)
  Fitur: Auto Quest + Auto Kill (Shen -> Core Disciple)
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

    local state = { running = false, runId = 0, totalKills = 0, questCleared = 0 }

    local CONFIG = {
        MOB_NAME      = "core disciple", -- lowercase
        ANCHOR_NAME   = "Anchor_CoreDisciple",
        SEARCH_RADIUS = 250,
        ATTACK_REACH  = 3,
        KILL_TICK     = 0.08,
        LOOP_TICK     = 0.3,
        ACCEPT_WAIT   = 1.5,
        MAX_HITS      = 150,
        RESCAN_DELAY  = 3,   -- jeda full-scan workspace
    }

    local refs = { shen = nil, prompt = nil, anchor = nil }
    local mobContainer, lastFullScan = nil, 0

    -- Anti-AFK (VU sebelumnya di-import tapi nggak dipakai buat ini)
    local idleConn = player.Idled:Connect(function()
        VU:CaptureController()
        VU:ClickButton2(Vector2.new())
    end)

    -- === HELPERS ===
    local function getPos(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Attachment") then return inst.WorldPosition end
        if inst:IsA("Model") then return inst:GetPivot().Position end
        return getPos(inst.Parent)
    end

    local function alive(inst) return inst and inst.Parent ~= nil end

    -- Cache refs; hanya cari ulang kalau hilang (bukan tiap loop)
    local function initRefs()
        pcall(function()
            if not alive(refs.shen) then
                refs.shen = workspace:FindFirstChild("Shen")
                refs.prompt = nil
            end
            if refs.shen and not alive(refs.prompt) then
                refs.prompt = refs.shen:FindFirstChild("QuestPrompt", true)
            end
            if not alive(refs.anchor) then
                local anchors = workspace:FindFirstChild("QuestTargetAnchors")
                refs.anchor = anchors and anchors:FindFirstChild(CONFIG.ANCHOR_NAME)
            end
        end)
        return (refs.shen and refs.prompt and refs.anchor) ~= nil
    end

    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function isAlive()
        local c = player.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return h and h.Health > 0
    end

    local function isQuestActive()
        if not alive(refs.anchor) then return false end
        local marker = refs.anchor:FindFirstChild("QuestTarget_CoreDisciple")
        return marker ~= nil and marker:IsA("BillboardGui") and marker.Enabled
    end

    -- Prompt cuma jalan kalau dekat -> teleport ke Shen dulu
    local function goNearShen()
        local hrp, pos = getHRP(), getPos(refs.prompt)
        if not hrp or not pos then return end
        local range = (refs.prompt.MaxActivationDistance or 10)
        if (hrp.Position - pos).Magnitude > range - 2 then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 0, 3))
            task.wait(0.2)
        end
    end

    local function fireQuestPrompt()
        if not alive(refs.prompt) then return end
        goNearShen()
        local ok = pcall(fireproximityprompt, refs.prompt)
        if not ok then
            pcall(function()
                refs.prompt:InputHoldBegin()
                task.wait(refs.prompt.HoldDuration + 0.1)
                refs.prompt:InputHoldEnd()
            end)
        end
    end

    -- Match kata utuh (sebelumnya "ok" ikut nge-match "book", "look", dll)
    local ACCEPT_WORDS = { accept = true, ambil = true, terima = true, yes = true, ok = true, okay = true }
    local function isAcceptText(s)
        for w in (s or ""):lower():gmatch("%a+") do
            if ACCEPT_WORDS[w] then return true end
        end
        return false
    end

    local function clickButton(btn)
        -- RBXScriptSignal nggak punya :Fire(); pakai getconnections/firesignal
        if firesignal then
            if pcall(firesignal, btn.MouseButton1Click) then return true end
        end
        if getconnections then
            local ok = pcall(function()
                for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
            end)
            return ok
        end
        return false
    end

    local function acceptDialog()
        task.wait(CONFIG.ACCEPT_WAIT)

        -- Legacy Dialog: cari cuma di bawah Shen, bukan seluruh workspace
        if refs.shen then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            for _, d in ipairs(refs.shen:GetDescendants()) do
                if d:IsA("Dialog") then
                    for _, choice in ipairs(d:GetChildren()) do
                        if choice:IsA("DialogChoice") and isAcceptText(choice.UserDialog) and hum then
                            pcall(function() d:Show(hum, choice) end)
                            return true
                        end
                    end
                end
            end
        end

        -- Custom GUI: hanya tombol yang beneran kelihatan
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") and desc.Visible and isAcceptText(desc.Text) then
                        if clickButton(desc) then return true end
                    end
                end
            end
        end
        return false
    end

    -- Cari mob: cache parent-nya, scan workspace penuh cuma kalau perlu
    local function pickClosest(list, anchorPos)
        local closest, best = nil, CONFIG.SEARCH_RADIUS
        for _, obj in ipairs(list) do
            if obj:IsA("Model") and obj.Name:lower() == CONFIG.MOB_NAME then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and hrp then
                    local d = (hrp.Position - anchorPos).Magnitude
                    if d < best then closest, best = obj, d end
                end
            end
        end
        return closest
    end

    local function findTargetMob()
        local anchorPos = getPos(refs.anchor)
        if not anchorPos then return nil end

        if alive(mobContainer) then
            local m = pickClosest(mobContainer:GetChildren(), anchorPos)
            if m then return m end
        end

        if os.clock() - lastFullScan < CONFIG.RESCAN_DELAY then return nil end
        lastFullScan = os.clock()
        local m = pickClosest(workspace:GetDescendants(), anchorPos)
        mobContainer = m and m.Parent or nil
        return m
    end

    -- === KILL ===
    local function killMob(mob, myRun)
        local hum = mob:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local hits = 0

        while state.running and state.runId == myRun
              and alive(mob) and hum.Health > 0 and hits < CONFIG.MAX_HITS do
            local mobHRP, hrp = mob:FindFirstChild("HumanoidRootPart"), getHRP()
            if not mobHRP or not hrp or not isAlive() then break end

            -- Teleport depan mob & hadap ke mob
            local pos = (mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)).Position
            hrp.CFrame = CFrame.lookAt(pos, mobHRP.Position)

            local cam = workspace.CurrentCamera
            VU:Button1Down(Vector2.new(0, 0), cam and cam.CFrame)
            task.wait(0.03)
            VU:Button1Up(Vector2.new(0, 0), cam and cam.CFrame)
            task.wait(CONFIG.KILL_TICK)
            hits += 1
        end

        if hum.Health <= 0 then state.totalKills += 1 end
    end

    -- === LOOP UTAMA ===
    local function autoLoop(myRun)
        local wasActive = false

        while state.running and state.runId == myRun do
            local ok, err = pcall(function()
                if not isAlive() then task.wait(1) return end
                if not initRefs() then return end

                local active = isQuestActive()

                if wasActive and not active then
                    state.questCleared += 1
                    Logger.success(string.format("[AUTO] Quest #%d COMPLETE! Total kills: %d",
                        state.questCleared, state.totalKills))
                end
                wasActive = active

                if not active then
                    fireQuestPrompt()
                    acceptDialog()
                    task.wait(1)
                    return
                end

                local target = findTargetMob()
                if target then
                    killMob(target, myRun)
                else
                    task.wait(0.5) -- nunggu respawn, jangan spam log
                end
            end)
            if not ok then Logger.warn("[AUTO] Error: " .. tostring(err)) end
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

    local function setStatus(text, color)
        if statusLabel and statusLabel.Parent then
            statusLabel.Text = "  Status: " .. text
            statusLabel.TextColor3 = color
        end
    end

    task.spawn(function()
        while statusLabel and statusLabel.Parent do
            task.wait(0.5)
            killsLabel.Text  = "  Kills: " .. state.totalKills
            questsLabel.Text = "  Quest cleared: " .. state.questCleared
        end
        idleConn:Disconnect() -- bersihin saat GUI ditutup
        state.running = false
    end)

    window:AddButton("▶ START Auto Quest", function()
        if state.running then Logger.warn("[AUTO] Udah jalan, stop dulu") return end
        if not initRefs() then
            Logger.error("[AUTO] Shen/prompt/anchor belum ketemu.")
            setStatus("FAILED (refs missing)", P.ERROR)
            return
        end
        state.running = true
        state.runId += 1 -- token: loop lama otomatis mati
        Logger.success("[AUTO] ▶ STARTED")
        setStatus("RUNNING", P.SUCCESS)
        task.spawn(autoLoop, state.runId)
    end)

    window:AddButton("⏹ STOP Auto Quest", function()
        if not state.running then Logger.warn("[AUTO] Belum jalan") return end
        state.running = false
        Logger.info("[AUTO] ⏹ STOPPED")
        setStatus("STOPPED", P.WARN)
    end)

    window:AddButton("🔍 Check Refs", function()
        local ok = initRefs()
        Logger.info(string.format("Shen:%s prompt:%s anchor:%s",
            tostring(refs.shen ~= nil), tostring(refs.prompt ~= nil), tostring(refs.anchor ~= nil)))
        ctx.GuiUtil.Notify("TEN HUB", ok and "Refs OK" or "Refs missing — cek console", ok and 2 or 3)
    end)

    initRefs()
    Logger.success("Cultivation Unbound module loaded")
end

return Game
