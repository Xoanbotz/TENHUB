--[[
=========================================================
  TEN HUB - Loader
  Author: Kyriel (for ADIEL)
  Executor: Delta / Codex / Wave / Xeno
  Version: 1.0
=========================================================
]]

-- ============================================================
-- CONFIG
-- ============================================================
local BASE_URL = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/"
-- GANTI dengan URL repo lo (branch main, raw)

-- Daftar game (kosong dulu, lo isi nanti)
-- Format: [PlaceId] = "nama_file_module"
local GAMES = {
    -- [2753915549] = "blox_fruits",
    -- [9872472334] = "pet_sim_99",
}

-- ============================================================
-- HELPER
-- ============================================================
local function fetch(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and res and #res > 0 then
        return res
    end
    warn("[TEN HUB] Fetch failed: " .. url)
    return nil
end

local function runLua(code)
    local ok, fn = pcall(loadstring, code)
    if ok and fn then
        pcall(fn)
        return true
    end
    return false
end

-- ============================================================
-- LOAD SHARED LIBRARY
-- ============================================================
_G.TenHub = _G.TenHub or {}

local sharedFiles = {"logger", "gui_util", "anti_afk"}
for _, name in ipairs(sharedFiles) do
    local code = fetch(BASE_URL .. "modules/shared/" .. name .. ".lua")
    if code then
        runLua(code)
    else
        warn("[TEN HUB] Gagal load " .. name)
    end
end

-- ============================================================
-- GET SHARED REFS
-- ============================================================
local Logger = _G.TenHub.Logger
local GuiUtil = _G.TenHub.GuiUtil
local AntiAFK = _G.TenHub.AntiAFK

if not Logger or not GuiUtil then
    warn("[TEN HUB] Shared library gagal load, hub gak bisa jalan")
    return
end

Logger.info("TEN HUB starting...")

-- ============================================================
-- CREATE MAIN WINDOW
-- ============================================================
local Window = GuiUtil.CreateWindow({
    Title = "TEN HUB",
    Subtitle = "T E N   H U B   v 1 . 0",
    Width = 420,
    Height = 340,
})

-- ============================================================
-- WELCOME SECTION
-- ============================================================
Window:AddSection("Welcome")
Window:AddLabel("TEN HUB v1.0", GuiUtil.Palette.NEON)
Window:AddLabel("Script Created by ADIEL", GuiUtil.Palette.GRAY)

-- ============================================================
-- STATUS SECTION
-- ============================================================
Window:AddSection("Status")

local gameName = "Unknown"
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info then
        gameName = info.Name
    end
end)

Window:AddLabel("Game: " .. gameName, GuiUtil.Palette.TEXT)
Window:AddLabel("PlaceId: " .. tostring(game.PlaceId), GuiUtil.Palette.GRAY)
Window:AddLabel(
    "Anti-AFK: " .. (AntiAFK and AntiAFK.enabled and "ENABLED" or "DISABLED"),
    AntiAFK and AntiAFK.enabled and GuiUtil.Palette.SUCCESS or GuiUtil.Palette.ERROR
)

-- Anti-AFK toggle
Window:AddToggle("Anti-AFK", AntiAFK and AntiAFK.enabled or true, function(state)
    if AntiAFK then
        AntiAFK.setEnabled(state)
        Logger.info("Anti-AFK: " .. (state and "ON" or "OFF"))
    end
end)

-- ============================================================
-- GAMES SECTION
-- ============================================================
Window:AddSection("Games")

local placeId = game.PlaceId
local moduleName = GAMES[placeId]

if moduleName then
    local code = fetch(BASE_URL .. "modules/" .. moduleName .. ".lua")
    if code then
        if runLua(code) then
            Logger.success("Module loaded: " .. moduleName)
            Window:AddLabel("Loaded: " .. moduleName, GuiUtil.Palette.SUCCESS)
        else
            Logger.error("Syntax error di module: " .. moduleName)
        end
    else
        Logger.error("Gagal fetch module: " .. moduleName)
    end
else
    Window:AddLabel("No module available for this game", GuiUtil.Palette.WARN)
    Window:AddLabel("Add PlaceId to GAMES table", GuiUtil.Palette.GRAY)
    Window:AddLabel("PlaceId: " .. placeId, GuiUtil.Palette.GRAY)
end

-- ============================================================
-- INFO SECTION
-- ============================================================
Window:AddSection("Info")
Window:AddLabel("Version: 1.0", GuiUtil.Palette.TEXT)
Window:AddLabel("Author: ADIEL", GuiUtil.Palette.TEXT)
Window:AddLabel("Compatible: Delta / Codex / Wave / Xeno", GuiUtil.Palette.GRAY)

-- ============================================================
-- NOTIFY + DONE
-- ============================================================
GuiUtil.Notify("TEN HUB", "Loaded successfully", 3)
Logger.success("TEN HUB loaded")
