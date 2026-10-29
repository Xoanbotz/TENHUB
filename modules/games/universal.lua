
--[[
=========================================================
  TEN HUB Game: Universal
  Fallback module — fitur dasar untuk game apapun
  Author: Kyriel
=========================================================
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Teleport   = game:GetService("TeleportService")

local player = Players.LocalPlayer

local Universal = {
    name    = "Universal",
    gameIds = {},
}

function Universal.build(window, ctx)
    local Logger = ctx.Logger
    local P      = ctx.GuiUtil.Palette

    -- ========================================================
    -- HELPERS
    -- ========================================================
    local function getHum()
        local char = player.Character
        return char and char:FindFirstChildOfClass("Humanoid")
    end

    local function getHRP()
        local char = player.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    -- ========================================================
    -- MOVEMENT
    -- ========================================================
    window:AddSection("Movement")

    window:AddTextBox("WalkSpeed (16 - 500)", function(text)
        local v = tonumber(text)
        if not v then
            Logger.warn("WalkSpeed: invalid number")
            return
        end
        local hum = getHum()
        if hum then
            hum.WalkSpeed = math.clamp(v, 16, 500)
            Logger.info("WalkSpeed set to " .. hum.WalkSpeed)
        end
    end)

    window:AddTextBox("JumpPower (50 - 500)", function(text)
        local v = tonumber(text)
        if not v then
            Logger.warn("JumpPower: invalid number")
            return
        end
        local hum = getHum()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = math.clamp(v, 50, 500)
            Logger.info("JumpPower set to " .. hum.JumpPower)
        end
    end)

    -- Infinite Jump
    local infJump = false
    UIS.JumpRequest:Connect(function()
        if not infJump then return end
        local hum = getHum()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    window:AddToggle("Infinite Jump", false, function(s)
        infJump = s
        Logger.info("Infinite Jump: " .. (s and "ON" or "OFF"))
    end)

    -- Noclip
    local noclip = false
    RunService.Stepped:Connect(function()
        if not noclip then return end
        local char = player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    window:AddToggle("Noclip", false, function(s)
        noclip = s
        Logger.info("Noclip: " .. (s and "ON" or "OFF"))
    end)

    -- ========================================================
    -- TELEPORT
    -- ========================================================
    window:AddSection("Teleport")

    window:AddTextBox("Player name (partial ok)", function(name)
        if not name or name == "" then return end
        local hrp = getHRP()
        if not hrp then
            Logger.warn("Teleport: HRP not found")
            return
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Name:lower():find(name:lower(), 1, true) then
                local target = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if target then
                    hrp.CFrame = target.CFrame + Vector3.new(0, 3, 0)
                    Logger.success("Teleported to " .. p.Name)
                    return
                end
            end
        end
        Logger.warn("Player not found: " .. name)
    end)

    window:AddButton("Freeze Self", function()
        local hrp = getHRP()
        if hrp then
            hrp.Anchored = true
            Logger.info("Frozen")
        end
    end)

    window:AddButton("Unfreeze Self", function()
        local hrp = getHRP()
        if hrp then
            hrp.Anchored = false
            Logger.info("Unfrozen")
        end
    end)

    -- ========================================================
    -- SERVER
    -- ========================================================
    window:AddSection("Server")

    window:AddButton("Rejoin Server", function()
        Logger.info("Rejoining...")
        Teleport:Teleport(game.PlaceId, player)
    end)

    -- ========================================================
    -- DONE
    -- ========================================================
    Logger.success("Universal features ready")
end

return Universal
