-- TEN HUB Loader
local BASE_URL = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/"

loadstring(game:HttpGet(BASE_URL .. "modules/logger.lua"))()
loadstring(game:HttpGet(BASE_URL .. "modules/gui.lua"))()

local Logger  = _G.TenHub.Logger
local GuiUtil = _G.TenHub.GuiUtil

Logger.info("Loader starting...")

local Window = GuiUtil.CreateWindow({
    Title    = "TEN HUB",
    Subtitle = "v1.0",
    Width    = 400,
    Height   = 300,
})
local P = GuiUtil.Palette

Window:AddSection("Welcome")
Window:AddLabel("TEN HUB v1.0", P.NEON)
Window:AddLabel("Script by ADIEL", P.GRAY)

Window:AddSection("Status")
Window:AddLabel("PlaceId: " .. tostring(game.PlaceId), P.TEXT)
Window:AddLabel("Game: " .. tostring(game.PlaceId), P.TEXT)

Window:AddSection("Test")
Window:AddToggle("Test Toggle", false, function(s)
    Logger.info("Toggle: " .. tostring(s))
end)
Window:AddButton("Test Button", function()
    Logger.success("Button clicked")
    GuiUtil.Notify("TEN HUB", "Button works", 3)
end)

GuiUtil.Notify("TEN HUB", "Loaded", 3)
Logger.success("DONE")
