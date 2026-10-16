--[[
================================================================================
    XIANXIA GOD MODE v1.2 (DEBUG BUILD)
    Script Created by ADIEL
    
    Versi ini ada LOG tiap step, biar keliatan error di mana.
    Kalo ada error, muncul di console/output executor lo.
    Kirim ke gw error-nya.
================================================================================
]]

print("[XGM] === STARTING SCRIPT ===")

local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local CollectionService   = game:GetService("CollectionService")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local VirtualUser         = game:GetService("VirtualUser")
local CoreGui             = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

print("[XGM] LocalPlayer:", LocalPlayer and LocalPlayer.Name or "NIL")

--==============================================================================
-- CONFIG
--==============================================================================
local CONFIG = {
    HERB_TAGS          = {"Herbs"},
    ENEMY_TAGS         = {"Enemy"},
    FORCE_DISTANCE     = 999999,
    ATTACK_RANGE       = 30,
    AUTO_FARM_INTERVAL = 0.5,
    SPEED_VALUE        = 60,
    JUMP_VALUE         = 120,
}

--==============================================================================
-- STATE
==============================================================================
local STATE = {
    autoHarvest = false,
    killAura = false,
    autoFarm = false,
    espHerbs = false,
    espEnemies = false,
    speedBoost = false,
    jumpBoost = false,
    character = nil,
    humanoid = nil,
    rootPart = nil,
    connections = {},
    espObjects = {},
}

local stats = {
    harvested = 0,
    killed = 0,
    lastHerbCount = 0,
    lastEnemyCount = 0,
}

local GUI_REFS = {
    ScreenGui = nil,
    MainFrame = nil,
    Bubble = nil,
    Labels = {},
    Buttons = {},
}

--==============================================================================
-- STEP RUNNER (LOG SETIAP STEP)
--==============================================================================
local function step(name, fn)
    print("[XGM] Step: " .. name)
    local ok, err = pcall(fn)
    if not ok then
        warn("[XGM] !!! ERROR in " .. name .. ": " .. tostring(err))
    end
    return ok
end

--==============================================================================
-- LOG
--==============================================================================
local function log(msg, logType)
    logType = logType or "info"
    local fullMsg = "[XGM] " .. tostring(msg)
    if logType == "error" then warn(fullMsg) else print(fullMsg) end
end

--==============================================================================
-- CHARACTER REFS
--==============================================================================
local function updateCharacterRefs()
    local char = LocalPlayer.Character
    if char then
        STATE.character = char
        STATE.humanoid  = char:FindFirstChildOfClass("Humanoid")
        STATE.rootPart  = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    end
end

--==============================================================================
-- HERB SYSTEM
--==============================================================================
local function getAllHerbs()
    local herbs = {}
    for _, tag in ipairs(CONFIG.HERB_TAGS) do
        pcall(function()
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                if obj and obj.Parent then
                    table.insert(herbs, obj)
                end
            end
        end)
    end
    return herbs
end

local function getHerbPosition(herb)
    if not herb then return nil end
    if herb:IsA("BasePart") then return herb.Position end
    if herb.PrimaryPart then return herb.PrimaryPart.Position end
    local part = herb:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position end
    return nil
end

local function harvestOneHerb(herb)
    if not herb or not herb.Parent then return false end
    local success = false
    
    pcall(function()
        local prompt = herb:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            prompt = herb:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
        if prompt then
            prompt.MaxActivationDistance = CONFIG.FORCE_DISTANCE
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.Enabled = true
            pcall(function() fireproximityprompt(prompt, 0, true) end)
            success = true
        end
    end)
    
    if not success then
        pcall(function()
            local cd = herb:FindFirstChildOfClass("ClickDetector")
            if not cd then
                cd = herb:FindFirstChildWhichIsA("ClickDetector", true)
            end
            if cd then
                cd.MaxActivationDistance = CONFIG.FORCE_DISTANCE
                pcall(function() fireclickdetector(cd, 0, true) end)
                success = true
            end
        end)
    end
    
    if not success and STATE.rootPart then
        pcall(function()
            local part = herb:FindFirstChildWhichIsA("BasePart", true)
            if part and firetouchinterest then
                firetouchinterest(STATE.rootPart, part, 0)
                task.wait(0.05)
                firetouchinterest(STATE.rootPart, part, 1)
                success = true
            end
        end)
    end
    
    return success
end

local function harvestAllHerbs()
    local herbs = getAllHerbs()
    stats.lastHerbCount = #herbs
    
    if #herbs == 0 then
        log("Tidak ada herbs", "warn")
        return 0
    end
    
    log("Harvest " .. tostring(#herbs) .. " herbs...", "info")
    
    local count = 0
    for _, herb in ipairs(herbs) do
        task.spawn(function()
            pcall(function()
                if harvestOneHerb(herb) then
                    count = count + 1
                    stats.harvested = stats.harvested + 1
                end
            end)
        end)
    end
    
    task.wait(0.1)
    log("Harvest selesai: " .. tostring(count), "success")
    return count
end

--==============================================================================
-- ENEMY SYSTEM
--==============================================================================
local function getAllEnemies()
    local enemies = {}
    for _, tag in ipairs(CONFIG.ENEMY_TAGS) do
        pcall(function()
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                if obj and obj.Parent then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        table.insert(enemies, {obj = obj, humanoid = hum})
                    end
                end
            end
        end)
    end
    return enemies
end

local function getEnemyPosition(enemy)
    if not enemy then return nil end
    if enemy:IsA("BasePart") then return enemy.Position end
    if enemy.PrimaryPart then return enemy.PrimaryPart.Position end
    local root = enemy:FindFirstChild("HumanoidRootPart")
    if root then return root.Position end
    local part = enemy:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.Position end
    return nil
end

local function getDistanceTo(pos)
    if not pos or not STATE.rootPart then return math.huge end
    return (STATE.rootPart.Position - pos).Magnitude
end

local function getEquippedTool()
    if not STATE.character then return nil end
    for _, child in ipairs(STATE.character:GetChildren()) do
        if child:IsA("Tool") then return child end
    end
    return nil
end

local function equipFirstTool()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function()
                tool.Parent = STATE.character
            end)
            return tool
        end
    end
    return nil
end

local function attackEnemy(enemyObj)
    if not enemyObj or not enemyObj.Parent then return false end
    local tool = getEquippedTool()
    if not tool then
        tool = equipFirstTool()
        task.wait(0.05)
    end
    if not tool then return false end
    
    pcall(function() tool:Activate() end)
    pcall(function()
        for _, obj in ipairs(tool:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                obj:FireServer()
            end
        end
    end)
    return true
end

local function killAuraTick()
    if not STATE.killAura then return end
    if not STATE.rootPart then return end
    local enemies = getAllEnemies()
    stats.lastEnemyCount = #enemies
    for _, enemy in ipairs(enemies) do
        local pos = getEnemyPosition(enemy.obj)
        if pos and getDistanceTo(pos) <= CONFIG.ATTACK_RANGE then
            attackEnemy(enemy.obj)
            stats.killed = stats.killed + 1
        end
    end
end

local function startKillAura()
    if STATE.connections.killAura then
        pcall(function() STATE.connections.killAura:Disconnect() end)
    end
    STATE.connections.killAura = RunService.Heartbeat:Connect(function()
        pcall(killAuraTick)
    end)
    log("Kill Aura: ON", "success")
end

local function stopKillAura()
    if STATE.connections.killAura then
        pcall(function() STATE.connections.killAura:Disconnect() end)
        STATE.connections.killAura = nil
    end
    log("Kill Aura: OFF", "warn")
end

--==============================================================================
-- AUTO FARM
--==============================================================================
local function startAutoFarm()
    if STATE.connections.autoFarm then
        pcall(function() task.cancel(STATE.connections.autoFarm) end)
    end
    STATE.connections.autoFarm = task.spawn(function()
        while STATE.autoFarm do
            pcall(function() harvestAllHerbs() end)
            task.wait(CONFIG.AUTO_FARM_INTERVAL)
        end
    end)
    log("Auto Farm: ON", "success")
end

local function stopAutoFarm()
    STATE.autoFarm = false
    if STATE.connections.autoFarm then
        pcall(function() task.cancel(STATE.connections.autoFarm) end)
        STATE.connections.autoFarm = nil
    end
    log("Auto Farm: OFF", "warn")
end

--==============================================================================
-- ESP SYSTEM
--==============================================================================
local function clearESP()
    for _, obj in ipairs(STATE.espObjects) do
        pcall(function()
            if obj and obj.Parent then obj:Destroy() end
        end)
    end
    STATE.espObjects = {}
end

local function createESP(target, color)
    if not target or not target.Parent then return end
    local adornee = nil
    if target:IsA("Model") then
        adornee = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart", true)
    elseif target:IsA("BasePart") then
        adornee = target
    end
    if not adornee then return end
    
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "ESP"
    box.Adornee = adornee
    box.Size = adornee.Size + Vector3.new(0.5, 0.5, 0.5)
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = color
    pcall(function()
        box.Parent = CoreGui
    end)
    if not box.Parent then
        pcall(function()
            box.Parent = LocalPlayer:FindFirstChild("PlayerGui")
        end)
    end
    if box.Parent then
        table.insert(STATE.espObjects, box)
    end
end

local function espTick()
    if not STATE.espHerbs and not STATE.espEnemies then return end
    clearESP()
    if STATE.espHerbs then
        for _, herb in ipairs(getAllHerbs()) do
            createESP(herb, Color3.fromRGB(0, 255, 100))
        end
    end
    if STATE.espEnemies then
        for _, enemy in ipairs(getAllEnemies()) do
            createESP(enemy.obj, Color3.fromRGB(255, 60, 60))
        end
    end
end

local function startESP()
    if STATE.connections.esp then
        pcall(function() STATE.connections.esp:Disconnect() end)
    end
    STATE.connections.esp = RunService.Heartbeat:Connect(function()
        pcall(espTick)
    end)
end

local function stopESP()
    if STATE.connections.esp then
        pcall(function() STATE.connections.esp:Disconnect() end)
        STATE.connections.esp = nil
    end
    clearESP()
end

--==============================================================================
-- TELEPORT
--==============================================================================
local function teleportToPosition(pos)
    if not pos or not STATE.rootPart then return end
    pcall(function()
        STATE.rootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
end

local function teleportToNearestHerb()
    local herbs = getAllHerbs()
    local nearest, nearestDist = nil, math.huge
    for _, herb in ipairs(herbs) do
        local pos = getHerbPosition(herb)
        if pos then
            local d = getDistanceTo(pos)
            if d < nearestDist then nearest, nearestDist = pos, d end
        end
    end
    if nearest then
        teleportToPosition(nearest)
        log("TP herb (" .. string.format("%.1f", nearestDist) .. ")", "info")
    else
        log("Tidak ada herb", "warn")
    end
end

local function teleportToNearestEnemy()
    local enemies = getAllEnemies()
    local nearest, nearestDist = nil, math.huge
    for _, enemy in ipairs(enemies) do
        local pos = getEnemyPosition(enemy.obj)
        if pos then
            local d = getDistanceTo(pos)
            if d < nearestDist then nearest, nearestDist = pos, d end
        end
    end
    if nearest then
        teleportToPosition(nearest)
        log("TP enemy (" .. string.format("%.1f", nearestDist) .. ")", "info")
    else
        log("Tidak ada enemy", "warn")
    end
end

--==============================================================================
-- SPEED & JUMP
--==============================================================================
local function applySpeedJump()
    if not STATE.humanoid then return end
    pcall(function()
        STATE.humanoid.WalkSpeed = STATE.speedBoost and CONFIG.SPEED_VALUE or 16
        if STATE.jumpBoost then
            STATE.humanoid.UseJumpPower = true
            STATE.humanoid.JumpPower = CONFIG.JUMP_VALUE
        else
            STATE.humanoid.JumpPower = 50
        end
    end)
end

--==============================================================================
-- DRAGGABLE (SIMPLE)
--==============================================================================
local function makeDraggable(frame, handle)
    if not frame or not handle then return end
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging then
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

--==============================================================================
-- MINIMIZE / RESTORE
--==============================================================================
local function minimizeGUI()
    if GUI_REFS.MainFrame then GUI_REFS.MainFrame.Visible = false end
    if GUI_REFS.Bubble then GUI_REFS.Bubble.Visible = true end
end

local function restoreGUI()
    if GUI_REFS.MainFrame then GUI_REFS.MainFrame.Visible = true end
    if GUI_REFS.Bubble then GUI_REFS.Bubble.Visible = false end
end

--==============================================================================
-- GUI CREATION
--==============================================================================
local function createGUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 15)
    if not pg then
        warn("[XGM] PlayerGui gak ketemu!")
        return
    end
    print("[XGM] PlayerGui OK")
    
    -- Hapus GUI lama
    local old = pg:FindFirstChild("XianxiaGodMode_ADIEL")
    if old then
        old:Destroy()
        print("[XGM] Old GUI removed")
    end
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "XianxiaGodMode_ADIEL"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = pg
    GUI_REFS.ScreenGui = sg
    print("[XGM] ScreenGui created")
    
    -- MAIN FRAME
    local mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 680, 0, 300)
    mf.Position = UDim2.new(0.5, -340, 0.5, -150)
    mf.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Parent = sg
    GUI_REFS.MainFrame = mf
    local mfc = Instance.new("UICorner"); mfc.CornerRadius = UDim.new(0, 10); mfc.Parent = mf
    local mfs = Instance.new("UIStroke"); mfs.Color = Color3.fromRGB(60, 40, 80); mfs.Thickness = 1; mfs.Parent = mf
    print("[XGM] MainFrame created")
    
    -- TITLE BAR
    local tb = Instance.new("Frame")
    tb.Name = "TitleBar"
    tb.Size = UDim2.new(1, 0, 0, 35)
    tb.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    tb.BorderSizePixel = 0
    tb.Active = true
    tb.Parent = mf
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 10); tbc.Parent = tb
    
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -90, 1, 0)
    tl.Position = UDim2.new(0, 12, 0, 0)
    tl.BackgroundTransparency = 1
    tl.Text = "XIANXIA GOD MODE v1.2 - ADIEL"
    tl.TextColor3 = Color3.fromRGB(200, 130, 255)
    tl.TextSize = 13
    tl.Font = Enum.Font.GothamBold
    tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Parent = tb
    print("[XGM] TitleBar created")
    
    -- MINIMIZE BUTTON
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
    GUI_REFS.Buttons.minBtn = minB
    
    -- CLOSE BUTTON
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
    GUI_REFS.Buttons.closeBtn = clB
    
    -- HELPER: BUTTON
    local function mkBtn(parent, n, txt, y, h, col)
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
        b.Parent = parent
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
        return b
    end
    
    -- HELPER: LABEL
    local function mkLbl(parent, n, y, col, size)
        local l = Instance.new("TextLabel")
        l.Name = n
        l.Size = UDim2.new(1, -16, 0, 18)
        l.Position = UDim2.new(0, 8, 0, y)
        l.BackgroundTransparency = 1
        l.Text = n .. ": 0"
        l.TextColor3 = col
        l.TextSize = size or 11
        l.Font = Enum.Font.Code
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = parent
        return l
    end
    
    -- COL 1: HERBS
    local c1 = Instance.new("ScrollingFrame")
    c1.Name = "Col1"
    c1.Size = UDim2.new(0, 218, 0, 250)
    c1.Position = UDim2.new(0, 6, 0, 42)
    c1.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c1.BorderSizePixel = 0
    c1.ScrollBarThickness = 4
    c1.CanvasSize = UDim2.new(0, 0, 0, 220)
    c1.Parent = mf
    local c1c = Instance.new("UICorner"); c1c.CornerRadius = UDim.new(0, 8); c1c.Parent = c1
    
    local c1t = Instance.new("TextLabel")
    c1t.Size = UDim2.new(1, -16, 0, 22)
    c1t.Position = UDim2.new(0, 8, 0, 6)
    c1t.BackgroundTransparency = 1
    c1t.Text = "HERB FARMER"
    c1t.TextColor3 = Color3.fromRGB(0, 255, 100)
    c1t.TextSize = 14
    c1t.Font = Enum.Font.GothamBold
    c1t.TextXAlignment = Enum.TextXAlignment.Left
    c1t.Parent = c1
    
    GUI_REFS.Buttons.harvestNow = mkBtn(c1, "HarvestNow", "HARVEST ALL", 32, 38, Color3.fromRGB(0, 160, 90))
    GUI_REFS.Buttons.autoHarvest = mkBtn(c1, "AutoHarvest", "AUTO HARVEST: OFF", 74, 30, Color3.fromRGB(0, 110, 180))
    GUI_REFS.Buttons.autoFarm = mkBtn(c1, "AutoFarm", "AUTO FARM: OFF", 108, 30, Color3.fromRGB(80, 60, 160))
    GUI_REFS.Buttons.espHerbs = mkBtn(c1, "ESPHerbs", "ESP HERBS: OFF", 142, 28, Color3.fromRGB(100, 100, 0))
    GUI_REFS.Buttons.tpHHerb = mkBtn(c1, "TpHerb", "TELEPORT HERB", 174, 28, Color3.fromRGB(60, 80, 120))
    print("[XGM] Col1 created")
    
    -- COL 2: COMBAT
    local c2 = Instance.new("ScrollingFrame")
    c2.Name = "Col2"
    c2.Size = UDim2.new(0, 218, 0, 250)
    c2.Position = UDim2.new(0, 230, 0, 42)
    c2.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c2.BorderSizePixel = 0
    c2.ScrollBarThickness = 4
    c2.CanvasSize = UDim2.new(0, 0, 0, 220)
    c2.Parent = mf
    local c2c = Instance.new("UICorner"); c2c.CornerRadius = UDim.new(0, 8); c2c.Parent = c2
    
    local c2t = Instance.new("TextLabel")
    c2t.Size = UDim2.new(1, -16, 0, 22)
    c2t.Position = UDim2.new(0, 8, 0, 6)
    c2t.BackgroundTransparency = 1
    c2t.Text = "COMBAT"
    c2t.TextColor3 = Color3.fromRGB(255, 100, 100)
    c2t.TextSize = 14
    c2t.Font = Enum.Font.GothamBold
    c2t.TextXAlignment = Enum.TextXAlignment.Left
    c2t.Parent = c2
    
    GUI_REFS.Buttons.killAura = mkBtn(c2, "KillAura", "KILL AURA: OFF", 32, 38, Color3.fromRGB(180, 50, 50))
    GUI_REFS.Buttons.espEnemies = mkBtn(c2, "ESPEnemies", "ESP ENEMY: OFF", 74, 28, Color3.fromRGB(100, 100, 0))
    GUI_REFS.Buttons.tpEnemy = mkBtn(c2, "TpEnemy", "TELEPORT ENEMY", 106, 28, Color3.fromRGB(60, 80, 120))
    GUI_REFS.Buttons.equipTool = mkBtn(c2, "EquipTool", "EQUIP TOOL", 138, 28, Color3.fromRGB(70, 70, 70))
    GUI_REFS.Buttons.scanCombat = mkBtn(c2, "ScanCombat", "SCAN ENEMY", 170, 28, Color3.fromRGB(60, 50, 90))
    print("[XGM] Col2 created")
    
    -- COL 3: STATS
    local c3 = Instance.new("ScrollingFrame")
    c3.Name = "Col3"
    c3.Size = UDim2.new(0, 218, 0, 250)
    c3.Position = UDim2.new(0, 454, 0, 42)
    c3.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    c3.BorderSizePixel = 0
    c3.ScrollBarThickness = 4
    c3.CanvasSize = UDim2.new(0, 0, 0, 220)
    c3.Parent = mf
    local c3c = Instance.new("UICorner"); c3c.CornerRadius = UDim.new(0, 8); c3c.Parent = c3
    
    local c3t = Instance.new("TextLabel")
    c3t.Size = UDim2.new(1, -16, 0, 22)
    c3t.Position = UDim2.new(0, 8, 0, 6)
    c3t.BackgroundTransparency = 1
    c3t.Text = "STATS + MOVE"
    c3t.TextColor3 = Color3.fromRGB(0, 200, 255)
    c3t.TextSize = 14
    c3t.Font = Enum.Font.GothamBold
    c3t.TextXAlignment = Enum.TextXAlignment.Left
    c3t.Parent = c3
    
    GUI_REFS.Buttons.speed = mkBtn(c3, "Speed", "SPEED: OFF", 32, 28, Color3.fromRGB(0, 110, 180))
    GUI_REFS.Buttons.jump = mkBtn(c3, "Jump", "JUMP: OFF", 64, 28, Color3.fromRGB(0, 110, 180))
    
    GUI_REFS.Labels.harvested = mkLbl(c3, "Harvested", 98, Color3.fromRGB(0, 220, 130))
    GUI_REFS.Labels.killed = mkLbl(c3, "Killed", 116, Color3.fromRGB(240, 120, 120))
    GUI_REFS.Labels.herbs = mkLbl(c3, "Herbs", 134, Color3.fromRGB(140, 220, 140))
    GUI_REFS.Labels.enemies = mkLbl(c3, "Enemies", 152, Color3.fromRGB(255, 150, 150))
    GUI_REFS.Labels.status = mkLbl(c3, "Status", 174, Color3.fromRGB(0, 220, 130), 12)
    GUI_REFS.Labels.status.Text = "Status: IDLE"
    
    local cr = Instance.new("TextLabel")
    cr.Size = UDim2.new(1, -16, 0, 20)
    cr.Position = UDim2.new(0, 8, 0, 196)
    cr.BackgroundTransparency = 1
    cr.Text = "Created by ADIEL"
    cr.TextColor3 = Color3.fromRGB(100, 100, 130)
    cr.TextSize = 10
    cr.Font = Enum.Font.Gotham
    cr.TextXAlignment = Enum.TextXAlignment.Left
    cr.Parent = c3
    print("[XGM] Col3 created")
    
    -- BUBBLE
    local bubble = Instance.new("TextButton")
    bubble.Name = "FloatingBubble"
    bubble.Size = UDim2.new(0, 55, 0, 55)
    bubble.Position = UDim2.new(0, 20, 0.4, 0)
    bubble.BackgroundColor3 = Color3.fromRGB(120, 60, 180)
    bubble.BorderSizePixel = 0
    bubble.Text = "XGM"
    bubble.TextColor3 = Color3.fromRGB(240, 240, 240)
    bubble.TextSize = 14
    bubble.Font = Enum.Font.GothamBold
    bubble.Visible = false
    bubble.Active = true
    bubble.ZIndex = 100
    bubble.Parent = sg
    GUI_REFS.Bubble = bubble
    local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(1, 0); bbc.Parent = bubble
    local bbs = Instance.new("UIStroke"); bbs.Color = Color3.fromRGB(200, 130, 255); bbs.Thickness = 2; bbs.Parent = bubble
    print("[XGM] Bubble created")
    
    print("[XGM] === GUI CREATED SUCCESSFULLY ===")
end

--==============================================================================
-- STATS UPDATER
--==============================================================================
local function startStatsUpdater()
    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                local herbs = getAllHerbs()
                local enemies = getAllEnemies()
                stats.lastHerbCount = #herbs
                stats.lastEnemyCount = #enemies
                
                if GUI_REFS.Labels.harvested then
                    GUI_REFS.Labels.harvested.Text = "Harvested: " .. tostring(stats.harvested)
                end
                if GUI_REFS.Labels.killed then
                    GUI_REFS.Labels.killed.Text = "Killed: " .. tostring(stats.killed)
                end
                if GUI_REFS.Labels.herbs then
                    GUI_REFS.Labels.herbs.Text = "Herbs: " .. tostring(#herbs)
                end
                if GUI_REFS.Labels.enemies then
                    GUI_REFS.Labels.enemies.Text = "Enemies: " .. tostring(#enemies)
                end
                if GUI_REFS.Labels.status then
                    local statusText = "IDLE"
                    local statusColor = Color3.fromRGB(0, 220, 130)
                    if STATE.autoFarm then
                        statusText = "AUTO FARM"; statusColor = Color3.fromRGB(160, 100, 255)
                    elseif STATE.killAura and STATE.autoHarvest then
                        statusText = "FULL MODE"; statusColor = Color3.fromRGB(255, 200, 0)
                    elseif STATE.killAura then
                        statusText = "KILL AURA"; statusColor = Color3.fromRGB(255, 100, 100)
                    elseif STATE.autoHarvest then
                        statusText = "AUTO HARVEST"; statusColor = Color3.fromRGB(0, 200, 255)
                    end
                    GUI_REFS.Labels.status.Text = "Status: " .. statusText
                    GUI_REFS.Labels.status.TextColor3 = statusColor
                end
            end)
        end
    end)
end

--==============================================================================
-- EVENTS
--==============================================================================
local function bindEvents()
    print("[XGM] Binding events...")
    
    GUI_REFS.Buttons.harvestNow.MouseButton1Click:Connect(function()
        task.spawn(function() pcall(harvestAllHerbs) end)
    end)
    
    GUI_REFS.Buttons.autoHarvest.MouseButton1Click:Connect(function()
        STATE.autoHarvest = not STATE.autoHarvest
        if STATE.autoHarvest then
            GUI_REFS.Buttons.autoHarvest.Text = "AUTO HARVEST: ON"
            GUI_REFS.Buttons.autoHarvest.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
            task.spawn(function()
                while STATE.autoHarvest do
                    pcall(harvestAllHerbs)
                    task.wait(1)
                end
            end)
        else
            GUI_REFS.Buttons.autoHarvest.Text = "AUTO HARVEST: OFF"
            GUI_REFS.Buttons.autoHarvest.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        end
    end)
    
    GUI_REFS.Buttons.autoFarm.MouseButton1Click:Connect(function()
        if STATE.autoFarm then
            stopAutoFarm()
            GUI_REFS.Buttons.autoFarm.Text = "AUTO FARM: OFF"
            GUI_REFS.Buttons.autoFarm.BackgroundColor3 = Color3.fromRGB(80, 60, 160)
        else
            STATE.autoFarm = true
            startAutoFarm()
            GUI_REFS.Buttons.autoFarm.Text = "AUTO FARM: ON"
            GUI_REFS.Buttons.autoFarm.BackgroundColor3 = Color3.fromRGB(130, 90, 220)
        end
    end)
    
    GUI_REFS.Buttons.espHerbs.MouseButton1Click:Connect(function()
        STATE.espHerbs = not STATE.espHerbs
        if STATE.espHerbs then
            GUI_REFS.Buttons.espHerbs.Text = "ESP HERBS: ON"
            GUI_REFS.Buttons.espHerbs.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
            startESP()
        else
            GUI_REFS.Buttons.espHerbs.Text = "ESP HERBS: OFF"
            GUI_REFS.Buttons.espHerbs.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
            if not STATE.espEnemies then stopESP() end
        end
    end)
    
    GUI_REFS.Buttons.tpHHerb.MouseButton1Click:Connect(function()
        task.spawn(function() pcall(teleportToNearestHerb) end)
    end)
    
    GUI_REFS.Buttons.killAura.MouseButton1Click:Connect(function()
        STATE.killAura = not STATE.killAura
        if STATE.killAura then
            GUI_REFS.Buttons.killAura.Text = "KILL AURA: ON"
            GUI_REFS.Buttons.killAura.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
            startKillAura()
        else
            GUI_REFS.Buttons.killAura.Text = "KILL AURA: OFF"
            GUI_REFS.Buttons.killAura.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
            stopKillAura()
        end
    end)
    
    GUI_REFS.Buttons.espEnemies.MouseButton1Click:Connect(function()
        STATE.espEnemies = not STATE.espEnemies
        if STATE.espEnemies then
            GUI_REFS.Buttons.espEnemies.Text = "ESP ENEMY: ON"
            GUI_REFS.Buttons.espEnemies.BackgroundColor3 = Color3.fromRGB(150, 150, 0)
            startESP()
        else
            GUI_REFS.Buttons.espEnemies.Text = "ESP ENEMY: OFF"
            GUI_REFS.Buttons.espEnemies.BackgroundColor3 = Color3.fromRGB(100, 100, 0)
            if not STATE.espHerbs then stopESP() end
        end
    end)
    
    GUI_REFS.Buttons.tpEnemy.MouseButton1Click:Connect(function()
        task.spawn(function() pcall(teleportToNearestEnemy) end)
    end)
    
    GUI_REFS.Buttons.equipTool.MouseButton1Click:Connect(function()
        pcall(equipFirstTool)
        log("Tool di-equip", "info")
    end)
    
    GUI_REFS.Buttons.scanCombat.MouseButton1Click:Connect(function()
        local enemies = getAllEnemies()
        log("Enemies: " .. tostring(#enemies), "info")
    end)
    
    GUI_REFS.Buttons.speed.MouseButton1Click:Connect(function()
        STATE.speedBoost = not STATE.speedBoost
        applySpeedJump()
        if STATE.speedBoost then
            GUI_REFS.Buttons.speed.Text = "SPEED: ON"
            GUI_REFS.Buttons.speed.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        else
            GUI_REFS.Buttons.speed.Text = "SPEED: OFF"
            GUI_REFS.Buttons.speed.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        end
    end)
    
    GUI_REFS.Buttons.jump.MouseButton1Click:Connect(function()
        STATE.jumpBoost = not STATE.jumpBoost
        applySpeedJump()
        if STATE.jumpBoost then
            GUI_REFS.Buttons.jump.Text = "JUMP: ON"
            GUI_REFS.Buttons.jump.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        else
            GUI_REFS.Buttons.jump.Text = "JUMP: OFF"
            GUI_REFS.Buttons.jump.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        end
    end)
    
    GUI_REFS.Buttons.minBtn.MouseButton1Click:Connect(function() minimizeGUI() end)
    GUI_REFS.Buttons.closeBtn.MouseButton1Click:Connect(function() minimizeGUI() end)
    GUI_REFS.Bubble.MouseButton1Click:Connect(function() restoreGUI() end)
    
    print("[XGM] Events bound successfully")
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

--==============================================================================
-- INIT
--==============================================================================
local function init()
    print("[XGM] === INIT START ===")
    
    step("updateCharacterRefs", updateCharacterRefs)
    
    step("character listener", function()
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(2)
            updateCharacterRefs()
            applySpeedJump()
        end)
    end)
    
    step("createGUI", createGUI)
    
    step("makeDraggable main", function()
        local titleBar = GUI_REFS.MainFrame and GUI_REFS.MainFrame:FindFirstChild("TitleBar")
        if GUI_REFS.MainFrame and titleBar then
            makeDraggable(GUI_REFS.MainFrame, titleBar)
            print("[XGM] Main draggable OK")
        else
            warn("[XGM] MainFrame or TitleBar nil!")
        end
    end)
    
    step("makeDraggable bubble", function()
        if GUI_REFS.Bubble then
            makeDraggable(GUI_REFS.Bubble, GUI_REFS.Bubble)
            print("[XGM] Bubble draggable OK")
        end
    end)
    
    step("bindEvents", bindEvents)
    step("startStatsUpdater", startStatsUpdater)
    step("setupAntiAFK", setupAntiAFK)
    
    print("[XGM] === ALL STEPS DONE ===")
    log("Script Created by ADIEL - v1.2", "success")
    log("Herbs: " .. tostring(#getAllHerbs()) .. " | Enemy: " .. tostring(#getAllEnemies()), "info")
end

init()
