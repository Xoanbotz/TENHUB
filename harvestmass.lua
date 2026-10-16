--[[
=========================================================
  MASS HARVEST v6.0 - PLANT COLLECTOR
  Author: Kyriel (for ADIEL)
  Executor: Delta / Codex / Wave / Xeno

FITUR:
  - MASS HARVEST (semua plant di map sekaligus)
  - 3 Metode Deteksi:
      1. GetDescendants() - scan semua object
      2. CollectionService - tag "Harvestable"
      3. Batch Processing - proses banyak sekaligus
  - Server-side inventory update via RemoteEvent
  - Plants: Ginseng, Spirit Grass
=========================================================
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    -- ═══ PLANT DETECTION ═══
    PLANT_NAMES = {
        "Ginseng",
        "Spirit Grass",
        "SpiritGrass",
    },
    
    -- Tag CollectionService buat plant
    HARVESTABLE_TAGS = {
        "Harvestable",
        "Plant",
        "Herb",
        "Collectable",
        "Resource",
    },
    
    -- ═══ BATCH PROCESSING ═══
    BATCH_SIZE = 20,              -- Proses 20 plant sekaligus
    BATCH_DELAY = 0.05,           -- Delay antar batch (detik)
    TELEPORT_DELAY = 0.1,         -- Delay teleport per plant
    FIRE_DELAY = 0.15,            -- Delay abis fire prompt
    
    -- ═══ SCAN ═══
    MAX_DEPTH = 8,                -- Depth recursive scan
    AUTO_SCAN_INTERVAL = 5,       -- Auto rescan tiap X detik (kalo loop aktif)
    
    -- ═══ MODE ═══
    FORCE_PROMPT_DISTANCE = true, -- Paksa MaxActivationDistance = math.huge
    USE_REMOTE_EVENT = true,      -- Coba fire RemoteEvent
    USE_TELEPORT = true,          -- Teleport ke plant (kalo prompt butuh jarak)
    AUTO_LOOP = false,            -- Auto loop harvest
    
    -- ═══ DEBUG ═══
    DEBUG = false,
    LOG_LIMIT = 50,
}

-- ============================================================
-- STATE
-- ============================================================
local isHarvesting = false
local autoLoop = false
local cachedTool = nil

local stats = {
    collected = 0,
    lastScanCount = 0,
    startTime = 0,
    ginseng = 0,
    spiritGrass = 0,
}

-- ============================================================
-- LOG SYSTEM
-- ============================================================
local LogScroll = nil
local ConsolePopup = nil
local logCount = 0

local function log(msg, color)
    if CONFIG.DEBUG then
        print("[Harvest] " .. tostring(msg))
    end
    
    if not LogScroll or not LogScroll.Parent or not ConsolePopup or not ConsolePopup.Visible then
        return
    end
    
    local newLabel = Instance.new("TextLabel")
    newLabel.Size = UDim2.new(1, -6, 0, 0)
    newLabel.AutomaticSize = Enum.AutomaticSize.Y
    newLabel.BackgroundTransparency = 1
    newLabel.TextColor3 = color or Color3.fromRGB(150, 255, 150)
    newLabel.Text = "> " .. tostring(msg)
    newLabel.TextSize = 10
    newLabel.Font = Enum.Font.Code
    newLabel.TextXAlignment = Enum.TextXAlignment.Left
    newLabel.TextWrapped = true
    newLabel.Parent = LogScroll
    
    logCount = logCount + 1
    LogScroll.CanvasPosition = Vector2.new(0, LogScroll.AbsoluteCanvasSize.Y)
    
    if logCount > CONFIG.LOG_LIMIT then
        for _, child in ipairs(LogScroll:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
                logCount = logCount - 1
                break
            end
        end
    end
end

-- ============================================================
-- UTILITY
-- ============================================================
local function updateCharacterRefs()
    character = player.Character or player.CharacterAdded:Wait()
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
end

local function getPlantType(name)
    local nameLower = string.lower(name)
    for _, plantName in ipairs(CONFIG.PLANT_NAMES) do
        if string.find(nameLower, string.lower(plantName)) then
            return plantName
        end
    end
    return nil
end

-- ============================================================
-- METODE 1: GetDescendants() SCAN
-- ============================================================
local function findPlantsByDescendants()
    local plants = {}
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if not obj or not obj.Parent then continue end
        
        local plantType = getPlantType(obj.Name)
        if plantType then
            local root = nil
            local prompt = nil
            local clickDetector = nil
            
            if obj:IsA("Model") then
                root = obj.PrimaryPart 
                    or obj:FindFirstChild("HumanoidRootPart")
                    or obj:FindFirstChild("Head")
                    or obj:FindFirstChild("Handle")
                    or obj:FindFirstChild("Base")
                    or obj:FindFirstChildWhichIsA("BasePart", true)
                    
                prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                clickDetector = obj:FindFirstChildWhichIsA("ClickDetector", true)
            elseif obj:IsA("BasePart") then
                root = obj
                prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                clickDetector = obj:FindFirstChildWhichIsA("ClickDetector", true)
            end
            
            if root then
                table.insert(plants, {
                    obj = obj,
                    root = root,
                    name = plantType,
                    prompt = prompt,
                    clickDetector = clickDetector,
                    method = "Descendants"
                })
            end
        end
    end
    
    return plants
end

-- ============================================================
-- METODE 2: CollectionService SCAN (HARVESTABLE TAGS)
-- ============================================================
local function findPlantsByTags()
    local plants = {}
    local seen = {}
    
    for _, tag in ipairs(CONFIG.HARVESTABLE_TAGS) do
        local taggedObjects = CollectionService:GetTagged(tag)
        
        for _, obj in ipairs(taggedObjects) do
            if obj and obj.Parent and not seen[obj] then
                seen[obj] = true
                
                local plantType = getPlantType(obj.Name)
                if plantType then
                    local root = nil
                    local prompt = nil
                    local clickDetector = nil
                    
                    if obj:IsA("Model") then
                        root = obj.PrimaryPart 
                            or obj:FindFirstChild("HumanoidRootPart")
                            or obj:FindFirstChild("Head")
                            or obj:FindFirstChild("Handle")
                            or obj:FindFirstChildWhichIsA("BasePart", true)
                    elseif obj:IsA("BasePart") then
                        root = obj
                    end
                    
                    if root then
                        prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        clickDetector = obj:FindFirstChildWhichIsA("ClickDetector", true)
                        
                        table.insert(plants, {
                            obj = obj,
                            root = root,
                            name = plantType,
                            prompt = prompt,
                            clickDetector = clickDetector,
                            method = "Tag: " .. tag
                        })
                    end
                end
            end
        end
    end
    
    return plants
end

-- ============================================================
-- MERGE + DEDUPLICATE
-- ============================================================
local function findAllPlants()
    local allPlants = {}
    local seenObjects = {}
    
    -- Metode 1: GetDescendants
    local descPlants = findPlantsByDescendants()
    for _, plant in ipairs(descPlants) do
        if not seenObjects[plant.obj] then
            seenObjects[plant.obj] = true
            table.insert(allPlants, plant)
        end
    end
    
    -- Metode 2: CollectionService Tags
    local tagPlants = findPlantsByTags()
    for _, plant in ipairs(tagPlants) do
        if not seenObjects[plant.obj] then
            seenObjects[plant.obj] = true
            table.insert(allPlants, plant)
        end
    end
    
    return allPlants
end

-- ============================================================
-- SERVER-SIDE REMOTE EVENT HARVEST
-- ============================================================
local function tryRemoteHarvest(plant)
    if not CONFIG.USE_REMOTE_EVENT then return false end
    
    local success = false
    
    -- Scan ReplicatedStorage buat RemoteEvent harvest
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local nameLower = string.lower(obj.Name)
                if string.find(nameLower, "harvest") 
                    or string.find(nameLower, "collect")
                    or string.find(nameLower, "plant")
                    or string.find(nameLower, "gather")
                    or string.find(nameLower, "pickup")
                    or string.find(nameLower, "grab") then
                    
                    pcall(function()
                        if obj:IsA("RemoteEvent") then
                            obj:FireServer(plant.obj)
                        elseif obj:IsA("RemoteFunction") then
                            obj:InvokeServer(plant.obj)
                        end
                        success = true
                    end)
                end
            end
        end
    end)
    
    -- Scan object plant sendiri buat RemoteEvent
    pcall(function()
        for _, child in ipairs(plant.obj:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                pcall(function()
                    child:FireServer()
                    success = true
                end)
            end
        end
    end)
    
    return success
end

-- ============================================================
-- HARVEST SATU PLANT
-- ============================================================
local function harvestPlant(plant)
    if not plant or not plant.obj or not plant.obj.Parent then return false end
    
    local harvested = false
    
    -- ═══ METODE 1: ProximityPrompt (LANGSUNG) ═══
    if plant.prompt then
        pcall(function()
            if CONFIG.FORCE_PROMPT_DISTANCE then
                plant.prompt.MaxActivationDistance = math.huge
                plant.prompt.HoldDuration = 0
                plant.prompt.RequiresLineOfSight = false
            end
            fireproximityprompt(plant.prompt)
            harvested = true
        end)
    end
    
    -- ═══ METODE 2: ClickDetector ═══
    if not harvested and plant.clickDetector then
        pcall(function()
            plant.clickDetector.MaxActivationDistance = math.huge
            fireclickdetector(plant.clickDetector)
            harvested = true
        end)
    end
    
    -- ═══ METODE 3: RemoteEvent ═══
    if not harvested and CONFIG.USE_REMOTE_EVENT then
        local remoteSuccess = tryRemoteHarvest(plant)
        if remoteSuccess then
            harvested = true
        end
    end
    
    return harvested
end

-- ============================================================
-- BATCH PROCESSING (PROSES BANYAK SEKALIGUS)
-- ============================================================
local function batchHarvest()
    local originalCFrame = nil
    if humanoidRootPart and humanoidRootPart.Parent then
        originalCFrame = humanoidRootPart.CFrame
    end
    
    local plants = findAllPlants()
    local totalFound = #plants
    
    if totalFound == 0 then
        return 0, totalFound
    end
    
    log("Mass Harvest: " .. totalFound .. " plants found", Color3.fromRGB(150, 255, 100))
    
    local totalHarvested = 0
    
    -- Process in batches
    local batchCount = math.ceil(totalFound / CONFIG.BATCH_SIZE)
    
    for batchIndex = 1, batchCount do
        if not isHarvesting then break end
        
        local startIdx = (batchIndex - 1) * CONFIG.BATCH_SIZE + 1
        local endIdx = math.min(batchIndex * CONFIG.BATCH_SIZE, totalFound)
        
        for i = startIdx, endIdx do
            if not isHarvesting then break end
            
            local plant = plants[i]
            if plant and plant.obj and plant.obj.Parent then
                
                -- Teleport ke plant (kalo perlu)
                if CONFIG.USE_TELEPORT and humanoidRootPart and plant.root then
                    pcall(function()
                        humanoidRootPart.CFrame = CFrame.new(plant.root.Position + Vector3.new(0, 3, 0))
                        humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
                    end)
                    task.wait(CONFIG.TELEPORT_DELAY)
                end
                
                -- Harvest
                if harvestPlant(plant) then
                    totalHarvested = totalHarvested + 1
                    
                    -- Update stats per jenis
                    if string.find(string.lower(plant.name), "ginseng") then
                        stats.ginseng = stats.ginseng + 1
                    elseif string.find(string.lower(plant.name), "spirit") then
                        stats.spiritGrass = stats.spiritGrass + 1
                    end
                end
                
                task.wait(CONFIG.FIRE_DELAY)
            end
        end
        
        -- Delay antar batch
        task.wait(CONFIG.BATCH_DELAY)
    end
    
    -- Balik ke posisi awal
    if CONFIG.USE_TELEPORT then
        pcall(function()
            if originalCFrame and humanoidRootPart and humanoidRootPart.Parent then
                humanoidRootPart.CFrame = originalCFrame
                humanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    end
    
    return totalHarvested, totalFound
end

-- ============================================================
-- MASS HARVEST SINGLE CALL
-- ============================================================
local function doMassHarvest()
    if isHarvesting then return end
    isHarvesting = true
    
    stats.startTime = tick()
    log("=== MASS HARVEST STARTED ===", Color3.fromRGB(0, 255, 100))
    
    local harvested, found = batchHarvest()
    
    stats.collected = stats.collected + harvested
    stats.lastScanCount = found
    
    log("Harvested: " .. harvested .. "/" .. found, Color3.fromRGB(100, 255, 150))
    
    isHarvesting = false
end

-- ============================================================
-- AUTO LOOP
-- ============================================================
local function startAutoLoop()
    if autoLoop then return end
    autoLoop = true
    
    log("Auto Loop STARTED", Color3.fromRGB(0, 200, 255))
    
    task.spawn(function()
        while autoLoop do
            if not isHarvesting then
                doMassHarvest()
            end
            task.wait(CONFIG.AUTO_SCAN_INTERVAL)
        end
    end)
end

local function stopAutoLoop()
    autoLoop = false
    log("Auto Loop STOPPED", Color3.fromRGB(255, 150, 100))
end

-- ============================================================
-- GUI - HORIZONTAL LAYOUT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MassHarvestGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 680, 0, 260)
MainFrame.Position = UDim2.new(0.5, -340, 0.5, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(40, 40, 55)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.Parent = MainFrame

local TitleBarCorner = Instance.new("UICorner")
TitleBarCorner.CornerRadius = UDim.new(0, 10)
TitleBarCorner.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(0, 220, 130)
Title.Text = "MASS HARVEST v6.0 - Script Created by ADIEL"
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -60, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Text = "_"
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -30, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Text = "X"
CloseBtn.TextSize = 13
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

-- ═══════════════════════════════════════════
-- 3 COLUMNS
-- ═══════════════════════════════════════════

-- ═══ COLUMN 1: STATS ═══
local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 200, 1, -50)
StatsFrame.Position = UDim2.new(0, 12, 0, 42)
StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
StatsFrame.BorderSizePixel = 0
StatsFrame.Parent = MainFrame

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 8)
StatsCorner.Parent = StatsFrame

local StatsTitle = Instance.new("TextLabel")
StatsTitle.Size = UDim2.new(1, -16, 0, 20)
StatsTitle.Position = UDim2.new(0, 8, 0, 8)
StatsTitle.BackgroundTransparency = 1
StatsTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
StatsTitle.Text = "STATISTIK"
StatsTitle.TextSize = 11
StatsTitle.Font = Enum.Font.GothamBold
StatsTitle.TextXAlignment = Enum.TextXAlignment.Left
StatsTitle.Parent = StatsFrame

local TotalLabel = Instance.new("TextLabel")
TotalLabel.Size = UDim2.new(1, -16, 0, 22)
TotalLabel.Position = UDim2.new(0, 8, 0, 32)
TotalLabel.BackgroundTransparency = 1
TotalLabel.TextColor3 = Color3.fromRGB(0, 220, 130)
TotalLabel.Text = "Total: 0"
TotalLabel.TextSize = 14
TotalLabel.Font = Enum.Font.GothamBold
TotalLabel.TextXAlignment = Enum.TextXAlignment.Left
TotalLabel.Parent = StatsFrame

local GinsengLabel = Instance.new("TextLabel")
GinsengLabel.Size = UDim2.new(1, -16, 0, 20)
GinsengLabel.Position = UDim2.new(0, 8, 0, 58)
GinsengLabel.BackgroundTransparency = 1
GinsengLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
GinsengLabel.Text = "Ginseng: 0"
GinsengLabel.TextSize = 11
GinsengLabel.Font = Enum.Font.Gotham
GinsengLabel.TextXAlignment = Enum.TextXAlignment.Left
GinsengLabel.Parent = StatsFrame

local SpiritLabel = Instance.new("TextLabel")
SpiritLabel.Size = UDim2.new(1, -16, 0, 20)
SpiritLabel.Position = UDim2.new(0, 8, 0, 78)
SpiritLabel.BackgroundTransparency = 1
SpiritLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
SpiritLabel.Text = "Spirit Grass: 0"
SpiritLabel.TextSize = 11
SpiritLabel.Font = Enum.Font.Gotham
SpiritLabel.TextXAlignment = Enum.TextXAlignment.Left
SpiritLabel.Parent = StatsFrame

local DetectedLabel = Instance.new("TextLabel")
DetectedLabel.Size = UDim2.new(1, -16, 0, 18)
DetectedLabel.Position = UDim2.new(0, 8, 0, 105)
DetectedLabel.BackgroundTransparency = 1
DetectedLabel.TextColor3 = Color3.fromRGB(140, 140, 180)
DetectedLabel.Text = "Last Scan: 0 plants"
DetectedLabel.TextSize = 10
DetectedLabel.Font = Enum.Font.Gotham
DetectedLabel.TextXAlignment = Enum.TextXAlignment.Left
DetectedLabel.Parent = StatsFrame

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(1, -16, 0, 18)
TimeLabel.Position = UDim2.new(0, 8, 0, 125)
TimeLabel.BackgroundTransparency = 1
TimeLabel.TextColor3 = Color3.fromRGB(140, 140, 180)
TimeLabel.Text = "Duration: 0s"
TimeLabel.TextSize = 10
TimeLabel.Font = Enum.Font.Gotham
TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
TimeLabel.Parent = StatsFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -16, 0, 40)
StatusLabel.Position = UDim2.new(0, 8, 0, 150)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.Text = "Status: IDLE"
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
StatusLabel.TextWrapped = true
StatusLabel.Parent = StatsFrame

-- ═══ COLUMN 2: ACTIONS ═══
local ActionsFrame = Instance.new("Frame")
ActionsFrame.Size = UDim2.new(0, 220, 1, -50)
ActionsFrame.Position = UDim2.new(0, 224, 0, 42)
ActionsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
ActionsFrame.BorderSizePixel = 0
ActionsFrame.Parent = MainFrame

local ActionsCorner = Instance.new("UICorner")
ActionsCorner.CornerRadius = UDim.new(0, 8)
ActionsCorner.Parent = ActionsFrame

local ActionsTitle = Instance.new("TextLabel")
ActionsTitle.Size = UDim2.new(1, -16, 0, 20)
ActionsTitle.Position = UDim2.new(0, 8, 0, 8)
ActionsTitle.BackgroundTransparency = 1
ActionsTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
ActionsTitle.Text = "MASS HARVEST"
ActionsTitle.TextSize = 11
ActionsTitle.Font = Enum.Font.GothamBold
ActionsTitle.TextXAlignment = Enum.TextXAlignment.Left
ActionsTitle.Parent = ActionsFrame

local HarvestBtn = Instance.new("TextButton")
HarvestBtn.Size = UDim2.new(1, -16, 0, 45)
HarvestBtn.Position = UDim2.new(0, 8, 0, 32)
HarvestBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
HarvestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HarvestBtn.Text = "HARVEST ALL SEKARANG"
HarvestBtn.TextSize = 13
HarvestBtn.Font = Enum.Font.GothamBold
HarvestBtn.Parent = ActionsFrame

local HarvestCorner = Instance.new("UICorner")
HarvestCorner.CornerRadius = UDim.new(0, 6)
HarvestCorner.Parent = HarvestBtn

local AutoLoopBtn = Instance.new("TextButton")
AutoLoopBtn.Size = UDim2.new(1, -16, 0, 38)
AutoLoopBtn.Position = UDim2.new(0, 8, 0, 85)
AutoLoopBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
AutoLoopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoLoopBtn.Text = "AUTO LOOP: OFF"
AutoLoopBtn.TextSize = 12
AutoLoopBtn.Font = Enum.Font.GothamBold
AutoLoopBtn.Parent = ActionsFrame

local AutoLoopCorner = Instance.new("UICorner")
AutoLoopCorner.CornerRadius = UDim.new(0, 6)
AutoLoopCorner.Parent = AutoLoopBtn

local ScanBtn = Instance.new("TextButton")
ScanBtn.Size = UDim2.new(1, -16, 0, 32)
ScanBtn.Position = UDim2.new(0, 8, 0, 131)
ScanBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
ScanBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
ScanBtn.Text = "SCAN PLANTS"
ScanBtn.TextSize = 12
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.Parent = ActionsFrame

local ScanCorner = Instance.new("UICorner")
ScanCorner.CornerRadius = UDim.new(0, 6)
ScanCorner.Parent = ScanBtn

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(1, -16, 0, 32)
ResetBtn.Position = UDim2.new(0, 8, 0, 171)
ResetBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 40)
ResetBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
ResetBtn.Text = "RESET STATS"
ResetBtn.TextSize = 12
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.Parent = ActionsFrame

local ResetCorner = Instance.new("UICorner")
ResetCorner.CornerRadius = UDim.new(0, 6)
ResetCorner.Parent = ResetBtn

local ConsoleBtn = Instance.new("TextButton")
ConsoleBtn.Size = UDim2.new(1, -16, 0, 32)
ConsoleBtn.Position = UDim2.new(0, 8, 0, 211)
ConsoleBtn.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
ConsoleBtn.TextColor3 = Color3.fromRGB(150, 220, 150)
ConsoleBtn.Text = "OPEN CONSOLE"
ConsoleBtn.TextSize = 12
ConsoleBtn.Font = Enum.Font.GothamBold
ConsoleBtn.Parent = ActionsFrame

local ConsoleCorner = Instance.new("UICorner")
ConsoleCorner.CornerRadius = UDim.new(0, 6)
ConsoleCorner.Parent = ConsoleBtn

-- ═══ COLUMN 3: INFO ═══
local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(0, 200, 1, -50)
InfoFrame.Position = UDim2.new(0, 456, 0, 42)
InfoFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
InfoFrame.BorderSizePixel = 0
InfoFrame.Parent = MainFrame

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 8)
InfoCorner.Parent = InfoFrame

local InfoTitle = Instance.new("TextLabel")
InfoTitle.Size = UDim2.new(1, -16, 0, 20)
InfoTitle.Position = UDim2.new(0, 8, 0, 8)
InfoTitle.BackgroundTransparency = 1
InfoTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
InfoTitle.Text = "INFORMASI"
InfoTitle.TextSize = 11
InfoTitle.Font = Enum.Font.GothamBold
InfoTitle.TextXAlignment = Enum.TextXAlignment.Left
InfoTitle.Parent = InfoFrame

local PlantListTitle = Instance.new("TextLabel")
PlantListTitle.Size = UDim2.new(1, -16, 0, 18)
PlantListTitle.Position = UDim2.new(0, 8, 0, 32)
PlantListTitle.BackgroundTransparency = 1
PlantListTitle.TextColor3 = Color3.fromRGB(140, 220, 140)
PlantListTitle.Text = "Plants:"
PlantListTitle.TextSize = 11
PlantListTitle.Font = Enum.Font.GothamBold
PlantListTitle.TextXAlignment = Enum.TextXAlignment.Left
PlantListTitle.Parent = InfoFrame

local PlantList = Instance.new("TextLabel")
PlantList.Size = UDim2.new(1, -16, 0, 40)
PlantList.Position = UDim2.new(0, 8, 0, 52)
PlantList.BackgroundTransparency = 1
PlantList.TextColor3 = Color3.fromRGB(200, 200, 220)
PlantList.Text = "- Ginseng\n- Spirit Grass"
PlantList.TextSize = 10
PlantList.Font = Enum.Font.Gotham
PlantList.TextXAlignment = Enum.TextXAlignment.Left
PlantList.TextYAlignment = Enum.TextYAlignment.Top
PlantList.TextWrapped = true
PlantList.Parent = InfoFrame

local MethodTitle = Instance.new("TextLabel")
MethodTitle.Size = UDim2.new(1, -16, 0, 18)
MethodTitle.Position = UDim2.new(0, 8, 0, 100)
MethodTitle.BackgroundTransparency = 1
MethodTitle.TextColor3 = Color3.fromRGB(140, 220, 140)
MethodTitle.Text = "Detection Methods:"
MethodTitle.TextSize = 11
MethodTitle.Font = Enum.Font.GothamBold
MethodTitle.TextXAlignment = Enum.TextXAlignment.Left
MethodTitle.Parent = InfoFrame

local MethodList = Instance.new("TextLabel")
MethodList.Size = UDim2.new(1, -16, 0, 60)
MethodList.Position = UDim2.new(0, 8, 0, 120)
MethodList.BackgroundTransparency = 1
MethodList.TextColor3 = Color3.fromRGB(200, 200, 220)
MethodList.Text = "- GetDescendants()\n- CollectionService\n- Batch Processing"
MethodList.TextSize = 10
MethodList.Font = Enum.Font.Gotham
MethodList.TextXAlignment = Enum.TextXAlignment.Left
MethodList.TextYAlignment = Enum.TextYAlignment.Top
MethodList.TextWrapped = true
MethodList.Parent = InfoFrame

local CreditLabel = Instance.new("TextLabel")
CreditLabel.Size = UDim2.new(1, -16, 0, 30)
CreditLabel.Position = UDim2.new(0, 8, 1, -40)
CreditLabel.BackgroundTransparency = 1
CreditLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
CreditLabel.Text = "Script Created by ADIEL"
CreditLabel.TextSize = 10
CreditLabel.Font = Enum.Font.GothamBold
CreditLabel.TextXAlignment = Enum.TextXAlignment.Left
CreditLabel.TextYAlignment = Enum.TextYAlignment.Bottom
CreditLabel.Parent = InfoFrame

-- ============================================================
-- CONSOLE POPUP
-- ============================================================
ConsolePopup = Instance.new("Frame")
ConsolePopup.Size = UDim2.new(0, 340, 0, 260)
ConsolePopup.Position = UDim2.new(0.5, -170, 0.5, -130)
ConsolePopup.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
ConsolePopup.BorderSizePixel = 0
ConsolePopup.Visible = false
ConsolePopup.ZIndex = 20
ConsolePopup.Active = true
ConsolePopup.Parent = ScreenGui

local ConsolePopupCorner = Instance.new("UICorner")
ConsolePopupCorner.CornerRadius = UDim.new(0, 10)
ConsolePopupCorner.Parent = ConsolePopup

local ConsoleTitle = Instance.new("Frame")
ConsoleTitle.Size = UDim2.new(1, 0, 0, 30)
ConsoleTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ConsoleTitle.BorderSizePixel = 0
ConsoleTitle.ZIndex = 21
ConsoleTitle.Active = true
ConsoleTitle.Parent = ConsolePopup

local ConsoleTitleCorner = Instance.new("UICorner")
ConsoleTitleCorner.CornerRadius = UDim.new(0, 10)
ConsoleTitleCorner.Parent = ConsoleTitle

local ConsoleTitleLabel = Instance.new("TextLabel")
ConsoleTitleLabel.Size = UDim2.new(1, -100, 1, 0)
ConsoleTitleLabel.Position = UDim2.new(0, 10, 0, 0)
ConsoleTitleLabel.BackgroundTransparency = 1
ConsoleTitleLabel.TextColor3 = Color3.fromRGB(0, 220, 130)
ConsoleTitleLabel.Text = "CONSOLE"
ConsoleTitleLabel.TextSize = 12
ConsoleTitleLabel.Font = Enum.Font.GothamBold
ConsoleTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
ConsoleTitleLabel.ZIndex = 22
ConsoleTitleLabel.Parent = ConsoleTitle

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0, 50, 0, 22)
ClearBtn.Position = UDim2.new(1, -85, 0, 4)
ClearBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 45)
ClearBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
ClearBtn.Text = "CLEAR"
ClearBtn.TextSize = 10
ClearBtn.Font = Enum.Font.GothamBold
ClearBtn.ZIndex = 22
ClearBtn.Parent = ConsoleTitle

local ClearCorner = Instance.new("UICorner")
ClearCorner.CornerRadius = UDim.new(0, 4)
ClearCorner.Parent = ClearBtn

local ConsoleClose = Instance.new("TextButton")
ConsoleClose.Size = UDim2.new(0, 25, 0, 22)
ConsoleClose.Position = UDim2.new(1, -28, 0, 4)
ConsoleClose.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ConsoleClose.TextColor3 = Color3.fromRGB(255, 255, 255)
ConsoleClose.Text = "X"
ConsoleClose.TextSize = 12
ConsoleClose.Font = Enum.Font.GothamBold
ConsoleClose.ZIndex = 22
ConsoleClose.Parent = ConsoleTitle

local ConsoleCloseCorner = Instance.new("UICorner")
ConsoleCloseCorner.CornerRadius = UDim.new(0, 4)
ConsoleCloseCorner.Parent = ConsoleClose

LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -10, 1, -40)
LogScroll.Position = UDim2.new(0, 5, 0, 35)
LogScroll.BackgroundTransparency = 1
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.ScrollBarThickness = 4
LogScroll.ZIndex = 21
LogScroll.Parent = ConsolePopup

local LogList = Instance.new("UIListLayout")
LogList.Padding = UDim.new(0, 2)
LogList.Parent = LogScroll

-- ============================================================
-- FLOATING BUBBLE
-- ============================================================
local Bubble = Instance.new("TextButton")
Bubble.Name = "FloatingBubble"
Bubble.Size = UDim2.new(0, 50, 0, 50)
Bubble.Position = UDim2.new(0, 20, 0, 100)
Bubble.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
Bubble.TextColor3 = Color3.fromRGB(255, 255, 255)
Bubble.Text = "H"
Bubble.TextSize = 20
Bubble.Font = Enum.Font.GothamBold
Bubble.Visible = false
Bubble.Active = true
Bubble.Parent = ScreenGui

local BubbleCorner = Instance.new("UICorner")
BubbleCorner.CornerRadius = UDim.new(1, 0)
BubbleCorner.Parent = Bubble

local BubbleStroke = Instance.new("UIStroke")
BubbleStroke.Color = Color3.fromRGB(0, 220, 130)
BubbleStroke.Thickness = 2
BubbleStroke.Parent = Bubble

-- ============================================================
-- DRAGGABLE
-- ============================================================
local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
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
end

makeDraggable(MainFrame, TitleBar)
makeDraggable(Bubble, Bubble)
makeDraggable(ConsolePopup, ConsoleTitle)

-- ============================================================
-- REAL-TIME STATS UPDATE
-- ============================================================
task.spawn(function()
    while task.wait(0.5) do
        TotalLabel.Text = "Total: " .. stats.collected
        GinsengLabel.Text = "Ginseng: " .. stats.ginseng
        SpiritLabel.Text = "Spirit Grass: " .. stats.spiritGrass
        DetectedLabel.Text = "Last Scan: " .. stats.lastScanCount .. " plants"
        
        if stats.startTime > 0 then
            local elapsed = math.floor(tick() - stats.startTime)
            TimeLabel.Text = "Duration: " .. elapsed .. "s"
        end
    end
end)

-- ============================================================
-- EVENT HANDLERS
-- ============================================================
HarvestBtn.MouseButton1Click:Connect(function()
    if isHarvesting then
        log("Harvest in progress...", Color3.fromRGB(255, 200, 100))
        return
    end
    
    HarvestBtn.Text = "HARVESTING..."
    HarvestBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 30)
    StatusLabel.Text = "Status: HARVESTING"
    StatusLabel.TextColor3 = Color3.fromRGB(0, 220, 100)
    
    task.spawn(function()
        doMassHarvest()
        
        HarvestBtn.Text = "HARVEST ALL SEKARANG"
        HarvestBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
        
        if autoLoop then
            StatusLabel.Text = "Status: AUTO LOOP"
        else
            StatusLabel.Text = "Status: IDLE"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end)

AutoLoopBtn.MouseButton1Click:Connect(function()
    if autoLoop then
        stopAutoLoop()
        AutoLoopBtn.Text = "AUTO LOOP: OFF"
        AutoLoopBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        StatusLabel.Text = "Status: IDLE"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        startAutoLoop()
        AutoLoopBtn.Text = "AUTO LOOP: ON"
        AutoLoopBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 0)
        StatusLabel.Text = "Status: AUTO LOOP"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 220, 100)
    end
end)

ScanBtn.MouseButton1Click:Connect(function()
    ScanBtn.Text = "SCANNING..."
    task.wait(0.1)
    
    local plants = findAllPlants()
    stats.lastScanCount = #plants
    
    if #plants > 0 then
        -- Hitung per jenis
        local ginsengCount = 0
        local spiritCount = 0
        for _, p in ipairs(plants) do
            if string.find(string.lower(p.name), "ginseng") then
                ginsengCount = ginsengCount + 1
            elseif string.find(string.lower(p.name), "spirit") then
                spiritCount = spiritCount + 1
            end
        end
        
        log("Found " .. #plants .. " plants (Ginseng: " .. ginsengCount .. ", Spirit Grass: " .. spiritCount .. ")", Color3.fromRGB(150, 255, 100))
    else
        log("No plants found", Color3.fromRGB(255, 200, 100))
    end
    
    ScanBtn.Text = "SCAN PLANTS"
end)

ResetBtn.MouseButton1Click:Connect(function()
    stats.collected = 0
    stats.ginseng = 0
    stats.spiritGrass = 0
    stats.lastScanCount = 0
    stats.startTime = 0
    
    TotalLabel.Text = "Total: 0"
    GinsengLabel.Text = "Ginseng: 0"
    SpiritLabel.Text = "Spirit Grass: 0"
    DetectedLabel.Text = "Last Scan: 0 plants"
    TimeLabel.Text = "Duration: 0s"
    
    log("Stats reset", Color3.fromRGB(200, 200, 200))
end)

ConsoleBtn.MouseButton1Click:Connect(function()
    ConsolePopup.Visible = not ConsolePopup.Visible
end)

ClearBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(LogScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    logCount = 0
end)

ConsoleClose.MouseButton1Click:Connect(function()
    ConsolePopup.Visible = false
end)

MinBtn.MouseButton1Click:Connect(function()
    if MainFrame.Size.Y.Offset > 50 then
        MainFrame.Size = UDim2.new(0, 680, 0, 35)
        MinBtn.Text = "o"
    else
        MainFrame.Size = UDim2.new(0, 680, 0, 260)
        MinBtn.Text = "_"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    Bubble.Position = MainFrame.Position
    Bubble.Visible = true
end)

Bubble.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    Bubble.Visible = false
end)

-- ============================================================
-- ANTI-AFK
-- ============================================================
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0))
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0))
    end)
end)

-- ============================================================
-- DONE
-- ============================================================
print("=========================================")
print("  MASS HARVEST v6.0")
print("  Script Created by ADIEL")
print("=========================================")
print("Plants: Ginseng, Spirit Grass")
print("Methods: GetDescendants + CollectionService + Batch")
