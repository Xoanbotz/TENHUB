--[[
=========================================================
  TEN HUB Shared: Anti-AFK
  Author: Kyriel
=========================================================
]]

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

_G.TenHub = _G.TenHub or {}

local AntiAFK = {
    enabled = true,
    triggerCount = 0,
    lastTrigger = 0,
}

-- Setter
function AntiAFK.setEnabled(state)
    AntiAFK.enabled = state and true or false
    if _G.TenHub.Logger then
        _G.TenHub.Logger.info("Anti-AFK: " .. (AntiAFK.enabled and "ON" or "OFF"))
    end
end

-- Toggle
function AntiAFK.toggle()
    AntiAFK.setEnabled(not AntiAFK.enabled)
    return AntiAFK.enabled
end

-- Listener
player.Idled:Connect(function()
    if not AntiAFK.enabled then return end
    
    AntiAFK.triggerCount = AntiAFK.triggerCount + 1
    AntiAFK.lastTrigger = tick()
    
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    if _G.TenHub.Logger then
        _G.TenHub.Logger.info("Anti-AFK triggered (total: " .. AntiAFK.triggerCount .. ")")
    end
end)

_G.TenHub.AntiAFK = AntiAFK
return AntiAFK
