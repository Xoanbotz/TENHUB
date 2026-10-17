--[[
    FAKE DRIVE SCRIPT
    Untuk Delta Executor / Synapse / Fluxus
    Gunakan di akun alt!
]]

-- ============ KONFIGURASI ============
local CONFIG = {
    AUTO_SEAT = true,           -- Paksa duduk di kendaraan
    SPEED_SPOOF = true,          -- Spoof speed kendaraan
    SPEED_VALUE = 999,           -- Nilai speed palsu (sesuaikan)
    REMOTE_SPAM = true,          -- Spam remote penghasil uang
    SPAM_DELAY = 0.5,            -- Delay antar spam (detik)
    AUTO_REJOIN = false,         -- Auto rejoin kalau kick
}

-- ============ SERVICES ============
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

print("[🐲 CONQUEROR FAKE DRIVE] Loading...")

-- ============ FUNGSI 1: AUTO SEAT ============
-- Paksa karakter duduk di VehicleSeat terdekat
local function autoSeat()
    if not CONFIG.AUTO_SEAT then return end
    
    task.spawn(function()
        while task.wait(0.5) do
            if not Character or not Character.Parent then break end
            
            -- Cari VehicleSeat di sekitar
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("VehicleSeat") then
                    local distance = (obj.Position - HRP.Position).Magnitude
                    if distance < 15 then  -- Radius 15 stud
                        -- Teleport ke seat + duduk
                        HRP.CFrame = obj.CFrame
                        Humanoid.Sit = true
                        obj:Sit(Humanoid)
                        break
                    end
                end
            end
        end
    end)
end

-- ============ FUNGSI 2: SPEED SPOOF ============
-- Manipulasi speed kendaraan
local function speedSpoof()
    if not CONFIG.SPEED_SPOOF then return end
    
    task.spawn(function()
        while task.wait(0.1) do
            if not Character then break end
            
            -- Cari VehicleSeat tempat duduk
            local seat = Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                -- Spoof atribut speed
                pcall(function()
                    seat.MaxSpeed = CONFIG.SPEED_VALUE
                    seat.Torque = math.huge
                    seat.MaxTorque = math.huge
                end)
                
                -- Cari BodyVelocity / BodyAngularVelocity
                for _, child in pairs(seat:GetChildren()) do
                    if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
                        pcall(function()
                            child.Velocity = Vector3.new(CONFIG.SPEED_VALUE, 0, CONFIG.SPEED_VALUE)
                            child.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        end)
                    end
                end
            end
        end
    end)
end

-- ============ FUNGSI 3: REMOTE SPAM ============
-- Spam remote event yang ngasih uang
local function remoteSpam()
    if not CONFIG.REMOTE_SPAM then return end
    
    -- Cari remote yang namanya mengandung kata uang/money/cash/earn
    local keywords = {"money", "cash", "coin", "earn", "reward", "drive", "vehicle", "pay"}
    local remotes = {}
    
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nameLower = obj.Name:lower()
            for _, kw in pairs(keywords) do
                if nameLower:find(kw) then
                    table.insert(remotes, obj)
                    break
                end
            end
        end
    end
    
    if #remotes == 0 then
        warn("[!] Tidak ada remote uang ditemukan. Coba cari manual.")
        return
    end
    
    print(string.format("[+] Ditemukan %d remote uang", #remotes))
    
    task.spawn(function()
        while task.wait(CONFIG.SPAM_DELAY) do
            if not Character then break end
            
            for _, remote in pairs(remotes) do
                pcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer()
                    else
                        remote:InvokeServer()
                    end
                end)
            end
        end
    end)
end

-- ============ FUNGSI 4: REMOTE LISTENER (untuk debugging) ============
-- Print semua remote yang dikirim game (buat cari remote uang manual)
local function listRemotes()
    print("[*] Daftar RemoteEvent di ReplicatedStorage:")
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            print("  - " .. obj:GetFullName())
        elseif obj:IsA("RemoteFunction") then
            print("  - (RF) " .. obj:GetFullName())
        end
    end
end

-- ============ FUNGSI 5: ANTI-KICK ============
local function antiKick()
    local oldKick = LocalPlayer.Kick
    LocalPlayer.Kick = function(self, reason)
        warn("[!] Kick attempt detected: " .. tostring(reason))
        if CONFIG.AUTO_REJOIN then
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end
    end
end

-- ============ RUN SEMUA ============
local function init()
    print("[🐲 CONQUEROR FAKE DRIVE] Starting...")
    
    -- Tunggu character ready
    if not Character then
        LocalPlayer.CharacterAdded:Connect(function(c)
            Character = c
            Humanoid = c:WaitForChild("Humanoid")
            HRP = c:WaitForChild("HumanoidRootPart")
            task.wait(1)
            autoSeat()
            speedSpoof()
        end)
    end
    
    autoSeat()
    speedSpoof()
    remoteSpam()
    antiKick()
    listRemotes()
    
    print("[✅ CONQUEROR FAKE DRIVE] Aktif!")
    print("  - Auto Seat: " .. tostring(CONFIG.AUTO_SEAT))
    print("  - Speed Spoof: " .. tostring(CONFIG.SPEED_SPOOF))
    print("  - Remote Spam: " .. tostring(CONFIG.REMOTE_SPAM))
    print("  - Speed Value: " .. CONFIG.SPEED_VALUE)
end

init()
