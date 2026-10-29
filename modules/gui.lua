_G.TenHub = _G.TenHub or {}

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local player  = Players.LocalPlayer
local pgui    = player:WaitForChild("PlayerGui")

local GuiUtil = {}

-- ============================================================
-- PALETTE (original purple neon cyber)
-- ============================================================
GuiUtil.Palette = {
    NEON       = Color3.fromRGB(180, 30, 255),
    ACCENT     = Color3.fromRGB(200, 100, 255),
    DARKPURPLE = Color3.fromRGB(120, 20, 180),
    DEEP       = Color3.fromRGB(60, 20, 90),
    BG         = Color3.fromRGB(10, 5, 15),
    PANEL      = Color3.fromRGB(20, 12, 32),
    TEXT       = Color3.fromRGB(220, 210, 230),
    GRAY       = Color3.fromRGB(150, 140, 170),
    WHITE      = Color3.fromRGB(240, 240, 245),
    SUCCESS    = Color3.fromRGB(100, 255, 150),
    WARN       = Color3.fromRGB(255, 200, 80),
    ERROR      = Color3.fromRGB(255, 80, 100),
}
local P = GuiUtil.Palette

-- ============================================================
-- LOW-LEVEL HELPERS
-- ============================================================
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
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = o; return s
end

local function textGlow(o, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thick or 1; s.Transparency = trans or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    s.Parent = o; return s
end

local function gradient(o, seq, rot)
    local g = Instance.new("UIGradient")
    g.Color = seq; g.Rotation = rot or 0; g.Parent = o; return g
end

local function tween(o, props, dur)
    local t = Tween:Create(o, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play(); return t
end

local function pulse(s, minT, maxT, dur)
    s.Transparency = minT
    local t = Tween:Create(s, TweenInfo.new(dur or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = maxT})
    t:Play(); return t
end

-- ============================================================
-- DRAGGABLE
-- ============================================================
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

-- ============================================================
-- LOGO "10 HUB"
-- ============================================================
local function createLogo(parent, w, h)
    w = w or 42; h = h or 42
    local container = new("Frame", {
        Size = UDim2.new(0, w, 0, h),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, parent)

    local box = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
    }, container)
    corner(box, 8)
    local boxStroke = stroke(box, P.NEON, 2, 0.1)
    pulse(boxStroke, 0.1, 0.6, 1.5)

    local grad = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = P.NEON,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
    }, box)
    corner(grad, 8)
    gradient(grad, ColorSequence.new(P.DEEP, P.DARKPURPLE), 45)

    local ten = new("TextLabel", {
        Size = UDim2.new(1, 0, 0.62, 0),
        Position = UDim2.new(0, 0, 0.02, 0),
        BackgroundTransparency = 1,
        Text = "10",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(h * 0.44),
        ZIndex = 2,
    }, box)
    textGlow(ten, P.NEON, 1, 0.35)

    local hub = new("TextLabel", {
        Size = UDim2.new(1, 0, 0.32, 0),
        Position = UDim2.new(0, 0, 0.62, 0),
        BackgroundTransparency = 1,
        Text = "H U B",
        TextColor3 = P.NEON,
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(h * 0.16),
        ZIndex = 2,
    }, box)
    textGlow(hub, P.DEEP, 1, 0.2)

    return container
end

-- ============================================================
-- INIT
-- ============================================================
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

-- ============================================================
-- CREATE WINDOW
-- ============================================================
function GuiUtil.CreateWindow(opts)
    opts = opts or {}
    local sg = GuiUtil.init()
    local w = opts.Width or 420
    local h = opts.Height or 380

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, w, 0, h),
        Position = UDim2.new(0.5, -w/2, 0.5, -h/2),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, sg)
    corner(main, 12)
    local mainStroke = stroke(main, P.NEON, 2, 0.1)
    pulse(mainStroke, 0.05, 0.55, 1.6)

    -- Scanlines
    local scan = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, main)
    for y = 15, h, 15 do
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, y),
            BackgroundColor3 = P.NEON,
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
        }, scan)
    end

    -- Sweep animation
    local sweep = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 55),
        BackgroundColor3 = P.NEON,
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, scan)
    gradient(sweep, ColorSequence.new(P.DARKPURPLE, P.NEON), 0)
    Tween:Create(sweep, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false), {
        Position = UDim2.new(0, 0, 1, 0)
    }):Play()

    -- Title bar
    local title = new("Frame", {
        Size = UDim2.new(1, 0, 0, 55),
        BackgroundColor3 = P.DEEP,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, main)
    corner(title, 12)
    gradient(title, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 10, 70)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 30, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 10, 70)),
    }), 0)

    local fill = new("Frame", {
        Size = UDim2.new(1, 0, 0, 15),
        Position = UDim2.new(0, 0, 1, -15),
        BackgroundColor3 = Color3.fromRGB(45, 10, 70),
        BorderSizePixel = 0,
    }, title)
    gradient(fill, ColorSequence.new(Color3.fromRGB(45, 10, 70), Color3.fromRGB(120, 30, 180)), 0)

    -- Logo
    local logo = createLogo(title, 42, 42)
    logo.Position = UDim2.new(0, 8, 0, 6)
    logo.ZIndex = 6

    -- Title text (shadow)
    new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 22),
        Position = UDim2.new(0, 62, 0, 8),
        BackgroundTransparency = 1,
        Text = opts.Title or "TEN HUB",
        TextColor3 = P.NEON,
        TextTransparency = 0.5,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    }, title)

    -- Title text (main)
    local titleLabel = new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 22),
        Position = UDim2.new(0, 61, 0, 7),
        BackgroundTransparency = 1,
        Text = opts.Title or "TEN HUB",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    }, title)
    textGlow(titleLabel, P.NEON, 1, 0.5)

    -- Subtitle
    new("TextLabel", {
        Size = UDim2.new(1, -140, 0, 14),
        Position = UDim2.new(0, 62, 0, 30),
        BackgroundTransparency = 1,
        Text = opts.Subtitle or "T E N   H U B",
        TextColor3 = P.ACCENT,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    }, title)

    -- Close button
    local close = new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -34, 0, 8),
        BackgroundColor3 = P.NEON,
        Text = "X",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 7,
    }, title)
    corner(close, 6)
    local closeStroke = stroke(close, P.NEON, 1, 0.3)
    pulse(closeStroke, 0.2, 0.7, 1.2)

    close.MouseEnter:Connect(function() tween(close, {BackgroundColor3 = Color3.fromRGB(220, 50, 100)}, 0.15) end)
    close.MouseLeave:Connect(function() tween(close, {BackgroundColor3 = P.NEON}, 0.15) end)
    close.MouseButton1Click:Connect(function()
        tween(main, {Size = UDim2.new(0, w, 0, 0)}, 0.25)
        task.wait(0.3)
        main:Destroy()
    end)

    -- Minimize button
    local min = new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -64, 0, 8),
        BackgroundColor3 = Color3.fromRGB(60, 30, 90),
        Text = "_",
        TextColor3 = P.TEXT,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 7,
    }, title)
    corner(min, 6)
    stroke(min, P.DARKPURPLE, 1, 0.3)

    local expanded = true
    min.MouseButton1Click:Connect(function()
        if expanded then
            tween(main, {Size = UDim2.new(0, w, 0, 55)}, 0.25)
            min.Text = "o"
        else
            tween(main, {Size = UDim2.new(0, w, 0, h)}, 0.25)
            min.Text = "_"
        end
        expanded = not expanded
    end)

    draggable(main, title)

    -- Accent line
    local accent = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 55),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, main)
    local accentStroke = stroke(accent, P.NEON, 2, 0.3)
    pulse(accentStroke, 0.15, 0.8, 1.3)

    -- Body
    local body = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -73),
        Position = UDim2.new(0, 8, 0, 63),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = P.NEON,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    }, main)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, body)

    local win = { Instance = main, Body = body, Title = title, Palette = P, _order = 0 }

    function win:AddSection(text)
        win._order = win._order + 1
        local f = new("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = win._order,
            ZIndex = 3,
        }, body)

        local lbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = P.NEON,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
        }, f)
        textGlow(lbl, P.NEON, 1, 0.5)

        local line = new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 22),
            BackgroundColor3 = P.NEON,
            BorderSizePixel = 0,
            ZIndex = 3,
        }, f)
        gradient(line, ColorSequence.new(P.NEON, P.DEEP), 0)

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
            ZIndex = 3,
        }, body)
    end

    function win:AddButton(text, callback)
        win._order = win._order + 1
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = P.DARKPURPLE,
            Text = text,
            TextColor3 = P.WHITE,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = win._order,
            ZIndex = 3,
        }, body)
        corner(b, 6)
        stroke(b, P.NEON, 1, 0.4)

        b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = P.NEON}, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = P.DARKPURPLE}, 0.15) end)
        b.MouseButton1Click:Connect(function()
            tween(b, {Size = UDim2.new(1, -4, 0, 32)}, 0.08)
            task.wait(0.1)
            tween(b, {Size = UDim2.new(1, 0, 0, 36)}, 0.08)
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
            ZIndex = 3,
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
            ZIndex = 3,
        }, f)

        local bg = new("Frame", {
            Size = UDim2.new(0, 40, 0, 20),
            Position = UDim2.new(1, -52, 0.5, -10),
            BackgroundColor3 = default and P.NEON or Color3.fromRGB(50, 30, 70),
            BorderSizePixel = 0,
            ZIndex = 3,
        }, f)
        corner(bg, 10)
        stroke(bg, P.DARKPURPLE, 1, 0.3)

        local knob = new("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = default and P.WHITE or P.GRAY,
            BorderSizePixel = 0,
            ZIndex = 3,
        }, bg)
        corner(knob, 8)

        local state = default or false
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 4,
        }, f)

        local function update()
            if state then
                tween(bg, {BackgroundColor3 = P.NEON}, 0.2)
                tween(knob, {Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = P.WHITE}, 0.2)
            else
                tween(bg, {BackgroundColor3 = Color3.fromRGB(50, 30, 70)}, 0.2)
                tween(knob, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = P.GRAY}, 0.2)
            end
        end

        btn.MouseButton1Click:Connect(function()
            state = not state
            update()
            if callback then pcall(callback, state) end
        end)
        return f
    end

    return win
end

-- ============================================================
-- NOTIFY
-- ============================================================
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
    local s = stroke(f, P.NEON, 2, 0.1)
    pulse(s, 0.1, 0.6, 1.2)

    local strip = new("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
        ZIndex = 201,
    }, f)
    gradient(strip, ColorSequence.new(P.NEON, P.DARKPURPLE), 90)

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

    tween(f, {Position = UDim2.new(1, -300, 1, -80)}, 0.3)
    task.delay(duration, function()
        tween(f, {Position = UDim2.new(1, 0, 1, -80)}, 0.3)
        task.wait(0.35)
        if f.Parent then f:Destroy() end
    end)
end

_G.TenHub.GuiUtil = GuiUtil
return GuiUtil
