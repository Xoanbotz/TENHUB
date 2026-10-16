--[[
====================================================
    HARVESTMASS.lua
    Script Created by ADIEL
    Single file - simple - works
    Tag: Herbs
====================================================
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- STATE
local autoHarvest = false
local harvested = 0

-- AMBIL HERBS
local function getHerbs()
    local list = {}
    pcall(function()
        for _, obj in ipairs(CollectionService:GetTagged("Herbs")) do
            if obj and obj.Parent then
                table.insert(list, obj)
            end
        end
    end)
    return list
end

-- HARVEST 1 HERB
local function harvestOne(herb)
    if not herb or not herb.Parent then return false end
    local ok = false

    -- ProximityPrompt
    pcall(function()
        local p = herb:FindFirstChildOfClass("ProximityPrompt")
        if not p then p = herb:FindFirstChildWhichIsA("ProximityPrompt", true) end
        if p then
            p.MaxActivationDistance = 999999
            p.HoldDuration = 0
            p.RequiresLineOfSight = false
            p.Enabled = true
            fireproximityprompt(p, 0, true)
            ok = true
        end
    end)

    -- ClickDetector
    if not ok then
        pcall(function()
            local c = herb:FindFirstChildOfClass("ClickDetector")
            if not c then c = herb:FindFirstChildWhichIsA("ClickDetector", true) end
            if c then
                c.MaxActivationDistance = 999999
                fireclickdetector(c, 0, true)
                ok = true
            end
        end)
    end

    return ok
end

-- HARVEST ALL
local function harvestAll()
    local herbs = getHerbs()
    if #herbs == 0 then
        print("[HARVESTMASS] Tidak ada herbs")
        return
    end

    print("[HARVESTMASS] Harvest " .. #herbs .. " herbs...")

    for _, herb in ipairs(herbs) do
        task.spawn(function()
            pcall(harvestOne, herb)
        end)
    end

    harvested = harvested + #herbs
    print("[HARVESTMASS] Selesai. Total: " .. harvested)
end

--====================================================
-- GUI SIMPLE
--====================================================
local pg = LP:WaitForChild("PlayerGui", 15)
if not pg then
    warn("[HARVESTMASS] PlayerGui gak ketemu")
    return
end

-- Hapus GUI lama
local old = pg:FindFirstChild("HarvestMass_ADIEL")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "HarvestMass_ADIEL"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

-- FRAME
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 180)
frame.Position = UDim2.new(0.5, -150, 0.5, -90)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 200, 130)
stroke.Thickness = 1
stroke.Parent = frame

-- TITLE BAR
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "HARVESTMASS - ADIEL"
titleText.TextColor3 = Color3.fromRGB(0, 220, 130)
titleText.TextSize = 13
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- CLOSE BUTTON
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -28, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeBtn

-- HARVEST BUTTON
local harvestBtn = Instance.new("TextButton")
harvestBtn.Size = UDim2.new(1, -20, 0, 40)
harvestBtn.Position = UDim2.new(0, 10, 0, 42)
harvestBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
harvestBtn.BorderSizePixel = 0
harvestBtn.Text = "HARVEST ALL"
harvestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
harvestBtn.TextSize = 14
harvestBtn.Font = Enum.Font.GothamBold
harvestBtn.Parent = frame

local hbCorner = Instance.new("UICorner")
hbCorner.CornerRadius = UDim.new(0, 6)
hbCorner.Parent = harvestBtn

-- AUTO BUTTON
local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -20, 0, 32)
autoBtn.Position = UDim2.new(0, 10, 0, 88)
autoBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
autoBtn.BorderSizePixel = 0
autoBtn.Text = "AUTO: OFF"
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.TextSize = 13
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Parent = frame

local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 6)
abCorner.Parent = autoBtn

-- INFO LABEL
local infoLbl = Instance.new("TextLabel")
infoLbl.Size = UDim2.new(1, -20, 0, 30)
infoLbl.Position = UDim2.new(0, 10, 0, 126)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "Herbs: 0 | Harvested: 0"
infoLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
infoLbl.TextSize = 12
infoLbl.Font = Enum.Font.Code
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.Parent = frame

--====================================================
-- DRAGGABLE (SIMPLE & PASTI JALAN)
--====================================================
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

--====================================================
-- EVENT HANDLERS
--====================================================
harvestBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        pcall(harvestAll)
    end)
end)

autoBtn.MouseButton1Click:Connect(function()
    autoHarvest = not autoHarvest
    if autoHarvest then
        autoBtn.Text = "AUTO: ON"
        autoBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        task.spawn(function()
            while autoHarvest do
                pcall(harvestAll)
                task.wait(2)
            end
        end)
    else
        autoBtn.Text = "AUTO: OFF"
        autoBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

--====================================================
-- INFO UPDATER
--====================================================
task.spawn(function()
    while gui and gui.Parent do
        task.wait(1)
        pcall(function()
            local herbs = getHerbs()
            infoLbl.Text = "Herbs: " .. #herbs .. " | Harvested: " .. harvested
        end)
    end
end)

--====================================================
-- ANTI AFK
--====================================================
pcall(function()
    LP.Idled:Connect(function()
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0, 0))
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0, 0))
    end)
end)

print("[HARVESTMASS] Loaded - Script Created by ADIEL")
