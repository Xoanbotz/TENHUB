_G.TenHub = _G.TenHub or {}

local Logger = { logs = {} }

local function log(msg, level)
    level = level or "info"
    local entry = { time = os.date("%H:%M:%S"), msg = tostring(msg), level = level }
    table.insert(Logger.logs, entry)
    print("[TEN HUB][" .. level:upper() .. "] " .. entry.msg)
end

function Logger.info(m)    log(m, "info")    end
function Logger.warn(m)    log(m, "warn")    end
function Logger.error(m)   log(m, "error")   end
function Logger.success(m) log(m, "success") end

_G.TenHub.Logger = Logger
return Logger
