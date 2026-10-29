--[[
=========================================================
  TEN HUB - Simple Test Loader
  Tujuan: cek fetch + loadstring di Delta
=========================================================
]]

print("========== START ==========")

-- STEP 1: Cek loadstring
print("[STEP 1] Cek loadstring...")
local ls = loadstring or load
print("  loadstring:", type(loadstring))
print("  load:", type(load))
print("  chosen:", type(ls))

if not ls then
    warn("  GAGAL: nggak ada loadstring/load, stop")
    return
end

-- STEP 2: Cek HTTP
print("[STEP 2] Cek HttpGet...")
print("  game.HttpGet:", type(game.HttpGet))
print("  game.HttpGetAsync:", type(game.HttpGetAsync))

local function fetch(url)
    -- Coba HttpGet dulu
    if type(game.HttpGet) == "function" then
        local ok, res = pcall(game.HttpGet, game, url)
        if ok and type(res) == "string" and #res > 0 then
            print("  [HttpGet] OK, " .. #res .. " bytes")
            return res
        end
    end
    -- Fallback HttpGetAsync
    if type(game.HttpGetAsync) == "function" then
        local ok, res = pcall(game.HttpGetAsync, game, url)
        if ok and type(res) == "string" and #res > 0 then
            print("  [HttpGetAsync] OK, " .. #res .. " bytes")
            return res
        end
    end
    warn("  GAGAL: dua-duanya gagal")
    return nil
end

-- STEP 3: Fetch loader kita sendiri
print("[STEP 3] Fetch logger.lua...")
local url = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/modules/shared/logger.lua"
local code = fetch(url)

if not code then
    warn("  GAGAL: fetch logger.lua")
    return
end

print("  First 80: " .. code:sub(1, 80))
print("  Last 80: " .. code:sub(-80))

-- STEP 4: Compile
print("[STEP 4] Compile logger.lua...")
local chunk, err = ls(code)
print("  compile:", type(chunk), err)

if not chunk then
    warn("  GAGAL: syntax error di logger.lua")
    return
end

-- STEP 5: Execute
print("[STEP 5] Execute logger.lua...")
local ok, result = pcall(chunk)
print("  execute:", ok, result)

if not ok then
    warn("  GAGAL: runtime error: " .. tostring(result))
    return
end

-- STEP 6: Cek hasil
print("[STEP 6] Cek _G.TenHub.Logger...")
print("  TenHub:", type(_G.TenHub))
print("  Logger:", type(_G.TenHub and _G.TenHub.Logger))

if _G.TenHub and _G.TenHub.Logger then
    _G.TenHub.Logger.info("LOGGER WORKS!")
    print("========== SEMUA OK ==========")

    -- Bikin GUI kecil bukti jalan
    local sg = Instance.new("ScreenGui")
    sg.Name = "TenHubTest"
    sg.ResetOnSpawn = false
    sg.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 80)
    frame.Position = UDim2.new(0.5, -150, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(20, 12, 32)
    frame.BorderSizePixel = 0
    frame.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(180, 30, 255)
    stroke.Thickness = 2
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "✓ TEN HUB TEST OK\nLogger berhasil di-load"
    label.TextColor3 = Color3.fromRGB(100, 255, 150)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    print("[GUI] Frame kecil muncul di atas layar")
else
    warn("  GAGAL: _G.TenHub.Logger nil")
end

print("========== DONE ==========")
