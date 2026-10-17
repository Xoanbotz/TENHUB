--[[
================================================================================
    MOTOR MONEY FARMER - UNIVERSAL
    Script Created by ADIEL
    Executor: Delta / Codex / Wave / Xeno
    
    Fungsi:
    - Scan remote yang berhubungan dengan duit / cash / money / reward
    - Scan remote motor / vehicle / drive / ride
    - Auto-fire remote duit pas lo naik motor
    - Auto-teleport muter-muter map biar motor dianggap "jalan"
    - Mode: FAKE DRIVE (kirim posisi palsu ke server)
    
    Cocok buat game: naik motor = duit nambah
================================================================================
]]

print("[MOTORFARM] Loading...")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

--==============================================================================
-- CONFIG
--==============================================================================
local CONFIG = {
    MONEY_KEYWORDS = {"money","cash","coin","reward","earn","income","salary","pay","fund","currency","bucks","dollar","$","balance","wallet","profit"},
    MOTOR_KEYWORDS = {"motor","bike","vehicle","drive","ride","cycle","scooter","car","wheel","speed"},
    SCAN_INTERVAL  = 3,
    FIRE_INTERVAL  = 0.1,
    FAKE_DRIVE_SPEED = 100, -- stud/detik buat fake drive
    DEBUG          = true,
}

--==============================================================================
-- STATE
--==============================================================================
local STATE = {
    character = nil,
    humanoid = nil,
    rootPart = nil,
    vehicleSeat = nil,
    moneyRemotes = {},
    motorRemotes = {},
    autoFarm = false,
    fakeDrive = false,
    fakeDriveThread = nil,
    remoteScanThread = nil,
    fireThread = nil,
    autoFarmThread = nil,
    earnedCount = 0,
    scanCount = 0,
}

--==============================================================================
-- LOG
--==============================================================================
local function log(msg, t)
    t = t or "info"
    local prefix = "[MOTORFARM] "
    if t == "error" then warn(prefix..msg)
    elseif t == "success" then print(prefix.."✓ "..msg)
    else print(prefix..msg) end
end

--==============================================================================
-- CHARACTER
--==============================================================================
local function updateChar()
    local c = LP.Character
    if c then
        STATE.character = c
        STATE.humanoid = c:FindFirstChildOfClass("Humanoid")
        STATE.rootPart = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
    end
end

local function getVehicleSeat()
    if not STATE.character then return nil end
    local seat = STATE.character:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat then return seat end
    -- Cari di seluruh descendant (kadang seat disimpan di model motor)
    for _, child in ipairs(STATE.character:GetDescendants()) do
        if child:IsA("VehicleSeat") then return child end
    end
    return nil
end

--==============================================================================
-- SCAN REMOTE
--==============================================================================
local function keywordMatch(name, keywords)
    local lower = string.lower(name)
    for _, kw in ipairs(keywords) do
        if string.find(lower, string.lower(kw), 1, true) then return true end
    end
    return false
end

local function scanRemotes()
    STATE.moneyRemotes = {}
    STATE.motorRemotes = {}
    local all = 0
    
    local containers = {ReplicatedStorage, Workspace, ServerStorage}
    
    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                        or obj:IsA("UnreliableRemoteEvent") then
                        all = all + 1
                        if keywordMatch(obj.Name, CONFIG.MONEY_KEYWORDS) then
                            table.insert(STATE.moneyRemotes, obj)
                            if CONFIG.DEBUG then
                                log("MONEY remote: " .. obj.Name .. " (" .. obj.ClassName .. ")", "success")
                            end
                        elseif keywordMatch(obj.Name, CONFIG.MOTOR_KEYWORDS) then
                            table.insert(STATE.motorRemotes, obj)
                            if CONFIG.DEBUG then
                                log("MOTOR remote: " .. obj.Name, "success")
                            end
                        end
                    end
                end
            end)
        end
    end
    
    STATE.scanCount = #STATE.moneyRemotes + #STATE.motorRemotes
    log("Scan: " .. all .. " remotes total | Money: " .. #STATE.moneyRemotes .. " | Motor: " .. #STATE.motorRemotes)
end

--==============================================================================
-- FIRE MONEY REMOTE
--==============================================================================
local function fireMoney()
    if #STATE.moneyRemotes == 0 then return end
    
    for _, remote in ipairs(STATE.moneyRemotes) do
        pcall(function()
            if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
                -- Coba berbagai argumen
                remote:FireServer()
                remote:FireServer(1)
                remote:FireServer(100)
                remote:FireServer(1000)
                remote:FireServer(STATE.vehicleSeat or STATE.rootPart)
                remote:FireServer("drive")
                remote:FireServer("ride")
                remote:FireServer(LP)
                remote:FireServer(LP.UserId)
            elseif remote:IsA("RemoteFunction") then
                pcall(function() remote:InvokeServer() end)
                pcall(function() remote:InvokeServer(1) end)
                pcall(function() remote:InvokeServer("drive") end)
            end
        end)
        STATE.earnedCount = STATE.earnedCount + 1
    end
end

--==============================================================================
-- FAKE DRIVE (kirim posisi palsu biar dianggap jalan)
--==============================================================================
local function startFakeDrive()
    if STATE.fakeDriveThread then
        pcall(function() task.cancel(STATE.fakeDriveThread) end)
    end
    
    STATE.fakeDrive = true
    STATE.fakeDriveThread = task.spawn(function()
        local angle = 0
        while STATE.fakeDrive do
            pcall(function()
                local seat = getVehicleSeat()
                if seat and STATE.rootPart then
                    -- Putar keliling
                    angle = angle + 0.5
                    local radius = 20
                    local offset = Vector3.new(
                        math.cos(angle) * radius,
                        0,
                        math.sin(angle) * radius
                    )
                    local basePos = STATE.rootPart.Position
                    seat.CFrame = CFrame.new(basePos + offset)
                end
            end)
            task.wait(0.1)
        end
    end)
    
    log("Fake Drive: ON", "success")
end

local function stopFakeDrive()
    STATE.fakeDrive = false
    if STATE.fakeDriveThread then
        pcall(function() task.cancel(STATE.fakeDriveThread) end)
        STATE.fakeDriveThread = nil
    end
    log("Fake Drive: OFF", "warn")
end

--==============================================================================
-- AUTO FARM LOOP
--==============================================================================
local function startAutoFarm()
    if STATE.autoFarmThread then
        pcall(function() task.cancel(STATE.autoFarmThread) end)
    end
    
    STATE.autoFarm = true
    STATE.autoFarmThread = task.spawn(function()
        while STATE.autoFarm do
            pcall(function()
                local seat = getVehicleSeat()
                if seat then
                    fireMoney()
                end
            end)
            task.wait(CONFIG.FIRE_INTERVAL)
        end
    end)
    
    log("Auto Farm: ON", "success")
end

local function stopAutoFarm()
    STATE.autoFarm = false
    if STATE.autoFarmThread then
        pcall(function() task.cancel(STATE.autoFarmThread) end)
        STATE.autoFarmThread = nil
    end
    log("Auto Farm: OFF", "warn")
end

--==============================================================================
-- AUTO TELEPORT MUTER
--==============================================================================
local function startAutoTeleport()
    task.spawn(function()
        local angle = 0
        while STATE.autoFarm do
            pcall(function()
                if STATE.rootPart then
                    angle = angle + 1
                    local radius = 50
                    local origin = STATE.rootPart.Position
                    local newPos = origin + Vector3.new(
                        math.cos(angle) * radius,
                        0,
                        math.sin(angle) * radius
                    )
                    STATE.rootPart.CFrame = CFrame.new(newPos, newPos + Vector3.new(0, 0, 10))
                end
            end)
            task.wait(0.2)
        end
    end)
    log("Auto Teleport: ON", "success")
end

--==============================================================================
-- GUI
--==============================================================================
local function createGUI()
    local pg = LP:WaitForChild("PlayerGui", 15)
    if not pg then return end
    
    local old = pg:FindFirstChild("MotorFarmer_ADIEL")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MotorFarmer_ADIEL"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = pg
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 320)
    frame.Position = UDim2.new(0, 20, 0.5, -160)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
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
    
    -- TITLE
    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1, 0, 0, 32)
    tb.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    tb.BorderSizePixel = 0
    tb.Active = true
    tb.Parent = frame
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 10); tbc.Parent = tb
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "MOTOR MONEY FARMER - ADIEL"
    title.TextColor3 = Color3.fromRGB(0, 220, 130)
    title.TextSize = 13
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = tb
    
    local minB = Instance.new("TextButton")
    minB.Size = UDim2.new(0, 24, 0, 24)
    minB.Position = UDim2.new(1, -28, 0, 4)
    minB.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    minB.BorderSizePixel = 0
    minB.Text = "X"
    minB.TextColor3 = Color3.fromRGB(255, 255, 255)
    minB.TextSize = 12
    minB.Font = Enum.Font.GothamBold
    minB.Parent = tb
    local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 5); mbc.Parent = minB
    
    -- STATUS
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 40)
    statusLbl.Position = UDim2.new(0, 10, 0, 38)
    statusLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    statusLbl.BorderSizePixel = 0
    statusLbl.Text = "SCAN: Click SCAN dulu buat cari remote"
    statusLbl.TextColor3 = Color3.fromRGB(180, 200, 255)
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextWrapped = true
    statusLbl.Parent = frame
    local slc = Instance.new("UICorner"); slc.CornerRadius = UDim.new(0, 6); slc.Parent = statusLbl
    local slp = Instance.new("UIPadding"); slp.PaddingLeft = UDim.new(0, 8); slp.PaddingRight = UDim.new(0, 8); slp.Parent = statusLbl
    
    -- BUTTON HELPER
    local function mkBtn(text, y, h, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, h)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 12
        b.Font = Enum.Font.GothamBold
        b.Parent = frame
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = b
        return b
    end
    
    local scanBtn = mkBtn("SCAN REMOTES", 85, 32, Color3.fromRGB(60, 50, 120))
    local driveBtn = mkBtn("FAKE DRIVE: OFF", 121, 32, Color3.fromRGB(0, 110, 180))
    local farmBtn = mkBtn("AUTO FARM: OFF", 157, 40, Color3.fromRGB(0, 160, 90))
    local tpBtn = mkBtn("AUTO TELEPORT MUTER", 201, 30, Color3.fromRGB(120, 60, 160))
    local manualBtn = mkBtn("FIRE MANUAL (1x)", 235, 30, Color3.fromRGB(70, 70, 70))
    
    -- INFO
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -20, 0, 40)
    infoLbl.Position = UDim2.new(0, 10, 0, 270)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "Money remotes: 0 | Motor remotes: 0\nFired: 0"
    infoLbl.TextColor3 = Color3.fromRGB(160, 220, 160)
    infoLbl.TextSize = 11
    infoLbl.Font = Enum.Font.Code
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.TextYAlignment = Enum.TextYAlignment.Top
    infoLbl.Parent = frame
    
    -- DRAG
    local dragging = false
    local dragStart, startPos
    tb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    tb.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- CLOSE
    minB.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    -- SCAN
    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "SCANNING..."
        task.spawn(function()
            pcall(scanRemotes)
            scanBtn.Text = "SCAN REMOTES"
            statusLbl.Text = "Money remotes: " .. #STATE.moneyRemotes .. "\nMotor remotes: " .. #STATE.motorRemotes
            if #STATE.moneyRemotes > 0 then
                statusLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
            end
        end)
    end)
    
    -- FAKE DRIVE
    driveBtn.MouseButton1Click:Connect(function()
        if STATE.fakeDrive then
            stopFakeDrive()
            driveBtn.Text = "FAKE DRIVE: OFF"
            driveBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 180)
        else
            startFakeDrive()
            driveBtn.Text = "FAKE DRIVE: ON"
            driveBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
        end
    end)
    
    -- AUTO FARM
    farmBtn.MouseButton1Click:Connect(function()
        if STATE.autoFarm then
            stopAutoFarm()
            farmBtn.Text = "AUTO FARM: OFF"
            farmBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
        else
            startAutoFarm()
            farmBtn.Text = "AUTO FARM: ON"
            farmBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 130)
        end
    end)
    
    -- AUTO TELEPORT
    tpBtn.MouseButton1Click:Connect(function()
        if not STATE.autoFarm then
            startAutoFarm()
            farmBtn.Text = "AUTO FARM: ON"
            farmBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 130)
        end
        startAutoTeleport()
    end)
    
    -- MANUAL FIRE
    manualBtn.MouseButton1Click:Connect(function()
        pcall(fireMoney)
        log("Manual fire: " .. #STATE.moneyRemotes .. " remotes")
    end)
    
    -- INFO UPDATE
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            pcall(function()
                infoLbl.Text = "Money remotes: " .. #STATE.moneyRemotes ..
                    " | Motor remotes: " .. #STATE.motorRemotes ..
                    "\nFired: " .. STATE.earnedCount ..
                    " | Seat: " .. (getVehicleSeat() and "YES" or "NO")
            end)
        end
    end)
end

--==============================================================================
-- ANTI AFK
--==============================================================================
pcall(function()
    LP.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0))
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0))
    end)
end)

--==============================================================================
-- INIT
--==============================================================================
local function init()
    updateChar()
    LP.CharacterAdded:Connect(function()
        task.wait(2)
        updateChar()
    end)
    
    createGUI()
    
    task.spawn(function()
        task.wait(1)
        pcall(scanRemotes)
    end)
    
    log("Loaded - Script Created by ADIEL", "success")
    log("TIP: Klik SCAN REMOTES dulu, liat hasilnya di GUI", "success")
end

init()
