--[[
============================================================
  TEN HUB Game Module: Cultivation Unbound
  Fitur: Auto Quest (Shen → Core Disciple)
============================================================
]]

local Players = game:GetService("Players")
local VU      = game:GetService("VirtualUser")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui")

local Game = {
    name    = "Cultivation Unbound",
    gameIds = {
        -- TODO: isi PlaceId game
    },
}

function Game.build(window, ctx)
    local Logger = ctx.Logger
    local P      = ctx.GuiUtil.Palette

    -- === STATE ===
    local state = {
        autoQuest    = false,
        loopRunning  = false,
    }

    -- === CONFIG ===
    local CONFIG = {
        MOB_NAME      = "Core Disciple",
        ANCHOR_NAME   = "Anchor_CoreDisciple",
        SEARCH_RADIUS = 250,
        ATTACK_REACH  = 3,
    }

    -- === REFS ===
    local refs = { shen = nil, prompt = nil, anchor = nil }

    local function initRefs()
        pcall(function()
            refs.shen = workspace:FindFirstChild("Shen")
            if refs.shen then
                refs.prompt = refs.shen:FindFirstChild("QuestPrompt", true)
            end
            local anchors = workspace:FindFirstChild("QuestTargetAnchors")
            if anchors then
                refs.anchor = anchors:FindFirstChild(CONFIG.ANCHOR_NAME)
            end
        end)
        return refs.shen and refs.prompt and refs.anchor
    end

    -- === HELPERS ===
    local function getHRP()
        local c = player.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function isQuestActive()
        if not refs.anchor then return false end
        local marker = refs.anchor:FindFirstChild("QuestTarget_CoreDisciple")
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
        task.wait(0.8)

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

    local function attackMob(mob)
        local hum    = mob:FindFirstChildOfClass("Humanoid")
        local mobHRP = mob:FindFirstChild("HumanoidRootPart")
        local hrp    = getHRP()
        if not hum or hum.Health <= 0 or not mobHRP or not hrp then return end

        hrp.CFrame = mobHRP.CFrame * CFrame.new(0, 0, -CONFIG.ATTACK_REACH)

        VU:Button1Down(Vector2.new())
        task.wait(0.1)
        VU:Button1Up(Vector2.new())
    end

    -- === LOOP ===
    local function startLoop()
        if state.loopRunning then return end
        state.loopRunning = true

        task.spawn(function()
            while state.autoQuest do
                local ok, err = pcall(function()
                    if not initRefs() then
                        Logger.warn("[AUTO] Shen/prompt/anchor missing")
                        return
                    end

                    if not isQuestActive() then
                        fireQuestPrompt()
                        acceptDialog()
                        task.wait(2)
                        return
                    end

                    local target = findTargetMob()
                    if target then
                        attackMob(target)
                    end
                end)

                if not ok then
                    Logger.error("[AUTO] " .. tostring(err))
                end

                task.wait(0.5)
            end
            state.loopRunning = false
        end)
    end

    -- === GUI ===
    window:AddSection("Auto Quest")
    window:AddLabel("Quest Giver: Shen", P.TEXT)
    window:AddLabel("Target: Core Disciple", P.TEXT)

    local statusLabel = window:AddLabel("Status: idle", P.GRAY)

    window:AddToggle("Auto Quest Core Disciple", false, function(enabled)
        state.autoQuest = enabled

        if enabled then
            Logger.info("[AUTO] Enabled")
            if statusLabel then
                statusLabel.Text = "  Status: running"
                statusLabel.TextColor3 = P.SUCCESS
            end
            startLoop()
        else
            Logger.info("[AUTO] Disabled")
            if statusLabel then
                statusLabel.Text = "  Status: stopped"
                statusLabel.TextColor3 = P.GRAY
            end
        end
    end)

    window:AddButton("Check Refs", function()
        local ok = initRefs()
        local msg = string.format(
            "Shen:%s prompt:%s anchor:%s",
            tostring(refs.shen ~= nil),
            tostring(refs.prompt ~= nil),
            tostring(refs.anchor ~= nil)
        )
        Logger.info("Refs " .. msg)

        if ok then
            ctx.GuiUtil.Notify("TEN HUB", "Refs OK", 2)
        else
            ctx.GuiUtil.Notify("TEN HUB", "Refs missing — cek output", 3)
        end
    end)

    -- Init
    initRefs()
    Logger.success("Cultivation Unbound loaded")
end

return Game
