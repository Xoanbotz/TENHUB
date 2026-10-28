
--[[
=========================================================
  TEN HUB Shared: Logger
  Author: Kyriel
=========================================================
]]

_G.TenHub = _G.TenHub or {}

local Logger = {
    logs = {},
    maxLogs = 200,
    guiCallback = nil,
}

-- Warna (biar konsisten sama palette)
local COLORS = {
    info = Color3.fromRGB(220, 210, 230),
    warn = Color3.fromRGB(255, 200, 80),
    error = Color3.fromRGB(255, 80, 100),
    success = Color3.fromRGB(100, 255, 150),
    debug = Color3.fromRGB(150, 140, 170),
}

-- Set callback kalo mau forward ke GUI
function Logger.setGuiCallback(cb)
    Logger.guiCallback = cb
end

-- Core logging
function Logger.log(msg, level)
    level = level or "info"
    local entry = {
        time = os.date("%H:%M:%S"),
        msg = tostring(msg),
        level = level,
        color = COLORS[level] or COLORS.info,
    }
    
    table.insert(Logger.logs, entry)
    if #Logger.logs > Logger.maxLogs then
        table.remove(Logger.logs, 1)
    end
    
    print("[TEN HUB][" .. string.upper(level) .. "] " .. entry.msg)
    
    if Logger.guiCallback then
        pcall(Logger.guiCallback, entry)
    end
end

-- Shortcut methods
function Logger.info(msg) Logger.log(msg, "info") end
function Logger.warn(msg) Logger.log(msg, "warn") end
function Logger.error(msg) Logger.log(msg, "error") end
function Logger.success(msg) Logger.log(msg, "success") end
function Logger.debug(msg) Logger.log(msg, "debug") end

-- Get last N logs
function Logger.getRecent(n)
    n = n or 10
    local out = {}
    local startIdx = math.max(1, #Logger.logs - n + 1)
    for i = startIdx, #Logger.logs do
        table.insert(out, Logger.logs[i])
    end
    return out
end

-- Clear log
function Logger.clear()
    Logger.logs = {}
end

_G.TenHub.Logger = Logger
return Logger
