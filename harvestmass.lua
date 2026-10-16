--[[
================================================================================
    TEST GUI - CEK DULU BISA MUNCUL APA ENGGAK
    Script Created by ADIEL
================================================================================
]]

print("[TEST] Script starting...")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

print("[TEST] LocalPlayer:", LocalPlayer and LocalPlayer.Name or "NIL")

local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
print("[TEST] PlayerGui:", pg and "OK" or "NIL")

if not pg then
    warn("[TEST] PlayerGui tidak ketemu!")
    return
end

-- Hapus GUI lama kalo ada
local old = pg:FindFirstChild("TEST_GUI_ADIEL")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "TEST_GUI_ADIEL"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = pg

print("[TEST] ScreenGui created")

-- FRAME UTAMA
local mf = Instance.new("Frame")
mf.Name = "MainFrame"
mf.Size = UDim2.new(0, 500, 0, 250)
mf.Position = UDim2.new(0.5, -250, 0.5, -125)
mf.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mf.BorderSizePixel = 2
mf.BorderColor3 = Color3.fromRGB(0, 220, 130)
mf.Active = true
mf.Parent = sg
print("[TEST] MainFrame created")

-- TITLE
local tb = Instance.new("TextLabel")
tb.Size = UDim2.new(1, 0, 0, 40)
tb.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
tb.BorderSizePixel = 0
tb.Text = "TEST GUI - KALO MUNCUL, SCRIPT JALAN"
tb.TextColor3 = Color3.fromRGB(0, 220, 130)
tb.TextSize = 16
tb.Font = Enum.Font.GothamBold
tb.Parent = mf
print("[TEST] Title created")

-- TOMBOL TEST
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -40, 0, 60)
btn.Position = UDim2.new(0, 20, 0, 60)
btn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
btn.BorderSizePixel = 0
btn.Text = "KLIK GW KALO MUNCUL"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextSize = 18
btn.Font = Enum.Font.GothamBold
btn.Parent = mf

local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = btn

-- LABEL INFO
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -40, 0, 30)
lbl.Position = UDim2.new(0, 20, 0, 130)
lbl.BackgroundTransparency = 1
lbl.Text = "Executor: " .. (identifyexecutor and identifyexecutor() or "UNKNOWN")
lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl.TextSize = 14
lbl.Font = Enum.Font.Code
lbl.Parent = mf

-- LABEL HERB/ENEMY COUNT
local lbl2 = Instance.new("TextLabel")
lbl2.Size = UDim2.new(1, -40, 0, 30)
lbl2.Position = UDim2.new(0, 20, 0, 160)
lbl2.BackgroundTransparency = 1
lbl2.Text = "Loading herbs & enemies..."
lbl2.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl2.TextSize = 14
lbl2.Font = Enum.Font.Code
lbl2.Parent = mf

task.spawn(function()
    local cs = game:GetService("CollectionService")
    task.wait(1)
    local herbCount = 0
    local enemyCount = 0
    pcall(function()
        herbCount = #cs:GetTagged("Herbs")
    end)
    pcall(function()
        enemyCount = #cs:GetTagged("Enemy")
    end)
    lbl2.Text = "Herbs: " .. herbCount .. " | Enemies: " .. enemyCount
end)

-- BUTTON CLICK TEST
btn.MouseButton1Click:Connect(function()
    btn.Text = "WORKS! GUI BISA DIKLIK!"
    btn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
end)

print("[TEST] ===== GUI SUCCESSFULLY CREATED =====")
print("[TEST] Kalo GUI gak muncul, berarti executor gak support / ada masalah di PlayerGui")
