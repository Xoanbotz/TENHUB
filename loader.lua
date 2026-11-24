local BASE_URL = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/"

loadstring(game:HttpGet(BASE_URL .. "modules/logger.lua"))()
loadstring(game:HttpGet(BASE_URL .. "modules/gui.lua"))()

local Logger  = _G.TenHub.Logger
local GuiUtil = _G.TenHub.GuiUtil

Logger.info("Loader starting...")

-- ============================================================
-- GAME MODULE MAP
-- PlaceId → nama file di modules/games/
-- ============================================================
local GAMES = {
    -- TODO: isi PlaceId Cultivation Unbound
     [110725234112010] = "cultivation_unbound",
}

local moduleName = GAMES[game.PlaceId]

-- ============================================================
-- WINDOW
-- ============================================================
local Window = GuiUtil.CreateWindow({
    Title    = "TEN HUB",
    Subtitle = "v1.0",
    Width    = 400,
    Height   = 340,
})
local P = GuiUtil.Palette

Window:AddSection("Welcome")
Window:AddLabel("TEN HUB v1.0", P.NEON)
Window:AddLabel("Script by ADIEL", P.GRAY)

Window:AddSection("Status")
Window:AddLabel("PlaceId: " .. tostring(game.PlaceId), P.TEXT)
Window:AddLabel("Module: " .. (moduleName or "(none)"), 
    moduleName and P.SUCCESS or P.WARN)

Window:AddToggle("Anti-AFK", false, function(s)
    Logger.info("Anti-AFK: " .. tostring(s))
end)

-- ============================================================
-- LOAD GAME MODULE
-- ============================================================
if moduleName then
    local ok, mod = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. "modules/games/" .. moduleName .. ".lua"))()
    end)

    if ok and type(mod) == "table" and type(mod.build) == "function" then
        mod.build(Window, {
            Logger  = Logger,
            GuiUtil = GuiUtil,
        })
        Logger.success("Module loaded: " .. (mod.name or moduleName))
    else
        Logger.error("Module fail: " .. tostring(mod))
        Window:AddSection("Error")
        Window:AddLabel("Module gagal load", P.ERROR)
    end
else
    Window:AddSection("Game")
    Window:AddLabel("Belum support PlaceId ini", P.WARN)
    Window:AddLabel("PlaceId: " .. tostring(game.PlaceId), P.GRAY)
end

GuiUtil.Notify("TEN HUB", "Loaded", 3)
Logger.success("DONE")
