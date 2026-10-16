--[[
================================================================================
    TRUE MASS HARVEST v6.1
    Script Created by ADIEL
    
    Executor    : Delta / Codex / Wave / Xeno (Mobile Android)
    Mode        : NO TELEPORT - Distance Harvest
    Target      : Ginseng / Spirit Grass / SpiritGrass
    Load        : loadstring(game:HttpGet("URL"))()
================================================================================
]]

--==============================================================================
-- SECTION 1 : HEADER + CREDIT
--==============================================================================
-- Script Created by ADIEL
-- TRUE MASS HARVEST v6.1 - Distance Harvest Engine
-- Compatible: Delta, Codex, Wave, Xeno

--==============================================================================
-- SECTION 2 : SERVICES
--==============================================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")

local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

--==============================================================================
-- SECTION 3 : CONFIG TABLE
--==============================================================================
local CONFIG = {
    PLANT_NAMES       = {"Ginseng", "Spirit Grass", "SpiritGrass"},
    HARVESTABLE_TAGS  = {"Harvestable", "Plant", "Herb", "Collectable", "Resource"},
    REMOTE_KEYWORDS   = {"harvest", "collect", "plant", "gather", "pickup", "grab", "herb", "pluck", "reap"},
    BATCH_SIZE        = 30,
    BATCH_DELAY       = 0.02,
    FIRE_DELAY        = 0.03,
    FORCE_DISTANCE    = 999999,
    MAX_DEPTH         = 10,
    AUTO_SCAN_INTERVAL = 3,
    DEBUG             = false,
    LOG_LIMIT         = 50,
}

--==============================================================================
-- SECTION 4 : STATE VARIABLES
--==============================================================================
local stats = {
    collected    = 0,
    lastScanCount = 0,
    startTime    = 0,
    ginseng      = 0,
    spiritGrass  = 0,
    lastDuration = 0,
}

local STATE = {
    autoLoopActive = false,
    autoLoopThread = nil,
    isHarvesting   = false,
    guiVisible     = true,
    consoleVisible = false,
    character      = nil,
    humanoid       = nil,
    rootPart       = nil,
    logs           = {},
}

local GUI_REFS = {
    ScreenGui  = nil,
    MainFrame  = nil,
    Bubble     = nil,
    Console    = nil,
    Labels     = {},
    Buttons    = {},
    LogFrame   = nil,
    LogLayout  = nil,
}

--==============================================================================
-- SECTION 5 : LOG SYSTEM
--==============================================================================
local function log(msg, logType)
    logType = logType or "info"
    local prefix = "[TRUE MASS HARVEST] "
    local fullMsg = prefix .. tostring(msg)
    
    if logType == "success" then
        print(fullMsg)
    elseif logType == "error" then
        warn(fullMsg)
    else
        print(fullMsg)
    end
    
    if GUI_REFS.LogFrame then
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -6, 0, 18)
        entry.BackgroundTransparency = 1
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextScaled = false
        entry.TextSize = 12
        entry.Font = Enum.Font.Code
        entry.Text = "[" .. logType:upper() .. "] " .. tostring(msg)
        
        if logType == "success" then
            entry.TextColor3 = Color3.fromRGB(0, 220, 130)
        elseif logType == "error" then
            entry.TextColor3 = Color3.fromRGB(240, 80, 80)
        elseif logType == "warn" then
            entry.TextColor3 = Color3.fromRGB(240, 200, 80)
        else
            entry.TextColor3 = Color3.fromRGB(120, 180, 240)
        end
        
        entry.Parent = GUI_REFS.LogFrame
        
        table.insert(STATE.logs, entry)
        if #STATE.logs > CONFIG.LOG_LIMIT then
            local old = table.remove(STATE.logs, 1)
            if old and old.Parent then
                old:Destroy()
            end
        end
    end
end

--==============================================================================
-- SECTION 6 : UTILITY FUNCTIONS
--==============================================================================
local function updateCharacterRefs()
    local char = LocalPlayer.Character
    if char then
        STATE.character = char
        STATE.humanoid  = char:FindFirstChildOfClass("Humanoid")
        STATE.rootPart  = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    end
end

local function getPlantType(plantObj)
    local name = ""
    if plantObj and plantObj.Name then
        name = string.lower(plantObj.Name)
    end
    
    if string.find(name, "ginseng") then
        return "Ginseng"
    elseif string.find(name, "spirit") or string.find(name, "grass") then
        return "Spirit Grass"
    end
    
    return "Unknown"
end

local function isPlantName(objName)
    if not objName then return false end
    local lowerName = string.lower(objName)
    for _, plantName in ipairs(CONFIG.PLANT_NAMES) do
        if string.find(lowerName, string.lower(plantName), 1, true) then
            return true
        end
    end
    return false
end

local function getRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj.PrimaryPart then return obj.PrimaryPart end
    if obj:FindFirstChild("HumanoidRootPart") then return obj.HumanoidRootPart end
    if obj:FindFirstChild("Head") then return obj.Head end
    if obj:FindFirstChild("Handle") then return obj.Handle end
    if obj:FindFirstChild("Base") then return obj.Base end
    local found = obj:FindFirstChildWhichIsA("BasePart", true)
    return found
end

local function safeDestroy(inst)
    pcall(function()
        if inst and inst.Parent then
            inst:Destroy()
        end
    end)
end

--==============================================================================
-- SECTION 7 : DETECTION 1 - GetDescendants
--==============================================================================
local function findPlantsByDescendants()
    local found = {}
    local descendants = {}
    
    local ok = pcall(function()
        descendants = Workspace:GetDescendants()
    end)
    
    if not ok then return found end
    
    for _, obj in ipairs(descendants) do
        if not obj or not obj.Parent then continue end
        
        local isMatch = false
        
        if isPlantName(obj.Name) then
            isMatch = true
        end
        
        if not isMatch and obj:IsA("Model") then
            if isPlantName(obj.Name) then
                isMatch = true
            end
        end
        
        if isMatch then
            local root = getRootPart(obj)
            if root then
                table.insert(found, {
                    obj = obj,
                    root = root,
                    type = getPlantType(obj),
                })
            end
        end
    end
    
    return found
end

--==============================================================================
-- SECTION 8 : DETECTION 2 - CollectionService Tags
--==============================================================================
local function findPlantsByTags()
    local found = {}
    
    for _, tag in ipairs(CONFIG.HARVESTABLE_TAGS) do
        local tagged = {}
        local ok = pcall(function()
            tagged = CollectionService:GetTagged(tag)
        end)
        
        if ok and tagged then
            for _, obj in ipairs(tagged) do
                if obj and obj.Parent then
                    local root = getRootPart(obj)
                    if root then
                        table.insert(found, {
                            obj = obj,
                            root = root,
                            type = getPlantType(obj),
                        })
                    end
                end
            end
        end
    end
    
    return found
end

--==============================================================================
-- SECTION 9 : MERGE + DEDUPLICATE
--==============================================================================
local function findAllPlants()
    local merged = {}
    local seen = {}
    
    local descPlants = findPlantsByDescendants()
    for _, p in ipairs(descPlants) do
        if p.obj and not seen[p.obj] then
            seen[p.obj] = true
            table.insert(merged, p)
        end
    end
    
    local tagPlants = findPlantsByTags()
    for _, p in ipairs(tagPlants) do
        if p.obj and not seen[p.obj] then
            seen[p.obj] = true
            table.insert(merged, p)
        end
    end
    
    return merged
end

--==============================================================================
-- SECTION 10 : REMOTE HARVEST
--==============================================================================
local function tryRemoteHarvest(plant)
    if not plant or not plant.obj then return false end
    
    local remoteContainers = {ReplicatedStorage, ServerStorage, ServerScriptService}
    local fired = false
    
    for _, container in ipairs(remoteContainers) do
        local ok, children = pcall(function()
            return container:GetDescendants()
        end)
        
        if ok and children then
            for _, obj in ipairs(children) do
                if not fired and obj and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                    local lowerName = string.lower(obj.Name)
                    for _, keyword in ipairs(CONFIG.REMOTE_KEYWORDS) do
                        if string.find(lowerName, keyword, 1, true) then
                            pcall(function()
                                if obj:IsA("RemoteEvent") then
                                    obj:FireServer(plant.obj)
                                    obj:FireServer(plant.root)
                                    obj:FireServer(plant.obj, plant.root)
                                elseif obj:IsA("RemoteFunction") then
                                    obj:InvokeServer(plant.obj)
                                end
                            end)
                            fired = true
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- Scan remotes inside plant object
    if not fired and plant.obj then
        local ok2, inside = pcall(function()
            return plant.obj:GetDescendants()
        end)
        if ok2 and inside then
            for _, obj in ipairs(inside) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    pcall(function()
                        if obj:IsA("RemoteEvent") then
                            obj:FireServer()
                            obj:FireServer(plant.obj)
                        elseif obj:IsA("RemoteFunction") then
                            obj:InvokeServer()
                        end
                    end)
                    fired = true
                end
            end
        end
    end
    
    return fired
end

--==============================================================================
-- SECTION 11 : HARVEST PLANT - 5 METHODS
--==============================================================================
local function harvestPlant(plant)
    if not plant or not plant.obj or not plant.obj.Parent then
        return false
    end
    
    if not plant.root or not plant.root.Parent then
        return false
    end
    
    local success = false
    
    -- METHOD 1 : Force ProximityPrompt
    local prompt = plant.obj:FindFirstChildOfClass("ProximityPrompt")
    if not prompt and plant.obj:IsA("Model") then
        prompt = plant.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    end
    
    if prompt then
        pcall(function()
            prompt.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.Enabled = true
        end)
        
        pcall(function()
            fireproximityprompt(prompt)
        end)
        
        success = true
    end
    
    -- METHOD 2 : ProximityPrompt Recursive (fallback deeper)
    if not success then
        local deepPrompt = nil
        pcall(function()
            deepPrompt = plant.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        end)
        
        if deepPrompt then
            pcall(function()
                deepPrompt.MaxActivationDistance = CONFIG.FORCE_DISTANCE
                deepPrompt.HoldDuration = 0
                deepPrompt.RequiresLineOfSight = false
                deepPrompt.Enabled = true
            end)
            pcall(function()
                fireproximityprompt(deepPrompt)
            end)
            success = true
        end
    end
    
    -- METHOD 3 : Force ClickDetector
    if not success then
        local cd = plant.obj:FindFirstChildOfClass("ClickDetector")
        if cd then
            pcall(function()
                cd.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            end)
            pcall(function()
                fireclickdetector(cd)
            end)
            success = true
        end
    end
    
    -- METHOD 4 : ClickDetector Recursive
    if not success then
        local deepCd = nil
        pcall(function()
            deepCd = plant.obj:FindFirstChildWhichIsA("ClickDetector", true)
        end)
        if deepCd then
            pcall(function()
                deepCd.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            end)
            pcall(function()
                fireclickdetector(deepCd)
            end)
            success = true
        end
    end
    
    -- METHOD 5 : RemoteEvent / RemoteFunction
    if not success then
        success = tryRemoteHarvest(plant)
    end
    
    return success
end

--==============================================================================
-- SECTION 12 : BATCH PROCESSING
--==============================================================================
local function batchHarvest(plants)
    if not plants or #plants == 0 then return 0 end
    
    local totalHarvested = 0
    local totalBatches = math.ceil(#plants / CONFIG.BATCH_SIZE)
    
    for batchIndex = 1, totalBatches do
        local startIdx = (batchIndex - 1) * CONFIG.BATCH_SIZE + 1
        local endIdx = math.min(batchIndex * CONFIG.BATCH_SIZE, #plants)
        
        for i = startIdx, endIdx do
            local plant = plants[i]
            if plant and plant.obj and plant.obj.Parent then
                local ok = pcall(function()
                    harvestPlant(plant)
                end)
                
                if ok then
                    totalHarvested = totalHarvested + 1
                    
                    local plantType = plant.type or "Unknown"
                    if plantType == "Ginseng" then
                        stats.ginseng = stats.ginseng + 1
                    elseif plantType == "Spirit Grass" then
                        stats.spiritGrass = stats.spiritGrass + 1
                    end
                end
                
                task.wait(CONFIG.FIRE_DELAY)
            end
        end
        
        task.wait(CONFIG.BATCH_DELAY)
    end
    
    return totalHarvested
end

--==============================================================================
-- SECTION 13 : MASS HARVEST WRAPPER
--==============================================================================
local function doMassHarvest()
    if STATE.isHarvesting then
        log("Harvest sudah berjalan, tunggu selesai.", "warn")
        return
    end
    
    STATE.isHarvesting = true
    local startTime = tick()
    
    log("Scanning plants di seluruh map...", "info")
    
    local plants = findAllPlants()
    stats.lastScanCount = #plants
    
    log("Ditemukan " .. tostring(#plants) .. " plants", "info")
    
    if #plants == 0 then
        log("Tidak ada plant yang ditemukan.", "warn")
        STATE.isHarvesting = false
        return
    end
    
    log("Memulai mass harvest " .. tostring(#plants) .. " plants...", "info")
    
    local harvested = batchHarvest(plants)
    
    stats.collected = stats.collected + harvested
    stats.lastDuration = tick() - startTime
    
    log("Harvest selesai: " .. tostring(harvested) .. " plants dalam " .. string.format("%.2f", stats.lastDuration) .. "s", "success")
    
    STATE.isHarvesting = false
end

--==============================================================================
-- SECTION 14 : AUTO LOOP
--==============================================================================
local function startAutoLoop()
    if STATE.autoLoopThread then
        task.cancel(STATE.autoLoopThread)
        STATE.autoLoopThread = nil
    end
    
    STATE.autoLoopActive = true
    
    STATE.autoLoopThread = task.spawn(function()
        while STATE.autoLoopActive do
            pcall(function()
                doMassHarvest()
            end)
            
            local waited = 0
            while waited < CONFIG.AUTO_SCAN_INTERVAL and STATE.autoLoopActive do
                task.wait(0.1)
                waited = waited + 0.1
            end
        end
    end)
    
    log("Auto loop: ON (interval " .. tostring(CONFIG.AUTO_SCAN_INTERVAL) .. "s)", "success")
end

local function stopAutoLoop()
    STATE.autoLoopActive = false
    if STATE.autoLoopThread then
        pcall(function()
            task.cancel(STATE.autoLoopThread)
        end)
        STATE.autoLoopThread = nil
    end
    log("Auto loop: OFF", "warn")
end

--==============================================================================
-- SECTION 15 : GUI SETUP
--==============================================================================
local function createGUI()
    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrueMassHarvest_ADIEL"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    GUI_REFS.ScreenGui = screenGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 680, 0, 260)
    mainFrame.Position = UDim2.new(0.5, -340, 0.5, -130)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui
    GUI_REFS.MainFrame = mainFrame
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(40, 40, 55)
    mainStroke.Thickness = 1
    mainStroke.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local titleMask = Instance.new("Frame")
    titleMask.Size = UDim2.new(1, 0, 0, 12)
    titleMask.Position = UDim2.new(0, 0, 1, -12)
    titleMask.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    titleMask.BorderSizePixel = 0
    titleMask.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -90, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "TRUE MASS HARVEST v6.1 - Script Created by ADIEL"
    titleLabel.TextColor3 = Color3.fromRGB(0, 220, 130)
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 25)
    minBtn.Position = UDim2.new(1, -70, 0, 5)
    minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    minBtn.BorderSizePixel = 0
    minBtn.Text = "_"
    minBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    minBtn.TextSize = 16
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Parent = titleBar
    GUI_REFS.Buttons.minBtn = minBtn
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 5)
    minCorner.Parent = minBtn
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 25)
    closeBtn.Position = UDim2.new(1, -36, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    GUI_REFS.Buttons.closeBtn = closeBtn
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    
    --==============================================================
    -- COLUMN 1 : STATISTIK
    --==============================================================
    local col1 = Instance.new("Frame")
    col1.Name = "Col1_Stats"
    col1.Size = UDim2.new(0, 200, 0, 210)
    col1.Position = UDim2.new(0, 12, 0, 42)
    col1.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    col1.BorderSizePixel = 0
    col1.Parent = mainFrame
    
    local col1Corner = Instance.new("UICorner")
    col1Corner.CornerRadius = UDim.new(0, 8)
    col1Corner.Parent = col1
    
    local col1Title = Instance.new("TextLabel")
    col1Title.Size = UDim2.new(1, -16, 0, 22)
    col1Title.Position = UDim2.new(0, 8, 0, 6)
    col1Title.BackgroundTransparency = 1
    col1Title.Text = "STATISTIK"
    col1Title.TextColor3 = Color3.fromRGB(0, 200, 255)
    col1Title.TextSize = 14
    col1Title.Font = Enum.Font.GothamBold
    col1Title.TextXAlignment = Enum.TextXAlignment.Left
    col1Title.Parent = col1
    
    local function makeStatLabel(name, yPos, color)
        local lbl = Instance.new("TextLabel")
        lbl.Name = name
        lbl.Size = UDim2.new(1, -16, 0, 20)
        lbl.Position = UDim2.new(0, 8, 0, yPos)
        lbl.BackgroundTransparency = 1
        lbl.Text = name .. ": 0"
        lbl.TextColor3 = color
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Code
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = col1
        return lbl
    end
    
    GUI_REFS.Labels.total      = makeStatLabel("Total", 34, Color3.fromRGB(0, 220, 130))
    GUI_REFS.Labels.total.TextSize = 14
    GUI_REFS.Labels.ginseng    = makeStatLabel("Ginseng", 58, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.spirit     = makeStatLabel("Spirit Grass", 80, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.lastScan   = makeStatLabel("Last Scan", 102, Color3.fromRGB(180, 180, 200))
    GUI_REFS.Labels.duration   = makeStatLabel("Duration", 124, Color3.fromRGB(180, 180, 200))
    GUI_REFS.Labels.status     = makeStatLabel("Status", 150, Color3.fromRGB(0, 220, 130))
    GUI_REFS.Labels.status.Text = "Status: IDLE"
    
    --==============================================================
    -- COLUMN 2 : ACTIONS
    --==============================================================
    local col2 = Instance.new("Frame")
    col2.Name = "Col2_Actions"
    col2.Size = UDim2.new(0, 220, 0, 210)
    col2.Position = UDim2.new(0, 224, 0, 42)
    col2.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    col2.BorderSizePixel = 0
    col2.Parent = mainFrame
    
    local col2Corner = Instance.new("UICorner")
    col2Corner.CornerRadius = UDim.new(0, 8)
    col2Corner.Parent = col2
    
    local col2Title = Instance.new("TextLabel")
    col2Title.Size = UDim2.new(1, -16, 0, 22)
    col2Title.Position = UDim2.new(0, 8, 0, 6)
    col2Title.BackgroundTransparency = 1
    col2Title.Text = "MASS HARVEST"
    col2Title.TextColor3 = Color3.fromRGB(0, 200, 255)
    col2Title.TextSize = 14
    col2Title.Font = Enum.Font.GothamBold
    col2Title.TextXAlignment = Enum.TextXAlignment.Left
    col2Title.Parent = col2
    
    local function makeButton(name, text, yPos, height, color)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(1, -16, 0, height)
        btn.Position = UDim2.new(0, 8, 0, yPos)
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.Parent = col2
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        
        return btn
    end
    
    GUI_REFS.Buttons.harvestAll = makeButton("HarvestAll", "HARVEST ALL SEKARANG", 34, 45, Color3.fromRGB(0, 160, 90))
    GUI_REFS.Buttons.autoLoop   = makeButton("AutoLoop", "AUTO LOOP: OFF", 86, 30, Color3.fromRGB(0, 110, 180))
    GUI_REFS.Buttons.scan       = makeButton("Scan", "SCAN PLANTS", 122, 30, Color3.fromRGB(60, 50, 90))
    GUI_REFS.Buttons.reset      = makeButton("Reset", "RESET STATS", 158, 30, Color3.fromRGB(70, 40, 40))
    GUI_REFS.Buttons.console    = makeButton("Console", "OPEN CONSOLE", 194, 12, Color3.fromRGB(35, 60, 35))
    GUI_REFS.Buttons.console.TextSize = 10
    
    --==============================================================
    -- COLUMN 3 : INFO
    --==============================================================
    local col3 = Instance.new("Frame")
    col3.Name = "Col3_Info"
    col3.Size = UDim2.new(0, 200, 0, 210)
    col3.Position = UDim2.new(0, 456, 0, 42)
    col3.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    col3.BorderSizePixel = 0
    col3.Parent = mainFrame
    
    local col3Corner = Instance.new("UICorner")
    col3Corner.CornerRadius = UDim.new(0, 8)
    col3Corner.Parent = col3
    
    local col3Title = Instance.new("TextLabel")
    col3Title.Size = UDim2.new(1, -16, 0, 22)
    col3Title.Position = UDim2.new(0, 8, 0, 6)
    col3Title.BackgroundTransparency = 1
    col3Title.Text = "INFORMASI"
    col3Title.TextColor3 = Color3.fromRGB(0, 200, 255)
    col3Title.TextSize = 14
    col3Title.Font = Enum.Font.GothamBold
    col3Title.TextXAlignment = Enum.TextXAlignment.Left
    col3Title.Parent = col3
    
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -16, 0, 130)
    infoText.Position = UDim2.new(0, 8, 0, 32)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Plants:\n- Ginseng\n- Spirit Grass\n\nDetection:\n- GetDescendants\n- CollectionService\n- Batch Processing\n\nMode: NO TELEPORT"
    infoText.TextColor3 = Color3.fromRGB(180, 180, 200)
    infoText.TextSize = 11
    infoText.Font = Enum.Font.Code
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = col3
    
    local creditLabel = Instance.new("TextLabel")
    creditLabel.Size = UDim2.new(1, -16, 0, 20)
    creditLabel.Position = UDim2.new(0, 8, 1, -26)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Text = "Script Created by ADIEL"
    creditLabel.TextColor3 = Color3.fromRGB(100, 100, 130)
    creditLabel.TextSize = 11
    creditLabel.Font = Enum.Font.Gotham
    creditLabel.TextXAlignment = Enum.TextXAlignment.Left
    creditLabel.Parent = col3
    
    return screenGui
end

--==============================================================================
-- SECTION 16 : POPUP CONSOLE + FLOATING BUBBLE
--==============================================================================
local function createConsolePopup()
    local consoleFrame = Instance.new("Frame")
    consoleFrame.Name = "ConsolePopup"
    consoleFrame.Size = UDim2.new(0, 340, 0, 260)
    consoleFrame.Position = UDim2.new(0.5, -170, 0.5, -130)
    consoleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    consoleFrame.BorderSizePixel = 0
    consoleFrame.Visible = false
    consoleFrame.Active = true
    consoleFrame.ZIndex = 50
    consoleFrame.Parent = GUI_REFS.ScreenGui
    GUI_REFS.Console = consoleFrame
    
    local consoleCorner = Instance.new("UICorner")
    consoleCorner.CornerRadius = UDim.new(0, 10)
    consoleCorner.Parent = consoleFrame
    
    local consoleStroke = Instance.new("UIStroke")
    consoleStroke.Color = Color3.fromRGB(60, 100, 60)
    consoleStroke.Thickness = 1
    consoleStroke.Parent = consoleFrame
    
    -- Console Title Bar
    local consoleTitle = Instance.new("Frame")
    consoleTitle.Name = "ConsoleTitle"
    consoleTitle.Size = UDim2.new(1, 0, 0, 30)
    consoleTitle.BackgroundColor3 = Color3.fromRGB(22, 32, 22)
    consoleTitle.BorderSizePixel = 0
    consoleTitle.Active = true
    consoleTitle.Parent = consoleFrame
    
    local consoleTitleCorner = Instance.new("UICorner")
    consoleTitleCorner.CornerRadius = UDim.new(0, 10)
    consoleTitleCorner.Parent = consoleTitle
    
    local consoleTitleText = Instance.new("TextLabel")
    consoleTitleText.Size = UDim2.new(1, -80, 1, 0)
    consoleTitleText.Position = UDim2.new(0, 10, 0, 0)
    consoleTitleText.BackgroundTransparency = 1
    consoleTitleText.Text = "CONSOLE LOG"
    consoleTitleText.TextColor3 = Color3.fromRGB(0, 220, 130)
    consoleTitleText.TextSize = 12
    consoleTitleText.Font = Enum.Font.GothamBold
    consoleTitleText.TextXAlignment = Enum.TextXAlignment.Left
    consoleTitleText.Parent = consoleTitle
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 45, 0, 22)
    clearBtn.Position = UDim2.new(1, -76, 0, 4)
    clearBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    clearBtn.BorderSizePixel = 0
    clearBtn.Text = "CLEAR"
    clearBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    clearBtn.TextSize = 10
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = consoleTitle
    GUI_REFS.Buttons.clearBtn = clearBtn
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 4)
    clearCorner.Parent = clearBtn
    
    local closeConsoleBtn = Instance.new("TextButton")
    closeConsoleBtn.Size = UDim2.new(0, 22, 0, 22)
    closeConsoleBtn.Position = UDim2.new(1, -26, 0, 4)
    closeConsoleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeConsoleBtn.BorderSizePixel = 0
    closeConsoleBtn.Text = "X"
    closeConsoleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    closeConsoleBtn.TextSize = 11
    closeConsoleBtn.Font = Enum.Font.GothamBold
    closeConsoleBtn.Parent = consoleTitle
    GUI_REFS.Buttons.closeConsole = closeConsoleBtn
    
    local closeConsoleCorner = Instance.new("UICorner")
    closeConsoleCorner.CornerRadius = UDim.new(0, 4)
    closeConsoleCorner.Parent = closeConsoleBtn
    
    -- Scrolling Frame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "LogScroll"
    scroll.Size = UDim2.new(1, -16, 1, -42)
    scroll.Position = UDim2.new(0, 8, 0, 34)
    scroll.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = consoleFrame
    GUI_REFS.LogFrame = scroll
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 6)
    scrollCorner.Parent = scroll
    
    local logPadding = Instance.new("UIPadding")
    logPadding.PaddingTop = UDim.new(0, 4)
    logPadding.PaddingBottom = UDim.new(0, 4)
    logPadding.PaddingLeft = UDim.new(0, 4)
    logPadding.PaddingRight = UDim.new(0, 4)
    logPadding.Parent = scroll
    
    local logLayout = Instance.new("UIListLayout")
    logLayout.SortOrder = Enum.SortOrder.LayoutOrder
    logLayout.Padding = UDim.new(0, 2)
    logLayout.Parent = scroll
    GUI_REFS.LogLayout = logLayout
    
    -- Bubble
    local bubble = Instance.new("TextButton")
    bubble.Name = "FloatingBubble"
    bubble.Size = UDim2.new(0, 50, 0, 50)
    bubble.Position = UDim2.new(0, 20, 0.5, -25)
    bubble.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
    bubble.BorderSizePixel = 0
    bubble.Text = "H"
    bubble.TextColor3 = Color3.fromRGB(240, 240, 240)
    bubble.TextSize = 22
    bubble.Font = Enum.Font.GothamBold
    bubble.Visible = false
    bubble.Active = true
    bubble.ZIndex = 40
    bubble.Parent = GUI_REFS.ScreenGui
    GUI_REFS.Bubble = bubble
    
    local bubbleCorner = Instance.new("UICorner")
    bubbleCorner.CornerRadius = UDim.new(1, 0)
    bubbleCorner.Parent = bubble
end

--==============================================================================
-- SECTION 17 : DRAGGABLE FUNCTION
--==============================================================================
local function makeDraggable(frame, dragHandle)
    if not frame or not dragHandle then return end
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function onInputBegan(input)
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
    end
    
    local function onInputChanged(input)
        if dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end
    
    dragHandle.InputBegan:Connect(onInputBegan)
    UserInputService.InputChanged:Connect(onInputChanged)
end

--==============================================================================
-- SECTION 18 : REAL-TIME STATS UPDATE
--==============================================================================
local function startStatsUpdater()
    task.spawn(function()
        while true do
            task.wait(0.5)
            
            pcall(function()
                if GUI_REFS.Labels.total then
                    GUI_REFS.Labels.total.Text = "Total: " .. tostring(stats.collected)
                end
                if GUI_REFS.Labels.ginseng then
                    GUI_REFS.Labels.ginseng.Text = "Ginseng: " .. tostring(stats.ginseng)
                end
                if GUI_REFS.Labels.spirit then
                    GUI_REFS.Labels.spirit.Text = "Spirit Grass: " .. tostring(stats.spiritGrass)
                end
                if GUI_REFS.Labels.lastScan then
                    GUI_REFS.Labels.lastScan.Text = "Last Scan: " .. tostring(stats.lastScanCount) .. " plants"
                end
                if GUI_REFS.Labels.duration then
                    GUI_REFS.Labels.duration.Text = "Duration: " .. string.format("%.2f", stats.lastDuration) .. "s"
                end
                if GUI_REFS.Labels.status then
                    if STATE.isHarvesting then
                        GUI_REFS.Labels.status.Text = "Status: HARVESTING"
                        GUI_REFS.Labels.status.TextColor3 = Color3.fromRGB(255, 200, 0)
                    elseif STATE.autoLoopActive then
                        GUI_REFS.Labels.status.Text = "Status: AUTO LOOP"
                        GUI_REFS.Labels.status.TextColor3 = Color3.fromRGB(0, 200, 255)
                    else
                        GUI_REFS.Labels.status.Text = "Status: IDLE"
                        GUI_REFS.Labels.status.TextColor3 = Color3.fromRGB(0, 220, 130)
                    end
                end
            end)
        end
    end)
end

--==============================================================================
-- SECTION 19 : EVENT HANDLERS
--==============================================================================
local function bindEvents()
    -- Harvest All
    GUI_REFS.Buttons.harvestAll.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(function()
                doMassHarvest()
            end)
        end)
    end)
    
    -- Auto Loop
    GUI_REFS.Buttons.autoLoop.MouseButton1Click:Connect(function()
        if STATE.autoLoopActive then
            stopAutoLoop()
            GUI_REFS.Buttons.autoLoop.Text = "AUTO LOOP: OFF"
            GUI_REFS.Buttons.autoLoop.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        else
            startAutoLoop()
            GUI_REFS.Buttons.autoLoop.Text = "AUTO LOOP: ON"
            GUI_REFS.Buttons.autoLoop.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        end
    end)
    
    -- Scan
    GUI_REFS.Buttons.scan.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(function()
                local plants = findAllPlants()
                stats.lastScanCount = #plants
                log("Scan selesai: " .. tostring(#plants) .. " plants ditemukan", "info")
            end)
        end)
    end)
    
    -- Reset Stats
    GUI_REFS.Buttons.reset.MouseButton1Click:Connect(function()
        stats.collected = 0
        stats.ginseng = 0
        stats.spiritGrass = 0
        stats.lastScanCount = 0
        stats.lastDuration = 0
        log("Stats di-reset", "warn")
    end)
    
    -- Open Console
    GUI_REFS.Buttons.console.MouseButton1Click:Connect(function()
        if GUI_REFS.Console then
            GUI_REFS.Console.Visible = not GUI_REFS.Console.Visible
            STATE.consoleVisible = GUI_REFS.Console.Visible
        end
    end)
    
    -- Clear Console
    if GUI_REFS.Buttons.clearBtn then
        GUI_REFS.Buttons.clearBtn.MouseButton1Click:Connect(function()
            pcall(function()
                for _, child in ipairs(GUI_REFS.LogFrame:GetChildren()) do
                    if child:IsA("TextLabel") then
                        child:Destroy()
                    end
                end
                STATE.logs = {}
            end)
        end)
    end
    
    -- Close Console
    if GUI_REFS.Buttons.closeConsole then
        GUI_REFS.Buttons.closeConsole.MouseButton1Click:Connect(function()
            if GUI_REFS.Console then
                GUI_REFS.Console.Visible = false
                STATE.consoleVisible = false
            end
        end)
    end
    
    -- Minimize Main GUI (show bubble)
    GUI_REFS.Buttons.minBtn.MouseButton1Click:Connect(function()
        GUI_REFS.MainFrame.Visible = false
        if GUI_REFS.Bubble then
            GUI_REFS.Bubble.Visible = true
        end
    end)
    
    -- Close Main GUI (show bubble)
    GUI_REFS.Buttons.closeBtn.MouseButton1Click:Connect(function()
        GUI_REFS.MainFrame.Visible = false
        if GUI_REFS.Console then
            GUI_REFS.Console.Visible = false
        end
        if GUI_REFS.Bubble then
            GUI_REFS.Bubble.Visible = true
        end
    end)
    
    -- Bubble clicked -> Show GUI
    if GUI_REFS.Bubble then
        GUI_REFS.Bubble.MouseButton1Click:Connect(function()
            GUI_REFS.MainFrame.Visible = true
            GUI_REFS.Bubble.Visible = false
        end)
    end
end

--==============================================================================
-- SECTION 20 : ANTI-AFK + INITIAL SCAN + LOADED PRINT
--==============================================================================
local function setupAntiAFK()
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0))
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0))
            log("Anti-AFK triggered", "info")
        end)
    end)
end

local function reconnectCharacter()
    pcall(function()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            updateCharacterRefs()
            log("Character respawn - refs updated", "info")
        end)
    end)
end

--==============================================================================
-- INITIALIZATION
--==============================================================================
local function init()
    log("Loading TRUE MASS HARVEST v6.1...", "info")
    
    updateCharacterRefs()
    reconnectCharacter()
    
    createGUI()
    createConsolePopup()
    
    makeDraggable(GUI_REFS.MainFrame, GUI_REFS.MainFrame:FindFirstChild("TitleBar"))
    makeDraggable(GUI_REFS.Bubble, GUI_REFS.Bubble)
    if GUI_REFS.Console then
        makeDraggable(GUI_REFS.Console, GUI_REFS.Console:FindFirstChild("ConsoleTitle"))
    end
    
    bindEvents()
    startStatsUpdater()
    setupAntiAFK()
    
    task.spawn(function()
        task.wait(0.5)
        pcall(function()
            local plants = findAllPlants()
            stats.lastScanCount = #plants
            log("Initial scan: " .. tostring(#plants) .. " plants", "success")
        end)
    end)
    
    log("Script Created by ADIEL - Loaded successfully", "success")
    log("NO TELEPORT MODE - Distance Harvest aktif", "success")
end

init()
