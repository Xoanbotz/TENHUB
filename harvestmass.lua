--[[
================================================================================
    TRUE MASS HARVEST v8.2 (INSTANT + DEBUG + COPY LOG)
    Script Created by ADIEL
    
    Changelog v8.2:
    - Tambah tombol COPY LOG di title bar
    - Semua log ke-buffer, tinggal klik COPY LOG -> paste
    - Auto reset buffer tiap klik DEBUG SCAN
================================================================================
]]

--==============================================================================
-- SERVICES
--==============================================================================
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")
local UserInputService    = game:GetService("UserInputService")
local VirtualUser         = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

--==============================================================================
-- CONFIG
--==============================================================================
local CONFIG = {
    PLANT_NAMES     = {"Ginseng", "Spirit Grass", "SpiritGrass"},
    HARVESTABLE_TAGS = {"Harvestable", "Plant", "Herb", "Collectable", "Resource"},
    REMOTE_KEYWORDS = {"harvest","collect","plant","gather","pickup","grab","herb","pluck","reap","interact","use","take","pick","trigger"},
    FORCE_DISTANCE  = 999999,
}

--==============================================================================
-- STATE
--==============================================================================
local stats = {collected = 0, ginseng = 0, spiritGrass = 0, lastScanCount = 0}
local STATE = {isHarvesting = false, autoLoopActive = false, autoLoopThread = nil, character = nil, humanoid = nil, rootPart = nil}
local GUI_REFS = {ScreenGui = nil, MainFrame = nil, Labels = {}, Buttons = {}, LogFrame = nil}
local logBuffer = {}

--==============================================================================
-- LOG (WITH BUFFER)
--==============================================================================
local function log(msg, logType)
    logType = logType or "info"
    table.insert(logBuffer, "[" .. logType:upper() .. "] " .. tostring(msg))
    local fullMsg = "[TMM v8.2] " .. tostring(msg)
    if logType == "error" then warn(fullMsg) else print(fullMsg) end
    if GUI_REFS.LogFrame then
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -6, 0, 16)
        entry.BackgroundTransparency = 1
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextSize = 10
        entry.Font = Enum.Font.Code
        entry.Text = "[" .. logType:upper() .. "] " .. tostring(msg)
        if logType == "success" then entry.TextColor3 = Color3.fromRGB(0, 220, 130)
        elseif logType == "error" then entry.TextColor3 = Color3.fromRGB(240, 80, 80)
        elseif logType == "warn" then entry.TextColor3 = Color3.fromRGB(240, 200, 80)
        elseif logType == "debug" then entry.TextColor3 = Color3.fromRGB(255, 150, 255)
        else entry.TextColor3 = Color3.fromRGB(120, 180, 240) end
        entry.Parent = GUI_REFS.LogFrame
    end
end

--==============================================================================
-- UTILITY
--==============================================================================
local function updateCharacterRefs()
    local char = LocalPlayer.Character
    if char then
        STATE.character = char
        STATE.humanoid  = char:FindFirstChildOfClass("Humanoid")
        STATE.rootPart  = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    end
end

local function isPlantName(n)
    if not n then return false end
    local ln = string.lower(n)
    for _, pn in ipairs(CONFIG.PLANT_NAMES) do
        if string.find(ln, string.lower(pn), 1, true) then return true end
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

local function getPlantType(obj)
    local n = obj and string.lower(obj.Name) or ""
    if string.find(n, "ginseng") then return "Ginseng" end
    if string.find(n, "spirit") or string.find(n, "grass") then return "Spirit Grass" end
    return "Unknown"
end

--==============================================================================
-- DETECTION
--==============================================================================
local function findAllPlants()
    local merged, seen = {}, {}
    
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj and obj.Parent and isPlantName(obj.Name) then
                local root = getRootPart(obj)
                if root and not seen[obj] then
                    seen[obj] = true
                    table.insert(merged, {obj = obj, root = root, type = getPlantType(obj)})
                end
            end
        end
    end)
    
    for _, tag in ipairs(CONFIG.HARVESTABLE_TAGS) do
        pcall(function()
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                if obj and obj.Parent and not seen[obj] then
                    local root = getRootPart(obj)
                    if root then
                        seen[obj] = true
                        table.insert(merged, {obj = obj, root = root, type = getPlantType(obj)})
                    end
                end
            end
        end)
    end
    
    return merged
end

--==============================================================================
-- DEBUG SCAN
--==============================================================================
local function debugScan()
    log("========== DEBUG SCAN START ==========", "debug")
    
    -- 1. SCAN REMOTES
    log("-- REMOTES --", "debug")
    local allRemotes = {}
    local containers = {
        {c = ReplicatedStorage, n = "ReplicatedStorage"},
        {c = ServerStorage, n = "ServerStorage"},
        {c = ServerScriptService, n = "ServerScriptService"},
        {c = Workspace, n = "Workspace"},
    }
    
    for _, entry in ipairs(containers) do
        if entry.c then
            pcall(function()
                for _, o in ipairs(entry.c:GetDescendants()) do
                    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") then
                        local parentName = o.Parent and o.Parent.Name or "?"
                        log(o.ClassName .. " | " .. o.Name .. " | " .. entry.n .. "/" .. parentName, "debug")
                        table.insert(allRemotes, o)
                    end
                end
            end)
        end
    end
    log("Total remotes: " .. tostring(#allRemotes), "success")
    
    -- 2. SCAN PLAYER GUI
    log("-- PLAYER GUI REMOTES --", "debug")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        pcall(function()
            for _, o in ipairs(pg:GetDescendants()) do
                if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                    log("GUI: " .. o.ClassName .. " | " .. o.Name, "debug")
                end
            end
        end)
    end
    
    -- 3. SCAN PLANTS
    log("-- PLANTS --", "debug")
    local plantKeywords = {"ginseng", "spirit", "grass", "plant", "herb"}
    local plantCount = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local ln = string.lower(obj.Name)
            local match = false
            for _, kw in ipairs(plantKeywords) do
                if string.find(ln, kw, 1, true) then match = true; break end
            end
            if match and plantCount < 8 then
                log("PLANT: " .. obj.ClassName .. " | " .. obj.Name, "debug")
                for _, ch in ipairs(obj:GetDescendants()) do
                    if ch:IsA("ProximityPrompt") then
                        log("   Prompt: " .. ch.Name .. " Hold:" .. tostring(ch.HoldDuration) .. " Max:" .. tostring(ch.MaxActivationDistance), "debug")
                    elseif ch:IsA("ClickDetector") then
                        log("   ClickDet: " .. ch.Name, "debug")
                    elseif ch:IsA("RemoteEvent") or ch:IsA("RemoteFunction") then
                        log("   " .. ch.ClassName .. ": " .. ch.Name, "debug")
                    elseif ch:IsA("BasePart") then
                        log("   Part: " .. ch.Name, "debug")
                    end
                end
                plantCount = plantCount + 1
            end
        end
    end)
    
    -- 4. SCAN TAGS
    log("-- TAGS --", "debug")
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local tags = CollectionService:GetTags(obj)
            if #tags > 0 then
                log("TAG " .. obj.Name .. ": " .. table.concat(tags, ","), "debug")
            end
        end
    end)
    
    -- 5. SCAN TOOLS
    log("-- BACKPACK --", "debug")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            log("TOOL: " .. t.ClassName .. " | " .. t.Name, "debug")
        end
    end
    
    -- 6. SCAN CHARACTER
    log("-- EQUIPPED --", "debug")
    local ch = LocalPlayer.Character
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then
                log("EQUIPPED: " .. t.Name, "debug")
            end
        end
    end
    
    log("========== DEBUG SCAN END ==========", "success")
end

--==============================================================================
-- CACHE REMOTES
--==============================================================================
local cachedRemotes = nil

local function getRemotes()
    if cachedRemotes then return cachedRemotes end
    local remotes = {}
    local containers = {ReplicatedStorage, Workspace, ServerStorage, ServerScriptService}
    
    for _, c in ipairs(containers) do
        if c then
            pcall(function()
                for _, o in ipairs(c:GetDescendants()) do
                    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("UnreliableRemoteEvent") then
                        local ln = string.lower(o.Name)
                        for _, kw in ipairs(CONFIG.REMOTE_KEYWORDS) do
                            if string.find(ln, kw, 1, true) then
                                table.insert(remotes, o)
                                break
                            end
                        end
                    end
                end
            end)
        end
    end
    
    cachedRemotes = remotes
    log("Cached " .. tostring(#remotes) .. " harvest remotes", "info")
    return remotes
end

--==============================================================================
-- FIRE REMOTE
--==============================================================================
local function fireRemote(remote, plant)
    if not remote or not plant then return end
    pcall(function()
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            remote:FireServer(plant.obj)
            remote:FireServer(plant.obj, plant.root)
            remote:FireServer(plant.root)
            remote:FireServer(plant.obj.Name)
            remote:FireServer()
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(plant.obj)
            remote:InvokeServer(plant.obj, plant.root)
        end
    end)
end

--==============================================================================
-- HARVEST 1 PLANT
--==============================================================================
local function harvestPlant(plant)
    if not plant or not plant.obj or not plant.obj.Parent then return end
    if not plant.root or not plant.root.Parent then return end
    
    pcall(function()
        local prompt = plant.obj:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then prompt = plant.obj:FindFirstChildWhichIsA("ProximityPrompt", true) end
        if prompt then
            prompt.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.Enabled = true
            prompt:InputHoldBegin()
            pcall(function() fireproximityprompt(prompt, 0, true) end)
            prompt:InputHoldEnd()
        end
    end)
    
    pcall(function()
        local cd = plant.obj:FindFirstChildOfClass("ClickDetector")
        if not cd then cd = plant.obj:FindFirstChildWhichIsA("ClickDetector", true) end
        if cd then
            cd.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            pcall(function() fireclickdetector(cd, 0, true) end)
        end
    end)
    
    local remotes = getRemotes()
    for _, r in ipairs(remotes) do
        fireRemote(r, plant)
    end
    
    pcall(function()
        for _, o in ipairs(plant.obj:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
                fireRemote(o, plant)
            end
        end
    end)
end

--==============================================================================
-- INSTANT HARVEST
--==============================================================================
local function harvestAllInstant()
    if STATE.isHarvesting then return end
    STATE.isHarvesting = true
    
    local t0 = tick()
    log("Scanning...", "info")
    
    local plants = findAllPlants()
    stats.lastScanCount = #plants
    log("Found " .. tostring(#plants) .. " plants", "info")
    
    if #plants == 0 then
        STATE.isHarvesting = false
        return
    end
    
    getRemotes()
    
    for _, plant in ipairs(plants) do
        task.spawn(function()
            pcall(harvestPlant, plant)
        end)
    end
    
    for _, plant in ipairs(plants) do
        if plant.type == "Ginseng" then
            stats.ginseng = stats.ginseng + 1
        elseif plant.type == "Spirit Grass" then
            stats.spiritGrass = stats.spiritGrass + 1
        end
        stats.collected = stats.collected + 1
    end
    
    local dur = tick() - t0
    log("INSTANT: " .. tostring(#plants) .. " plants in " .. string.format("%.3f", dur) .. "s", "success")
    STATE.isHarvesting = false
end

--==============================================================================
-- AUTO LOOP
--==============================================================================
local function startAutoLoop()
    if STATE.autoLoopThread then pcall(task.cancel, STATE.autoLoopThread) end
    STATE.autoLoopActive = true
    STATE.autoLoopThread = task.spawn(function()
        while STATE.autoLoopActive do
            pcall(harvestAllInstant)
            task.wait(3)
        end
    end)
end

local function stopAutoLoop()
    STATE.autoLoopActive = false
    if STATE.autoLoopThread then
        pcall(task.cancel, STATE.autoLoopThread)
        STATE.autoLoopThread = nil
    end
end

--==============================================================================
-- GUI
--==============================================================================
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "TrueMassHarvest_ADIEL"
    sg.ResetOnSpawn = false
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
    tl.Size = UDim2.new(1, -230, 1, 0)
    tl.Position = UDim2.new(0, 12, 0, 0)
    tl.BackgroundTransparency = 1
    tl.Text = "TRUE MASS HARVEST v8.2 - Script Created by ADIEL"
    tl.TextColor3 = Color3.fromRGB(0, 220, 130)
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = tb
    
    -- COPY LOG BUTTON
    local copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyLog"
    copyBtn.Size = UDim2.new(0, 100, 0, 25)
    copyBtn.Position = UDim2.new(1, -170, 0, 5)
    copyBtn.BackgroundColor3 = Color3.fromRGB(30, 100, 180)
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = "COPY LOG"
    copyBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    copyBtn.TextSize = 11
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.Parent = tb
    local copyCorner = Instance.new("UICorner"); copyCorner.CornerRadius = UDim.new(0, 5); copyCorner.Parent = copyBtn
    GUI_REFS.Buttons.copyLog = copyBtn
    
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
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 5); cbc.Parent = clB
    GUI_REFS.Buttons.minBtn = minB
    GUI_REFS.Buttons.closeBtn = clB
    
    -- COL 1 STATISTIK
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
    
    local function mkLbl(n, y, col, size)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -16, 0, 22)
        l.Position = UDim2.new(0, 8, 0, y)
        l.BackgroundTransparency = 1
        l.Text = n .. ": 0"
        l.TextColor3 = col
        l.TextSize = size or 12
        l.Font = Enum.Font.Code
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = c1
        return l
    end
    
    GUI_REFS.Labels.total    = mkLbl("Total", 34, Color3.fromRGB(0, 220, 130), 15)
    GUI_REFS.Labels.ginseng  = mkLbl("Ginseng", 60, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.spirit   = mkLbl("Spirit Grass", 84, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.lastScan = mkLbl("Last Scan", 110, Color3.fromRGB(180, 180, 200))
    GUI_REFS.Labels.speed    = mkLbl("Speed", 134, Color3.fromRGB(255, 200, 100))
    GUI_REFS.Labels.status   = mkLbl("Status", 162, Color3.fromRGB(0, 220, 130), 13)
    GUI_REFS.Labels.status.Text = "Status: IDLE"
    
    -- COL 2 ACTIONS
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
        b.TextSize = 13
        b.Font = Enum.Font.GothamBold
        b.Parent = c2
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
        return b
    end
    
    GUI_REFS.Buttons.harvestAll = mkBtn("HarvestAll", "INSTANT HARVEST ALL", 34, 48, Color3.fromRGB(0, 180, 90))
    GUI_REFS.Buttons.autoLoop   = mkBtn("AutoLoop", "AUTO LOOP: OFF", 88, 28, Color3.fromRGB(0, 110, 180))
    GUI_REFS.Buttons.debug      = mkBtn("Debug", "DEBUG SCAN", 122, 28, Color3.fromRGB(120, 60, 160))
    GUI_REFS.Buttons.reset      = mkBtn("Reset", "RESET STATS", 156, 26, Color3.fromRGB(70, 40, 40))
    GUI_REFS.Buttons.console    = mkBtn("Console", "SHOW/HIDE LOG", 188, 22, Color3.fromRGB(35, 60, 35))
    
    -- COL 3 INFO
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
    it.Text = "MODE: INSTANT\n\nPlants:\n- Ginseng\n- Spirit Grass\n\nCara kirim log:\n1. Klik DEBUG SCAN\n2. Klik COPY LOG\n3. Paste di chat ADIEL"
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
    
    -- LOG PANEL
    local logFrame = Instance.new("Frame")
    logFrame.Name = "LogPanel"
    logFrame.Size = UDim2.new(1, -24, 0, 50)
    logFrame.Position = UDim2.new(0, 12, 1, -58)
    logFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    logFrame.BorderSizePixel = 0
    logFrame.ClipsDescendants = true
    logFrame.Parent = mf
    local lfc = Instance.new("UICorner"); lfc.CornerRadius = UDim.new(0, 6); lfc.Parent = logFrame
    
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, -8, 1, -8)
    sc.Position = UDim2.new(0, 4, 0, 4)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 3
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Parent = logFrame
    GUI_REFS.LogFrame = sc
    
    local ll = Instance.new("UIListLayout")
    ll.SortOrder = Enum.SortOrder.LayoutOrder
    ll.Padding = UDim.new(0, 1)
    ll.Parent = sc
end

--==============================================================================
-- DRAGGABLE
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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

--==============================================================================
-- STATS UPDATER
--==============================================================================
local function startStatsUpdater()
    task.spawn(function()
        while true do
            task.wait(0.3)
            pcall(function()
                if GUI_REFS.Labels.total then GUI_REFS.Labels.total.Text = "Total: " .. tostring(stats.collected) end
                if GUI_REFS.Labels.ginseng then GUI_REFS.Labels.ginseng.Text = "Ginseng: " .. tostring(stats.ginseng) end
                if GUI_REFS.Labels.spirit then GUI_REFS.Labels.spirit.Text = "Spirit Grass: " .. tostring(stats.spiritGrass) end
                if GUI_REFS.Labels.lastScan then GUI_REFS.Labels.lastScan.Text = "Last Scan: " .. tostring(stats.lastScanCount) end
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
-- EVENTS
--==============================================================================
local function bindEvents()
    GUI_REFS.Buttons.harvestAll.MouseButton1Click:Connect(function()
        task.spawn(function() pcall(harvestAllInstant) end)
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
    
    GUI_REFS.Buttons.debug.MouseButton1Click:Connect(function()
        logBuffer = {}
        task.spawn(function() pcall(debugScan) end)
    end)
    
    GUI_REFS.Buttons.reset.MouseButton1Click:Connect(function()
        stats.collected = 0; stats.ginseng = 0; stats.spiritGrass = 0; stats.lastScanCount = 0
        log("Stats reset", "warn")
    end)
    
    GUI_REFS.Buttons.console.MouseButton1Click:Connect(function()
        if GUI_REFS.LogFrame and GUI_REFS.LogFrame.Parent then
            GUI_REFS.LogFrame.Parent.Visible = not GUI_REFS.LogFrame.Parent.Visible
        end
    end)
    
    -- COPY LOG BUTTON
    if GUI_REFS.Buttons.copyLog then
        GUI_REFS.Buttons.copyLog.MouseButton1Click:Connect(function()
            pcall(function()
                local fullText = table.concat(logBuffer, "\n")
                if #fullText == 0 then
                    log("Log kosong, klik DEBUG SCAN dulu", "warn")
                    return
                end
                
                local copied = false
                if setclipboard then
                    setclipboard(fullText)
                    copied = true
                elseif toclipboard then
                    toclipboard(fullText)
                    copied = true
                elseif syn and syn.write_clipboard then
                    syn.write_clipboard(fullText)
                    copied = true
                end
                
                if copied then
                    log("Log ter-copy! (" .. tostring(#logBuffer) .. " baris). Paste di chat ADIEL.", "success")
                else
                    log("Clipboard gak support. Screenshot log panel aja.", "error")
                end
            end)
        end)
    end
    
    GUI_REFS.Buttons.minBtn.MouseButton1Click:Connect(function()
        GUI_REFS.MainFrame.Visible = false
    end)
    
    GUI_REFS.Buttons.closeBtn.MouseButton1Click:Connect(function()
        GUI_REFS.ScreenGui:Destroy()
    end)
end

--==============================================================================
-- ANTI-AFK
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

--==============================================================================
-- INIT
--==============================================================================
local function init()
    updateCharacterRefs()
    reconnectCharacter()
    createGUI()
    makeDraggable(GUI_REFS.MainFrame, GUI_REFS.MainFrame:FindFirstChild("TitleBar"))
    bindEvents()
    startStatsUpdater()
    setupAntiAFK()
    
    task.spawn(function()
        task.wait(0.3)
        pcall(function()
            getRemotes()
            local plants = findAllPlants()
            stats.lastScanCount = #plants
            log("Ready. " .. tostring(#plants) .. " plants detected", "success")
        end)
    end)
    
    log("Script Created by ADIEL - v8.2 INSTANT + DEBUG + COPY LOG", "success")
end

init()
