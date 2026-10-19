--[[
=========================================================
  AUTO COLLECT PLANTS - RAYFIELD UI
  Author: Kyriel (for ADIEL)
  Executor: Delta / Codex / Wave / Xeno

FITUR:
  - Rayfield UI Library
  - Multi-Select Dropdown tanaman
  - Toggle Auto Collect
  - Press method (MouseButton1Click/Activated/Down/Up)
  - Anti-AFK
=========================================================
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- ============================================================
-- LOAD RAYFIELD UI
-- ============================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- STATE
-- ============================================================
local isAutoCollecting = false
local selectedPlants = {}  -- Multi-select: array of selected plant names

-- ============================================================
-- CONFIG
-- ============================================================
-- Daftar tanaman yang bisa dipilih di dropdown
local PLANT_LIST = {
    "Meridian Roots",
    "Ice Lotus",
    "Lotus",
    "Ginseng",
    "Essence Leaf",
    "Spirit Grass",
}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

-- Fungsi press: fire semua event signal di button
local function press(btn)
    for _, sig in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up"}) do
        pcall(function()
            for _, c in ipairs(getconnections(btn[sig])) do
                c:Fire()
            end
        end)
    end
end

-- Cek apakah object adalah tanaman yang dipilih
local function isSelectedPlant(o)
    local nameLower = string.lower(o.Name or "")
    
    -- Kalo TextLabel/TextButton, ikutin text-nya juga
    if o:IsA("TextLabel") or o:IsA("TextButton") then
        nameLower = nameLower .. " " .. string.lower(o.Text or "")
    end
    
    -- Cek ke setiap plant yang dipilih user
    for _, plantName in ipairs(selectedPlants) do
        if string.find(nameLower, string.lower(plantName)) then
            return true
        end
    end
    return false
end

-- Cek apakah object di dalam folder "template" (buat skip template)
local function isTemplate(o)
    local p = o
    while p and p ~= player.PlayerGui do
        local pName = string.lower(p.Name or "")
        if string.find(pName, "template") then
            return true
        end
        p = p.Parent
    end
    return false
end

-- Ambil label (nama + text) dari button
local function getBtnLabel(btn)
    local name = string.lower(btn.Name or "")
    local text = ""
    if btn:IsA("TextButton") then
        text = string.lower(btn.Text or "")
    end
    return name .. " " .. text
end

-- ============================================================
-- COLLECT LOGIC (sama kayak script sebelumnya)
-- ============================================================

-- Cari tombol Collect di frame induk item, lalu klik
local function collectItem(item)
    local p = item
    -- Naik maksimal 5 level parent buat cari tombol
    for _ = 1, 5 do
        p = p.Parent
        if not p or p == player.PlayerGui then return false end
        
        local collectBtn = nil
        for _, d in ipairs(p:GetDescendants()) do
            if d:IsA("GuiButton") then
                local lbl = getBtnLabel(d)
                -- Cari tombol yang namanya/text mengandung "collect" atau "harvest"
                if string.find(lbl, "collect") 
                    or string.find(lbl, "harvest")
                    or string.find(lbl, "ambil")
                    or string.find(lbl, "pick") then
                    collectBtn = d
                    break
                end
            end
        end
        
        if collectBtn then
            press(collectBtn)
            return true
        end
    end
    return false
end

-- Satu iterasi collect: scan semua GUI, cari item yang dipilih, klik collect
local function collectOnce()
    local collectedCount = 0
    
    pcall(function()
        for _, o in ipairs(player.PlayerGui:GetDescendants()) do
            -- Skip kalo di dalam folder template
            if not isTemplate(o) and isSelectedPlant(o) then
                if collectItem(o) then
                    collectedCount = collectedCount + 1
                end
            end
        end
    end)
    
    return collectedCount
end

-- ============================================================
-- GUI RAYFIELD
-- ============================================================

-- Buat window utama
local Window = Rayfield:CreateWindow({
    Name = "Auto Collect Plants",
    LoadingTitle = "Cyber Edition",
    LoadingSubtitle = "by ADIEL",
    ConfigurationSaving = {
        Enabled = false,
    },
    KeySystem = false,
})

-- Tab utama
local MainTab = Window:CreateTab("Auto Collect", 4483362458)  -- icon ID

-- Section Info
local InfoSection = MainTab:CreateSection("Plant Selection")

-- ============================================================
-- MULTI-SELECT DROPDOWN TANAMAN
-- ============================================================
-- CATATAN: Di sini lo bisa pilih lebih dari 1 tanaman
-- Selected plants disimpan di variable `selectedPlants`

local PlantDropdown = MainTab:CreateDropdown({
    Name = "Pilih Tanaman",
    Options = PLANT_LIST,
    CurrentOption = {},  -- Kosong dulu
    MultipleOptions = true,  -- MULTI SELECT: bisa pilih lebih dari 1
    Flag = "SelectedPlantsFlag",  -- Internal identifier
    Callback = function(selected)
        -- Callback ini kepanggil tiap kali user ubah pilihan
        -- `selected` adalah table berisi semua opsi yang dipilih
        selectedPlants = {}
        for _, plant in ipairs(selected) do
            table.insert(selectedPlants, plant)
        end
        print("[AutoCollect] Selected: " .. table.concat(selectedPlants, ", "))
    end,
})

-- Section Control
local ControlSection = MainTab:CreateSection("Control")

-- ============================================================
-- TOGGLE AUTO COLLECT
-- ============================================================

local AutoCollectToggle = MainTab:CreateToggle({
    Name = "Auto Collect",
    CurrentValue = false,
    Flag = "AutoCollectFlag",
    Callback = function(state)
        isAutoCollecting = state
        
        if state then
            print("[AutoCollect] STARTED")
            
            -- Jalankan loop di task.spawn
            task.spawn(function()
                while isAutoCollecting do
                    -- Panggil collect sekali
                    local count = collectOnce()
                    
                    if count > 0 then
                        print("[AutoCollect] Collected: " .. count)
                    end
                    
                    -- Tunggu 5 detik sebelum scan lagi
                    task.wait(5)
                end
                print("[AutoCollect] STOPPED")
            end)
        else
            print("[AutoCollect] Toggle OFF")
            -- Loop bakal berhenti sendiri karena isAutoCollecting = false
        end
    end,
})

-- Section Manual
local ManualSection = MainTab:CreateSection("Manual")

-- ============================================================
-- BUTTON: COLLECT SEKARANG (manual, sekali klik)
-- ============================================================

local CollectNowBtn = MainTab:CreateButton({
    Name = "Collect Sekarang",
    Callback = function()
        local count = collectOnce()
        print("[AutoCollect] Manual collected: " .. count)
    end,
})

-- Section About
local AboutSection = MainTab:CreateSection("Info")

-- Label info
local InfoLabel = MainTab:CreateLabel("Script Created by ADIEL")
local InfoLabel2 = MainTab:CreateLabel("Pilih tanaman di dropdown, lalu aktifkan Auto Collect")

-- ============================================================
-- ANTI-AFK
-- ============================================================
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ============================================================
-- DONE
-- ============================================================
print("=========================================")
print("  AUTO COLLECT PLANTS - RAYFIELD UI")
print("  Script Created by ADIEL")
print("=========================================")
print("Pilih tanaman di dropdown, lalu aktifkan toggle Auto Collect")
