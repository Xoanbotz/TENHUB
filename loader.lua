--[[
  TEN HUB - DEBUG MODE
  Cek apakah file di GitHub bisa di-fetch
]]

local BASE_URL = "https://raw.githubusercontent.com/Xoanbotz/TENHUB/main/"

-- Bikin GUI debug dulu
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("TenHubDebug")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "TenHubDebug"
sg.ResetOnSpawn = false
sg.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 400)
frame.Position = UDim2.new(0.5, -175, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(10, 5, 15)
frame.BorderSizePixel = 0
frame.Parent = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(180, 30, 255)
stroke.Thickness = 2
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
title.Text = "TEN HUB - DEBUG"
title.TextColor3 = Color3.fromRGB(220, 210, 230)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -60)
scroll.Position = UDim2.new(0, 10, 0, 50)
scroll.BackgroundColor3 = Color3.fromRGB(20, 12, 32)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = scroll

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = scroll

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 8)
padding.Parent = scroll

local function addLine(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(220, 210, 230)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = scroll
    return lbl
end

addLine("BASE_URL:", Color3.fromRGB(180, 30, 255))
addLine(BASE_URL, Color3.fromRGB(150, 140, 170))
addLine("")

-- Test fetch 4 file
local files = {
    "loader.lua",
    "modules/shared/logger.lua",
    "modules/shared/gui_util.lua",
    "modules/shared/anti_afk.lua",
}

local successCount = 0
local totalFiles = #files

for _, file in ipairs(files) do
    local url = BASE_URL .. file
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    
    if ok and res and #res > 0 and not string.find(res, "404: Not Found") then
        addLine("[OK] " .. file .. " (" .. #res .. " bytes)", Color3.fromRGB(100, 255, 150))
        successCount = successCount + 1
    else
        addLine("[FAIL] " .. file, Color3.fromRGB(255, 80, 100))
        if ok and res then
            addLine("  Response: " .. string.sub(tostring(res), 1, 50), Color3.fromRGB(255, 150, 150))
        else
            addLine("  Error: " .. tostring(res), Color3.fromRGB(255, 150, 150))
        end
    end
end

addLine("")
addLine("Result: " .. successCount .. "/" .. totalFiles .. " file berhasil di-fetch", 
    successCount == totalFiles and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 80, 100))

if successCount == totalFiles then
    addLine("")
    addLine("Semua file OK. Kemungkinan masalah di logika script.", Color3.fromRGB(255, 200, 80))
else
    addLine("")
    addLine("ADA FILE YANG 404. Cek:", Color3.fromRGB(255, 200, 80))
    addLine("1. Repo private? Ubah ke Public", Color3.fromRGB(220, 210, 230))
    addLine("2. File belum diupload?", Color3.fromRGB(220, 210, 230))
    addLine("3. Nama file salah? (case-sensitive)", Color3.fromRGB(220, 210, 230))
end

print("[TEN HUB DEBUG] " .. successCount .. "/" .. totalFiles .. " files fetched")
