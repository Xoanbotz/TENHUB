function Logger.log(msg, level)
    level = level or "info"
    local okStr, strMsg = pcall(tostring, msg)
    if not okStr then strMsg = "<unstringable>" end

    local entry = {
        time  = os.date("!%H:%M:%S"),   -- UTC, konsisten walau beda TZ
        ms    = math.floor(os.clock() * 1000) % 1000000,
        msg   = strMsg,
        level = level,
        color = COLORS[level] or COLORS.info,
    }

    table.insert(Logger.logs, entry)
    if #Logger.logs > Logger.maxLogs then
        table.remove(Logger.logs, 1)
    end

    pcall(print, "[TEN HUB][" .. string.upper(level) .. "] " .. entry.msg)

    if Logger.guiCallback then
        pcall(Logger.guiCallback, entry)
    end
end
