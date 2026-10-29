local virtualUserWarned = false

player.Idled:Connect(function()
    if not AntiAFK.enabled then return end

    AntiAFK.triggerCount = AntiAFK.triggerCount + 1
    AntiAFK.lastTrigger = os.clock()

    local ok = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)

    if not ok and not virtualUserWarned then
        virtualUserWarned = true
        if _G.TenHub.Logger then
            _G.TenHub.Logger.warn("Anti-AFK: VirtualUser unsupported by executor")
        end
    end

    if _G.TenHub.Logger then
        _G.TenHub.Logger.info("Anti-AFK triggered (total: " .. AntiAFK.triggerCount .. ")")
    end
end)
