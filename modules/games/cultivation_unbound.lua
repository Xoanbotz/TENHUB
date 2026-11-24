--[[
============================================================
  DUMP DIALOG — standalone
  Cara: buka dialog Shen manual → execute ini → paste hasilnya
============================================================
]]

local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local pgui = Players.LocalPlayer:WaitForChild("PlayerGui")

local lines = {}
local function log(s)
    print(s)
    table.insert(lines, s)
end

log("=== VISIBLE DIALOGS ===")

-- ScreenGui + TextButton/ImageButton/TextLabel
for _, gui in ipairs(pgui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Enabled then
        local anyVisible = false
        for _, d in ipairs(gui:GetDescendants()) do
            if d.Visible and (d:IsA("TextButton") or d:IsA("ImageButton")
                or d:IsA("Frame")) then
                anyVisible = true
                break
            end
        end
        if not anyVisible then continue end

        log("")
        log("GUI: " .. gui.Name)

        for _, d in ipairs(gui:GetDescendants()) do
            if not d.Visible then continue end

            if d:IsA("TextButton") then
                log("  [TextButton] " .. d.Name
                    .. " | Text: '" .. d.Text .. "'"
                    .. " | Path: " .. d:GetFullName())
            elseif d:IsA("ImageButton") then
                log("  [ImageButton] " .. d.Name
                    .. " | Path: " .. d:GetFullName())
            elseif d:IsA("TextLabel") and d.Text ~= "" then
                log("  [TextLabel] " .. d.Name
                    .. " | Text: '" .. d.Text:sub(1, 100) .. "'")
            end
        end
    end
end

-- Legacy Dialog
log("")
log("=== LEGACY DIALOGS ===")
local anyLegacy = false
for _, d in ipairs(workspace:GetDescendants()) do
    if d:IsA("Dialog") and d.Enabled then
        anyLegacy = true
        log("Dialog: " .. d:GetFullName())
        for _, c in ipairs(d:GetChildren()) do
            if c:IsA("DialogChoice") then
                log("  Choice: '" .. c.Name .. "'"
                    .. " | UserDialog: '" .. tostring(c.UserDialog) .. "'"
                    .. " | ResponseDialog: '" .. tostring(c.ResponseDialog) .. "'")
            end
        end
    end
end
if not anyLegacy then log("  (none)") end

log("")
log("=== END ===")

-- Auto-copy
local fullText = table.concat(lines, "\n")
local copied = false
if typeof(setclipboard) == "function" then
    copied = pcall(function() setclipboard(fullText) end)
end

print("")
if copied then
    print("[COPY] ✅ Dialog structure di-copy ke clipboard. Ctrl+V di chat.")
else
    print("[COPY] ⚠️ setclipboard nggak support, copy manual dari console di atas.")
end
