_G.TenHub = _G.TenHub or {}

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui")

local GuiUtil = {}

GuiUtil.Palette = {
    NEON    = Color3.fromRGB(255, 40, 80),
    ACCENT  = Color3.fromRGB(255, 100, 130),
    BG      = Color3.fromRGB(15, 5, 10),
    PANEL   = Color3.fromRGB(30, 12, 20),
    TEXT    = Color3.fromRGB(230, 220, 225),
    GRAY    = Color3.fromRGB(150, 140, 150),
    WHITE   = Color3.fromRGB(255, 255, 255),
    SUCCESS = Color3.fromRGB(100, 255, 150),
    WARN    = Color3.fromRGB(255, 200, 80),
    ERROR   = Color3.fromRGB(255, 80, 100),
    DARKPURPLE = Color3.fromRGB(180, 30, 60),
}
local P = GuiUtil.Palette

local function new(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r); c.Parent = o; return c
end

local function stroke(o, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thick or 1; s.Transparency = trans or 0
    s.Parent = o; return s
end

-- Draggable
local function draggable(frame, handle)
    handle = handle or frame
    local drag, startPos, startFrame
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            startPos = input.Position
            startFrame = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startPos
            frame.Position = UDim2.new(startFrame.X.Scale, startFrame.X.Offset + d.X, startFrame.Y.Scale, startFrame.Y.Offset + d.Y)
        end
    end)
end

GuiUtil.screenGui = nil

function GuiUtil.init()
    if GuiUtil.screenGui and GuiUtil.screenGui.Parent then return GuiUtil.screenGui end
    local old = pgui:FindFirstChild("TenHub")
    if old then old:Destroy() end
    local sg = new("ScreenGui", {
        Name = "TenHub",
        ResetOnSpawn = false,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, pgui)
    GuiUtil.screenGui = sg
    return sg
end

function GuiUtil.CreateWindow(opts)
    opts = opts or {}
    local sg = GuiUtil.init()
    local w = opts.Width or 400
    local h = opts.Height or 300

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, w, 0, h),
        Position = UDim2.new(0.5, -w/2, 0.5, -h/2),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, sg)
    corner(main, 12)
    stroke(main, P.NEON, 2, 0.1)

    -- Title bar
    local title = new("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = P.PANEL,
        BorderSizePixel = 0,
    }, main)
    corner(title, 12)

    new("TextLabel", {
        Size = UDim2.new(1, -80, 0, 22),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = opts.Title or "TEN HUB",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, title)

    new("TextLabel", {
        Size = UDim2.new(1, -80, 0, 14),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = opts.Subtitle or "v1.0",
        TextColor3 = P.ACCENT,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, title)

    -- Close
    local close = new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -34, 0, 12),
        BackgroundColor3 = P.NEON,
        Text = "X",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, title)
    corner(close, 6)
    close.MouseButton1Click:Connect(function() main:Destroy() end)

    -- Accent line
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
    }, main)

    -- Body
    local body = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -66),
        Position = UDim2.new(0, 8, 0, 58),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = P.NEON,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, main)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, body)

    draggable(main, title)

    local win = { Instance = main, Body = body, Palette = P, _order = 0 }

    function win:AddSection(text)
        win._order = win._order + 1
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = win._order,
        }, body)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = P.NEON,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 22),
            BackgroundColor3 = P.NEON,
            BorderSizePixel = 0,
        }, f)
        return f
    end

    function win:AddLabel(text, color)
        win._order = win._order + 1
        return new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = "  " .. text,
            TextColor3 = color or P.TEXT,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = win._order,
        }, body)
    end

    function win:AddButton(text, callback)
        win._order = win._order + 1
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = P.DARKPURPLE,
            Text = text,
            TextColor3 = P.WHITE,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = win._order,
        }, body)
        corner(b, 6)
        stroke(b, P.NEON, 1, 0.4)
        b.MouseButton1Click:Connect(function()
            if callback then pcall(callback) end
        end)
        return b
    end

    function win:AddToggle(text, default, callback)
        win._order = win._order + 1
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = P.PANEL,
            BorderSizePixel = 0,
            LayoutOrder = win._order,
        }, body)
        corner(f, 6)
        stroke(f, P.DARKPURPLE, 1, 0.5)

        new("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = P.TEXT,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)

        local bg = new("Frame", {
            Size = UDim2.new(0, 40, 0, 20),
            Position = UDim2.new(1, -52, 0.5, -10),
            BackgroundColor3 = default and P.NEON or Color3.fromRGB(50, 30, 40),
            BorderSizePixel = 0,
        }, f)
        corner(bg, 10)

        local knob = new("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = P.WHITE,
            BorderSizePixel = 0,
        }, bg)
        corner(knob, 8)

        local state = default or false
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, f)
        btn.MouseButton1Click:Connect(function()
            state = not state
            bg.BackgroundColor3 = state and P.NEON or Color3.fromRGB(50, 30, 40)
            knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            if callback then pcall(callback, state) end
        end)
        return f
    end

    return win
end

function GuiUtil.Notify(title, text, duration)
    local sg = GuiUtil.init()
    duration = duration or 3
    local f = new("Frame", {
        Size = UDim2.new(0, 280, 0, 60),
        Position = UDim2.new(1, 0, 1, -80),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
        ZIndex = 200,
    }, sg)
    corner(f, 8)
    stroke(f, P.NEON, 2, 0.1)

    new("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
        ZIndex = 201,
    }, f)

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 14, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = P.NEON,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    }, f)

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 26),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = P.TEXT,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 201,
    }, f)

    Tween:Create(f, TweenInfo.new(0.3), {Position = UDim2.new(1, -300, 1, -80)}):Play()
    task.delay(duration, function()
        Tween:Create(f, TweenInfo.new(0.3), {Position = UDim2.new(1, 0, 1, -80)}):Play()
        task.wait(0.35)
        if f.Parent then f:Destroy() end
    end)
end

_G.TenHub.GuiUtil = GuiUtil
return GuiUtil
