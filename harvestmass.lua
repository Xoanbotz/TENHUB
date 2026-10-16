--[[
================================================================================
    TRUE MASS HARVEST v7.0 (FIXED HARVEST ENGINE)
    Script Created by ADIEL
    
    Changelog v7.0:
    - FIXED: ProximityPrompt sekarang coba InputHoldBegin/InputHoldEnd
    - FIXED: Remote scanner lebih agresif + DEBUG log nama remote
    - FIXED: Tambah firetouchinterest method
    - FIXED: Remote fire dengan multiple argument variations
    - FIXED: Cari remote di dalam PlayerGui, Character, Backpack
    - NEW: DEBUG MODE button buat lihat semua remote di game
    - NEW: Config STEALTH_CFRAME (opsional, default false)
================================================================================
]]

--==============================================================================
-- SECTION 1 : HEADER
--==============================================================================
-- Script Created by ADIEL - TRUE MASS HARVEST v7.0

--==============================================================================
-- SECTION 2 : SERVICES
--==============================================================================
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--==============================================================================
-- SECTION 3 : CONFIG
--==============================================================================
local CONFIG = {
    PLANT_NAMES        = {"Ginseng", "Spirit Grass", "SpiritGrass"},
    HARVESTABLE_TAGS   = {"Harvestable", "Plant", "Herb", "Collectable", "Resource"},
    REMOTE_KEYWORDS    = {
        "harvest","collect","plant","gather","pickup","grab","herb","pluck","reap",
        "interact","use","take","pick","click","trigger","action","tool","item","farm"
    },
    BATCH_SIZE         = 30,
    BATCH_DELAY        = 0.02,
    FIRE_DELAY         = 0.04,
    FORCE_DISTANCE     = 999999,
    MAX_DEPTH          = 10,
    AUTO_SCAN_INTERVAL = 3,
    DEBUG              = true,
    LOG_LIMIT          = 50,
    STEALTH_CFRAME     = false,
    STEALTH_DURATION   = 0.05,
}

--==============================================================================
-- SECTION 4 : STATE
--==============================================================================
local stats = {
    collected = 0, lastScanCount = 0, startTime = 0,
    ginseng = 0, spiritGrass = 0, lastDuration = 0,
}

local STATE = {
    autoLoopActive = false, autoLoopThread = nil,
    isHarvesting = false, guiVisible = true, consoleVisible = false,
    character = nil, humanoid = nil, rootPart = nil,
    logs = {}, foundRemotes = {},
}

local GUI_REFS = {
    ScreenGui = nil, MainFrame = nil, Bubble = nil, Console = nil,
    Labels = {}, Buttons = {}, LogFrame = nil, LogLayout = nil,
}

--==============================================================================
-- SECTION 5 : LOG
--==============================================================================
local function log(msg, logType)
    logType = logType or "info"
    local fullMsg = "[TMM v7] " .. tostring(msg)
    if logType == "error" then warn(fullMsg) else print(fullMsg) end
    
    if GUI_REFS.LogFrame then
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -6, 0, 18)
        entry.BackgroundTransparency = 1
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextSize = 11
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
            if old and old.Parent then old:Destroy() end
        end
    end
end

--==============================================================================
-- SECTION 6 : UTILITY
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
    if string.find(name, "ginseng") then return "Ginseng" end
    if string.find(name, "spirit") or string.find(name, "grass") then return "Spirit Grass" end
    return "Unknown"
end

local function isPlantName(objName)
    if not objName then return false end
    local lowerName = string.lower(objName)
    for _, pn in ipairs(CONFIG.PLANT_NAMES) do
        if string.find(lowerName, string.lower(pn), 1, true) then return true end
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
    return obj:FindFirstChildWhichIsA("BasePart", true)
end

--==============================================================================
-- SECTION 7 : DETECTION 1
--==============================================================================
local function findPlantsByDescendants()
    local found = {}
    local descendants = {}
    pcall(function() descendants = Workspace:GetDescendants() end)
    
    for _, obj in ipairs(descendants) do
        if obj and obj.Parent and isPlantName(obj.Name) then
            local root = getRootPart(obj)
            if root then
                table.insert(found, {obj = obj, root = root, type = getPlantType(obj)})
            end
        end
    end
    return found
end

--==============================================================================
-- SECTION 8 : DETECTION 2
--==============================================================================
local function findPlantsByTags()
    local found = {}
    for _, tag in ipairs(CONFIG.HARVESTABLE_TAGS) do
        local tagged = {}
        pcall(function() tagged = CollectionService:GetTagged(tag) end)
        for _, obj in ipairs(tagged) do
            if obj and obj.Parent then
                local root = getRootPart(obj)
                if root then
                    table.insert(found, {obj = obj, root = root, type = getPlantType(obj)})
                end
            end
        end
    end
    return found
end

--==============================================================================
-- SECTION 9 : MERGE
--==============================================================================
local function findAllPlants()
    local merged, seen = {}, {}
    for _, p in ipairs(findPlantsByDescendants()) do
        if p.obj and not seen[p.obj] then seen[p.obj] = true; table.insert(merged, p) end
    end
    for _, p in ipairs(findPlantsByTags()) do
        if p.obj and not seen[p.obj] then seen[p.obj] = true; table.insert(merged, p) end
    end
    return merged
end

--==============================================================================
-- SECTION 10 : REMOTE SCANNER (AGGRESSIVE)
--==============================================================================
local function scanAllRemotes()
    local remotes = {}
    local containers = {
        ReplicatedStorage,
        Workspace,
        LocalPlayer:FindFirstChild("PlayerGui"),
        LocalPlayer:FindFirstChild("Backpack"),
        LocalPlayer.Character,
    }
    
    for _, container in ipairs(containers) do
        if not container then continue end
        pcall(function()
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                    or obj:IsA("UnreliableRemoteEvent") then
                    table.insert(remotes, obj)
                end
            end
        end)
    end
    
    return remotes
end

local function scanServerStorageRemotes()
    local remotes = {}
    for _, container in ipairs({ServerStorage, ServerScriptService}) do
        pcall(function()
            for _, obj in ipairs(container:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    table.insert(remotes, obj)
                end
            end
        end)
    end
    return remotes
end

local function debugDumpRemotes()
    log("=== DEBUG: Scanning all remotes ===", "info")
    local remotes = scanAllRemotes()
    STATE.foundRemotes = remotes
    
    for i, r in ipairs(remotes) do
        if i <= 30 then
            local parentName = r.Parent and r.Parent.Name or "?"
            log(i .. ". " .. r.ClassName .. " -> " .. r.Name .. " (Parent: " .. parentName .. ")", "info")
        end
    end
    
    log("Total remotes found: " .. tostring(#remotes), "success")
    return remotes
end

--==============================================================================
-- SECTION 11 : REMOTE HARVEST (MULTI VARIATIONS)
--==============================================================================
local function fireRemoteVariations(remote, plant)
    if not remote or not plant then return false end
    local ok = false
    
    pcall(function()
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            remote:FireServer()
            remote:FireServer(plant.obj)
            remote:FireServer(plant.obj.Name)
            remote:FireServer(plant.root)
            remote:FireServer(plant.obj, plant.root)
            remote:FireServer(plant.root, plant.obj)
            remote:FireServer(plant.obj, LocalPlayer)
            remote:FireServer(LocalPlayer, plant.obj)
            remote:FireServer(plant.obj.Name, plant.root.Position)
            remote:FireServer(plant.root.Position)
            remote:FireServer("harvest", plant.obj)
            remote:FireServer("collect", plant.obj)
            ok = true
        elseif remote:IsA("RemoteFunction") then
            pcall(function() remote:InvokeServer() end)
            pcall(function() remote:InvokeServer(plant.obj) end)
            pcall(function() remote:InvokeServer(plant.obj, plant.root) end)
            ok = true
        end
    end)
    
    return ok
end

local function tryRemoteHarvest(plant)
    if not plant or not plant.obj then return false end
    local fired = false
    
    -- Priority 1: Remote with matching keywords in ReplicatedStorage
    local containerList = {ReplicatedStorage, Workspace, ServerStorage, ServerScriptService}
    
    for _, container in ipairs(containerList) do
        pcall(function()
            for _, obj in ipairs(container:GetDescendants()) do
                if fired then return end
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local lowerName = string.lower(obj.Name)
                    for _, kw in ipairs(CONFIG.REMOTE_KEYWORDS) do
                        if string.find(lowerName, kw, 1, true) then
                            fireRemoteVariations(obj, plant)
                            fired = true
                            break
                        end
                    end
                end
            end
        end)
    end
    
    -- Priority 2: Remotes inside plant object
    if not fired and plant.obj then
        pcall(function()
            for _, obj in ipairs(plant.obj:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    fireRemoteVariations(obj, plant)
                    fired = true
                end
            end
        end)
    end
    
    return fired
end

--==============================================================================
-- SECTION 12 : HARVEST PLANT (7 METHODS)
--==============================================================================
local function harvestPlant(plant)
    if not plant or not plant.obj or not plant.obj.Parent then return false end
    if not plant.root or not plant.root.Parent then return false end
    
    local success = false
    
    -- METHOD 1: Direct ProximityPrompt + fireproximityprompt
    local prompt = plant.obj:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        pcall(function()
            prompt = plant.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        end)
    end
    
    if prompt then
        pcall(function()
            prompt.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.Enabled = true
            prompt:InputHoldBegin()
        end)
        pcall(function()
            fireproximityprompt(prompt, 0, true)
        end)
        pcall(function()
            prompt:InputHoldEnd()
        end)
        success = true
    end
    
    -- METHOD 2: firetouchinterest (fake touch)
    if not success then
        pcall(function()
            if STATE.rootPart and plant.root then
                firetouchinterest(STATE.rootPart, plant.root, 0)
                task.wait()
                firetouchinterest(STATE.rootPart, plant.root, 1)
            end
        end)
        success = true
    end
    
    -- METHOD 3: ClickDetector
    if not success then
        local cd = plant.obj:FindFirstChildOfClass("ClickDetector")
        if not cd then
            pcall(function()
                cd = plant.obj:FindFirstChildWhichIsA("ClickDetector", true)
            end)
        end
        if cd then
            pcall(function()
                cd.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            end)
            pcall(function()
                fireclickdetector(cd, 0, true)
            end)
            success = true
        end
    end
    
    -- METHOD 4: STEALTH CFrame (opsional, singkat)
    if not success and CONFIG.STEALTH_CFRAME and STATE.rootPart and plant.root then
        pcall(function()
            local savedCF = STATE.rootPart.CFrame
            STATE.rootPart.CFrame = CFrame.new(plant.root.Position + Vector3.new(0, 3, 0))
            task.wait(CONFIG.STEALTH_DURATION)
            if prompt then
                pcall(function() fireproximityprompt(prompt, 0, true) end)
            end
            STATE.rootPart.CFrame = savedCF
        end)
        success = true
    end
    
    -- METHOD 5: RemoteEvent/Function
    if not success then
        success = tryRemoteHarvest(plant)
    end
    
    -- METHOD 6: Fire ALL remotes with broad keyword (last resort)
    if not success then
        pcall(function()
            local allRemotes = scanAllRemotes()
            for _, r in ipairs(allRemotes) do
                local lowerName = string.lower(r.Name)
                if string.find(lowerName, "interact", 1, true)
                    or string.find(lowerName, "action", 1, true)
                    or string.find(lowerName, "use", 1, true) then
                    fireRemoteVariations(r, plant)
                    success = true
                    break
                end
            end
        end)
    end
    
    -- METHOD 7: fireproximityprompt brute force (no args)
    if not success then
        pcall(function()
            fireproximityprompt(plant.obj)
        end)
        success = true
    end
    
    return success
end

--==============================================================================
-- SECTION 13 : BATCH
--==============================================================================
local function batchHarvest(plants)
    if not plants or #plants == 0 then return 0 end
    local totalHarvested = 0
    local totalBatches = math.ceil(#plants / CONFIG.BATCH_SIZE)
    
    for b = 1, totalBatches do
        local sIdx = (b - 1) * CONFIG.BATCH_SIZE + 1
        local eIdx = math.min(b * CONFIG.BATCH_SIZE, #plants)
        
        for i = sIdx, eIdx do
            local plant = plants[i]
            if plant and plant.obj and plant.obj.Parent then
                local ok = pcall(function() harvestPlant(plant) end)
                if ok then
                    totalHarvested = totalHarvested + 1
                    if plant.type == "Ginseng" then
                        stats.ginseng = stats.ginseng + 1
                    elseif plant.type == "Spirit Grass" then
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
-- SECTION 14 : MASS HARVEST
--==============================================================================
local function doMassHarvest()
    if STATE.isHarvesting then return end
    STATE.isHarvesting = true
    local startTime = tick()
    
    log("Scanning...", "info")
    local plants = findAllPlants()
    stats.lastScanCount = #plants
    log("Found " .. tostring(#plants) .. " plants", "info")
    
    if #plants == 0 then
        log("No plants found", "warn")
        STATE.isHarvesting = false
        return
    end
    
    local harvested = batchHarvest(plants)
    stats.collected = stats.collected + harvested
    stats.lastDuration = tick() - startTime
    
    log("Done: " .. tostring(harvested) .. "/" .. tostring(#plants) .. " in " .. string.format("%.2f", stats.lastDuration) .. "s", "success")
    STATE.isHarvesting = false
end

--==============================================================================
-- SECTION 15 : AUTO LOOP
--==============================================================================
local function startAutoLoop()
    if STATE.autoLoopThread then
        pcall(function() task.cancel(STATE.autoLoopThread) end)
    end
    STATE.autoLoopActive = true
    STATE.autoLoopThread = task.spawn(function()
        while STATE.autoLoopActive do
            pcall(function() doMassHarvest() end)
            local w = 0
            while w < CONFIG.AUTO_SCAN_INTERVAL and STATE.autoLoopActive do
                task.wait(0.1); w = w + 0.1
            end
        end
    end)
    log("Auto loop ON", "success")
end

local function stopAutoLoop()
    STATE.autoLoopActive = false
    if STATE.autoLoopThread then
        pcall(function() task.cancel(STATE.autoLoopThread) end)
        STATE.autoLoopThread = nil
    end
    log("Auto loop OFF", "warn")
end

--==============================================================================
-- SECTION 16 : GUI
--==============================================================================
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "TrueMassHarvest_ADIEL"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    GUI_REFS.ScreenGui = sg
    
    local mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 680, 0, 260)
    mf.Position = UDim2.new(0.5, -340, 0.5, -130)
    mf.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Parent = sg
    GUI_REFS.MainFrame = mf
    
    local mfc = Instance.new("UICorner"); mfc.CornerRadius = UDim.new(0, 10); mfc.Parent = mf
    local mfs = Instance.new("UIStroke"); mfs.Color = Color3.fromRGB(40, 40, 55); mfs.Parent = mf
    
    -- TITLE BAR
    local tb = Instance.new("Frame")
    tb.Name = "TitleBar"
    tb.Size = UDim2.new(1, 0, 0, 35)
    tb.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    tb.BorderSizePixel = 0
    tb.Active = true
    tb.Parent = mf
    
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 10); tbc.Parent = tb
    local tbm = Instance.new("Frame")
    tbm.Size = UDim2.new(1, 0, 0, 12)
    tbm.Position = UDim2.new(0, 0, 1, -12)
    tbm.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    tbm.BorderSizePixel = 0
    tbm.Parent = tb
    
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -90, 1, 0)
    tl.Position = UDim2.new(0, 12, 0, 0)
    tl.BackgroundTransparency = 1
    tl.Text = "TRUE MASS HARVEST v7.0 - Script Created by ADIEL"
    tl.TextColor3 = Color3.fromRGB(0, 220, 130)
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = tb
    
    local minB = Instance.new("TextButton")
    minB.Size = UDim2.new(0, 30, 0, 25)
    minB.Position = UDim2.new(1, -70, 0, 5)
    minB.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    minB.BorderSizePixel = 0
    minB.Text = "_"
    minB.TextColor3 = Color3.fromRGB(220, 220, 220)
    minB.TextSize = 16
    minB.Font = Enum.Font.GothamBold
    minB.Parent = tb
    GUI_REFS.Buttons.minBtn = minB
    local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 5); mbc.Parent = minB
    
    local clB = Instance.new("TextButton")
    clB.Size = UDim2.new(0, 30, 0, 25)
    clB.Position = UDim2.new(1, -36, 0, 5)
    clB.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    clB.BorderSizePixel = 0
    clB.Text = "X"
    clB.TextColor3 = Color3.fromRGB(240, 240, 240)
    clB.TextSize = 14
    clB.Font = Enum.Font.GothamBold
    clB.Parent = tb
    GUI_REFS.Buttons.closeBtn = clB
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 5); cbc.Parent = clB
    
    -- COL 1
    local c1 = Instance.new("Frame")
    c1.Size = UDim2.new(0, 200, 0, 210)
    c1.Position = UDim2.new(0, 12, 0, 42)
    c1.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c1.BorderSizePixel = 0
    c1.Parent = mf
    local c1c = Instance.new("UICorner"); c1c.CornerRadius = UDim.new(0, 8); c1c.Parent = c1
    
    local c1t = Instance.new("TextLabel")
    c1t.Size = UDim2.new(1, -16, 0, 22)
    c1t.Position = UDim2.new(0, 8, 0, 6)
    c1t.BackgroundTransparency = 1
    c1t.Text = "STATISTIK"
    c1t.TextColor3 = Color3.fromRGB(0, 200, 255)
    c1t.TextSize = 14
    c1t.Font = Enum.Font.GothamBold
    c1t.TextXAlignment = Enum.TextXAlignment.Left
    c1t.Parent = c1
    
    local function mkLbl(n, y, col)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -16, 0, 20)
        l.Position = UDim2.new(0, 8, 0, y)
        l.BackgroundTransparency = 1
        l.Text = n .. ": 0"
        l.TextColor3 = col
        l.TextSize = 12
        l.Font = Enum.Font.Code
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = c1
        return l
    end
    
    GUI_REFS.Labels.total    = mkLbl("Total", 34, Color3.fromRGB(0, 220, 130))
    GUI_REFS.Labels.total.TextSize = 14
    GUI_REFS.Labels.ginseng  = mkLbl("Ginseng", 58, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.spirit   = mkLbl("Spirit Grass", 80, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.lastScan = mkLbl("Last Scan", 102, Color3.fromRGB(180, 180, 200))
    GUI_REFS.Labels.duration = mkLbl("Duration", 124, Color3.fromRGB(180, 180, 200))
    GUI_REFS.Labels.status   = mkLbl("Status", 150, Color3.fromRGB(0, 220, 130))
    GUI_REFS.Labels.status.Text = "Status: IDLE"
    
    -- COL 2
    local c2 = Instance.new("Frame")
    c2.Size = UDim2.new(0, 220, 0, 210)
    c2.Position = UDim2.new(0, 224, 0, 42)
    c2.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c2.BorderSizePixel = 0
    c2.Parent = mf
    local c2c = Instance.new("UICorner"); c2c.CornerRadius = UDim.new(0, 8); c2c.Parent = c2
    
    local c2t = Instance.new("TextLabel")
    c2t.Size = UDim2.new(1, -16, 0, 22)
    c2t.Position = UDim2.new(0, 8, 0, 6)
    c2t.BackgroundTransparency = 1
    c2t.Text = "MASS HARVEST"
    c2t.TextColor3 = Color3.fromRGB(0, 200, 255)
    c2t.TextSize = 14
    c2t.Font = Enum.Font.GothamBold
    c2t.TextXAlignment = Enum.TextXAlignment.Left
    c2t.Parent = c2
    
    local function mkBtn(n, txt, y, h, col)
        local b = Instance.new("TextButton")
        b.Name = n
        b.Size = UDim2.new(1, -16, 0, h)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(240, 240, 240)
        b.TextSize = 12
        b.Font = Enum.Font.GothamBold
        b.Parent = c2
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
        return b
    end
    
    GUI_REFS.Buttons.harvestAll = mkBtn("HarvestAll", "HARVEST ALL SEKARANG", 34, 42, Color3.fromRGB(0, 160, 90))
    GUI_REFS.Buttons.autoLoop   = mkBtn("AutoLoop", "AUTO LOOP: OFF", 82, 28, Color3.fromRGB(0, 110, 180))
    GUI_REFS.Buttons.scan       = mkBtn("Scan", "SCAN PLANTS", 114, 28, Color3.fromRGB(60, 50, 90))
    GUI_REFS.Buttons.debug      = mkBtn("Debug", "DEBUG REMOTES", 146, 28, Color3.fromRGB(80, 60, 30))
    GUI_REFS.Buttons.reset      = mkBtn("Reset", "RESET STATS", 178, 26, Color3.fromRGB(70, 40, 40))
    
    -- COL 3
    local c3 = Instance.new("Frame")
    c3.Size = UDim2.new(0, 200, 0, 210)
    c3.Position = UDim2.new(0, 456, 0, 42)
    c3.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c3.BorderSizePixel = 0
    c3.Parent = mf
    local c3c = Instance.new("UICorner"); c3c.CornerRadius = UDim.new(0, 8); c3c.Parent = c3
    
    local c3t = Instance.new("TextLabel")
    c3t.Size = UDim2.new(1, -16, 0, 22)
    c3t.Position = UDim2.new(0, 8, 0, 6)
    c3t.BackgroundTransparency = 1
    c3t.Text = "INFORMASI"
    c3t.TextColor3 = Color3.fromRGB(0, 200, 255)
    c3t.TextSize = 14
    c3t.Font = Enum.Font.GothamBold
    c3t.TextXAlignment = Enum.TextXAlignment.Left
    c3t.Parent = c3
    
    local it = Instance.new("TextLabel")
    it.Size = UDim2.new(1, -16, 0, 170)
    it.Position = UDim2.new(0, 8, 0, 32)
    it.BackgroundTransparency = 1
    it.Text = "Plants:\n- Ginseng\n- Spirit Grass\n\nMethods:\n- ProximityPrompt\n- ClickDetector\n- TouchInterest\n- RemoteEvent\n- Debug Remotes\n\nMode: NO TELEPORT"
    it.TextColor3 = Color3.fromRGB(180, 180, 200)
    it.TextSize = 11
    it.Font = Enum.Font.Code
    it.TextXAlignment = Enum.TextXAlignment.Left
    it.TextYAlignment = Enum.TextYAlignment.Top
    it.Parent = c3
    
    local cr = Instance.new("TextLabel")
    cr.Size = UDim2.new(1, -16, 0, 20)
    cr.Position = UDim2.new(0, 8, 1, -26)
    cr.BackgroundTransparency = 1
    cr.Text = "Script Created by ADIEL"
    cr.TextColor3 = Color3.fromRGB(100, 100, 130)
    cr.TextSize = 11
    cr.Font = Enum.Font.Gotham
    cr.TextXAlignment = Enum.TextXAlignment.Left
    cr.Parent = c3
end

--==============================================================================
-- SECTION 17 : CONSOLE + BUBBLE
--==============================================================================
local function createConsolePopup()
    local cf = Instance.new("Frame")
    cf.Name = "ConsolePopup"
    cf.Size = UDim2.new(0, 340, 0, 260)
    cf.Position = UDim2.new(0.5, -170, 0.5, -130)
    cf.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    cf.BorderSizePixel = 0
    cf.Visible = false
    cf.Active = true
    cf.ZIndex = 50
    cf.Parent = GUI_REFS.ScreenGui
    GUI_REFS.Console = cf
    local cfc = Instance.new("UICorner"); cfc.CornerRadius = UDim.new(0, 10); cfc.Parent = cf
    local cfs = Instance.new("UIStroke"); cfs.Color = Color3.fromRGB(60, 100, 60); cfs.Parent = cf
    
    local ct = Instance.new("Frame")
    ct.Name = "ConsoleTitle"
    ct.Size = UDim2.new(1, 0, 0, 30)
    ct.BackgroundColor3 = Color3.fromRGB(22, 32, 22)
    ct.BorderSizePixel = 0
    ct.Active = true
    ct.Parent = cf
    local ctc = Instance.new("UICorner"); ctc.CornerRadius = UDim.new(0, 10); ctc.Parent = ct
    
    local ctt = Instance.new("TextLabel")
    ctt.Size = UDim2.new(1, -80, 1, 0)
    ctt.Position = UDim2.new(0, 10, 0, 0)
    ctt.BackgroundTransparency = 1
    ctt.Text = "CONSOLE LOG"
    ctt.TextColor3 = Color3.fromRGB(0, 220, 130)
    ctt.TextSize = 12
    ctt.Font = Enum.Font.GothamBold
    ctt.TextXAlignment = Enum.TextXAlignment.Left
    ctt.Parent = ct
    
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0, 45, 0, 22)
    cb.Position = UDim2.new(1, -76, 0, 4)
    cb.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    cb.BorderSizePixel = 0
    cb.Text = "CLEAR"
    cb.TextColor3 = Color3.fromRGB(220, 220, 220)
    cb.TextSize = 10
    cb.Font = Enum.Font.GothamBold
    cb.Parent = ct
    GUI_REFS.Buttons.clearBtn = cb
    local cbc2 = Instance.new("UICorner"); cbc2.CornerRadius = UDim.new(0, 4); cbc2.Parent = cb
    
    local ccb = Instance.new("TextButton")
    ccb.Size = UDim2.new(0, 22, 0, 22)
    ccb.Position = UDim2.new(1, -26, 0, 4)
    ccb.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    ccb.BorderSizePixel = 0
    ccb.Text = "X"
    ccb.TextColor3 = Color3.fromRGB(240, 240, 240)
    ccb.TextSize = 11
    ccb.Font = Enum.Font.GothamBold
    ccb.Parent = ct
    GUI_REFS.Buttons.closeConsole = ccb
    local ccc2 = Instance.new("UICorner"); ccc2.CornerRadius = UDim.new(0, 4); ccc2.Parent = ccb
    
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, -16, 1, -42)
    sc.Position = UDim2.new(0, 8, 0, 34)
    sc.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 4
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Parent = cf
    GUI_REFS.LogFrame = sc
    local scc = Instance.new("UICorner"); scc.CornerRadius = UDim.new(0, 6); scc.Parent = sc
    
    local lp = Instance.new("UIPadding")
    lp.PaddingTop = UDim.new(0, 4); lp.PaddingBottom = UDim.new(0, 4)
    lp.PaddingLeft = UDim.new(0, 4); lp.PaddingRight = UDim.new(0, 4)
    lp.Parent = sc
    
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 2)
    ll.Parent = sc
    GUI_REFS.LogLayout = ll
    
    -- Bubble
    local bub = Instance.new("TextButton")
    bub.Name = "FloatingBubble"
    bub.Size = UDim2.new(0, 50, 0, 50)
    bub.Position = UDim2.new(0, 20, 0.5, -25)
    bub.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
    bub.BorderSizePixel = 0
    bub.Text = "H"
    bub.TextColor3 = Color3.fromRGB(240, 240, 240)
    bub.TextSize = 22
    bub.Font = Enum.Font.GothamBold
    bub.Visible = false
    bub.Active = true
    bub.ZIndex = 40
    bub.Parent = GUI_REFS.ScreenGui
    GUI_REFS.Bubble = bub
    local buc = Instance.new("UICorner"); buc.CornerRadius = UDim.new(1, 0); buc.Parent = bub
end

--==============================================================================
-- SECTION 18 : DRAGGABLE
--==============================================================================
local function makeDraggable(frame, handle)
    if not frame or not handle then return end
    local dragging, dragStart, startPos = false, nil, nil
    
    handle.InputBegan:Connect(function(input)
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
        if dragging then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

--==============================================================================
-- SECTION 19 : STATS UPDATER
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
                    GUI_REFS.Labels.lastScan.Text = "Last Scan: " .. tostring(stats.lastScanCount)
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
-- SECTION 20 : EVENTS
--==============================================================================
local function bindEvents()
    GUI_REFS.Buttons.harvestAll.MouseButton1Click:Connect(function()
        task.spawn(function() pcall(doMassHarvest) end)
    end)
    
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
    
    GUI_REFS.Buttons.scan.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(function()
                local plants = findAllPlants()
                stats.lastScanCount = #plants
                log("Scan: " .. tostring(#plants) .. " plants", "info")
            end)
        end)
    end)
    
    GUI_REFS.Buttons.debug.MouseButton1Click:Connect(function()
        task.spawn(function()
            pcall(debugDumpRemotes)
            if GUI_REFS.Console then
                GUI_REFS.Console.Visible = true
            end
        end)
    end)
    
    GUI_REFS.Buttons.reset.MouseButton1Click:Connect(function()
        stats.collected = 0; stats.ginseng = 0; stats.spiritGrass = 0
        stats.lastScanCount = 0; stats.lastDuration = 0
        log("Stats reset", "warn")
    end)
    
    if GUI_REFS.Buttons.clearBtn then
        GUI_REFS.Buttons.clearBtn.MouseButton1Click:Connect(function()
            pcall(function()
                for _, c in ipairs(GUI_REFS.LogFrame:GetChildren()) do
                    if c:IsA("TextLabel") then c:Destroy() end
                end
                STATE.logs = {}
            end)
        end)
    end
    
    if GUI_REFS.Buttons.closeConsole then
        GUI_REFS.Buttons.closeConsole.MouseButton1Click:Connect(function()
            if GUI_REFS.Console then GUI_REFS.Console.Visible = false end
        end)
    end
    
    GUI_REFS.Buttons.minBtn.MouseButton1Click:Connect(function()
        GUI_REFS.MainFrame.Visible = false
        if GUI_REFS.Bubble then GUI_REFS.Bubble.Visible = true end
    end)
    
    GUI_REFS.Buttons.closeBtn.MouseButton1Click:Connect(function()
        GUI_REFS.MainFrame.Visible = false
        if GUI_REFS.Console then GUI_REFS.Console.Visible = false end
        if GUI_REFS.Bubble then GUI_REFS.Bubble.Visible = true end
    end)
    
    if GUI_REFS.Bubble then
        GUI_REFS.Bubble.MouseButton1Click:Connect(function()
            GUI_REFS.MainFrame.Visible = true
            GUI_REFS.Bubble.Visible = false
        end)
    end
end

--==============================================================================
-- SECTION 21 : ANTI-AFK + INIT
--==============================================================================
local function setupAntiAFK()
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0))
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0))
        end)
    end)
end

local function reconnectCharacter()
    pcall(function()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            updateCharacterRefs()
        end)
    end)
end

local function init()
    log("Loading TMM v7.0...", "info")
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
    
    log("Script Created by ADIEL - Loaded", "success")
    log("TIP: Kalo gagal, klik DEBUG REMOTES buat lihat remote game", "warn")
end

init()
