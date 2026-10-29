--[[
=========================================================
  TEN HUB - Loader v1.1
  Author: Kyriel (for ADIEL)
  Executor: Delta / Codex / Wave / Xeno
=========================================================
]]

local BASE_URL = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/"

-- PlaceId -> nama file (tanpa .lua) di modules/games/
local GAMES = {
    -- [2753915549] = "blox_fruits",
    -- [4442272183] = "blox_fruits",
    -- [7449423635] = "blox_fruits",
    -- [8737899170] = "pet_sim_99",
}

local FALLBACK_MODULE = "universal"

-- ============================================================
-- HELPERS
-- ============================================================
local function fetch(url)
    local ok, res = pcall(game.HttpGet, game, url)
    if ok and type(res) == "string" and #res > 0 then
        return res
    end
    warn("[TEN HUB] Fetch failed: " .. tostring(url))
    return nil
end

local function runLua(code, ...)
    if type(code) ~= "string" then return false, "code not string" end
    local chunk, loadErr = loadstring(code)
    if not chunk then
        return false, "syntax: " .. tostring(loadErr)
    end
    local ok, result = pcall(chunk, ...)
    if not ok then
        return false, "runtime: " .. tostring(result)
    end
    return true, result
end

-- ============================================================
-- LOAD SHARED
-- ============================================================
_G.TenHub = _G.TenHub or {}

for _, name in ipairs({"logger", "gui_util", "anti_afk"}) do
    local code = fetch(BASE_URL .. "modules/shared/" .. name .. ".lua")
    if code then
        local ok, err = runLua(code)
        if not ok then
            warn("[TEN HUB] " .. name .. " failed: " .. tostring(err))
        end
    end
end

local Logger  = _G.TenHub.Logger
local GuiUtil = _G.TenHub.GuiUtil
local AntiAFK = _G.TenHub.AntiAFK

if not Logger or not GuiUtil then
    warn("[TEN HUB] Shared library failed, abort")
    return
end

Logger.info("TEN HUB starting...")

-- ============================================================
-- WINDOW
-- ============================================================
local okWin, WindowOrErr = pcall(GuiUtil.CreateWindow, {
    Title    = "TEN HUB",
    Subtitle = "T E N   H U B   v 1 . 1",
    Width    = 420,
    Height   = 380,
})

if not okWin or not WindowOrErr then
    Logger.error("CreateWindow failed: " .. tostring(WindowOrErr))
    return
end

local Window = WindowOrErr
local P = GuiUtil.Palette

-- ============================================================
-- WELCOME
-- ============================================================
Window:AddSection("Welcome")
Window:AddLabel("TEN HUB v1.1", P.NEON)
Window:AddLabel("Script Created by ADIEL", P.GRAY)

-- ============================================================
-- STATUS
-- ============================================================
Window:AddSection("Status")

local gameName = "Unknown"
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info and info.Name then gameName = info.Name end
end)

Window:AddLabel("Game: " .. gameName, P.TEXT)
Window:AddLabel("PlaceId: " .. tostring(game.PlaceId), P.GRAY)

local aaInitial = (AntiAFK and AntiAFK.enabled == true)
Window:AddLabel(
    "Anti-AFK: " .. (aaInitial and "ENABLED" or "DISABLED"),
    aaInitial and P.SUCCESS or P.ERROR
)
Window:AddToggle("Anti-AFK", aaInitial, function(state)
    if AntiAFK then AntiAFK.setEnabled(state) end
end)

-- ============================================================
-- LOAD GAME MODULE
-- ============================================================
local function loadGameModule()
    local placeId    = game.PlaceId
    local moduleName = GAMES[placeId]
    local isFallback = false

    if not moduleName then
        moduleName = FALLBACK_MODULE
        isFallback = true
        Logger.warn("No module for PlaceId " .. placeId .. ", using fallback")
    end

    local code = fetch(BASE_URL .. "modules/games/" .. moduleName .. ".lua")

    if not code then
        Logger.error("Fetch failed: modules/games/" .. moduleName .. ".lua")
        Window:AddSection("Error")
        Window:AddLabel("Failed to fetch module: " .. moduleName, P.ERROR)
        return
    end

    local okRun, modOrErr = runLua(code)
    if not okRun then
        Logger.error("Module " .. moduleName .. " load failed: " .. tostring(modOrErr))
        Window:AddSection("Error")
        Window:AddLabel("Module load failed: " .. moduleName, P.ERROR)
        return
    end

    if type(modOrErr) ~= "table" or type(modOrErr.build) ~= "function" then
        Logger.error("Invalid module format: " .. moduleName)
        Window:AddSection("Error")
        Window:AddLabel("Invalid module contract: " .. moduleName, P.ERROR)
        return
    end

    local mod = modOrErr

    local ctx = {
        Logger     = Logger,
        GuiUtil    = GuiUtil,
        AntiAFK    = AntiAFK,
        isFallback = isFallback,
        placeId    = placeId,
        baseUrl    = BASE_URL,
    }

    local okBuild, buildErr = pcall(mod.build, mod, Window, ctx)
    if not okBuild then
        Logger.error("Module build error: " .. tostring(buildErr))
        Window:AddSection("Error")
        Window:AddLabel("Build error: " .. tostring(buildErr), P.ERROR)
    else
        Logger.success("Module loaded: " .. tostring(mod.name or moduleName))
    end
end

loadGameModule()

-- ============================================================
-- INFO
-- ============================================================
Window:AddSection("Info")
Window:AddLabel("Version: 1.1", P.TEXT)
Window:AddLabel("Author: ADIEL", P.TEXT)
Window:AddLabel("Executor: Delta / Codex / Wave / Xeno", P.GRAY)

GuiUtil.Notify("TEN HUB", "Loaded successfully", 3)
Logger.success("TEN HUB loaded")
