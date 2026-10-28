--[[
=========================================================
  TEN HUB Shared: GUI Utility
  Author: Kyriel
  Theme: Cyberpunk Purple
=========================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

_G.TenHub = _G.TenHub or {}

local GuiUtil = {}

-- ============================================================
-- PALETTE
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
local function new(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do
        obj[k] = v
    end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function textGlow(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.5
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    s.Parent = obj
    return s
end

local function gradient(obj, seq, rot)
    local g = Instance.new("UIGradient")
    g.Color = seq
    g.Rotation = rot or 0
    g.Parent = obj
    return g
end

-- ============================================================
-- ANIMATION HELPERS
-- ============================================================
function GuiUtil.tween(obj, props, duration, style, dir)
    local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

function GuiUtil.pulse(strokeObj, minT, maxT, duration)
    strokeObj.Transparency = minT
    local info = TweenInfo.new(duration or 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local t = TweenService:Create(strokeObj, info, {Transparency = maxT})
    t:Play()
    return t
end

-- ============================================================
-- DRAGGABLE
-- ============================================================
function GuiUtil.makeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local startPos, startFrame
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startFrame = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            frame.Position = UDim2.new(
                startFrame.X.Scale, startFrame.X.Offset + delta.X,
                startFrame.Y.Scale, startFrame.Y.Offset + delta.Y
            )
        end
    end)
end

-- ============================================================
-- SCREENGUI INIT
-- ============================================================
GuiUtil.screenGui = nil

function GuiUtil.init()
    if GuiUtil.screenGui and GuiUtil.screenGui.Parent then
        return GuiUtil.screenGui
    end
    local old = playerGui:FindFirstChild("TenHub")
    if old then old:Destroy() end
    
    local sg = new("ScreenGui", {
        Name = "TenHub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    }, playerGui)
    GuiUtil.screenGui = sg
    return sg
end

-- ============================================================
-- LOGO 10 HUB
-- ============================================================
function GuiUtil.createLogo(parent, width, height)
    width = width or 42
    height = height or 42
    
    local container = new("Frame", {
        Size = UDim2.new(0, width, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, parent)
    
    -- Background box
    local box = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
    }, container)
    corner(box, 8)
    local boxStroke = stroke(box, P.NEON, 2, 0.1)
    GuiUtil.pulse(boxStroke, 0.1, 0.6, 1.5)
    
    -- Gradient overlay
    local grad = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = P.NEON,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
    }, box)
    corner(grad, 8)
    gradient(grad, ColorSequence.new(P.DEEP, P.DARKPURPLE), 45)
    
    -- "10" text
    local ten = new("TextLabel", {
        Size = UDim2.new(1, 0, 0.62, 0),
        Position = UDim2.new(0, 0, 0.02, 0),
        BackgroundTransparency = 1,
        Text = "10",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(height * 0.44),
        ZIndex = 2,
    }, box)
    textGlow(ten, P.NEON, 1, 0.35)
    
    -- "HUB" text
    local hub = new("TextLabel", {
        Size = UDim2.new(1, 0, 0.32, 0),
        Position = UDim2.new(0, 0, 0.62, 0),
        BackgroundTransparency = 1,
        Text = "H U B",
        TextColor3 = P.NEON,
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(height * 0.16),
        ZIndex = 2,
    }, box)
    textGlow(hub, P.DEEP, 1, 0.2)
    
    return container
end

-- ============================================================
-- WINDOW
-- ============================================================
function GuiUtil.CreateWindow(opts)
    opts = opts or {}
    local sg = GuiUtil.init()
    
    local width = opts.Width or 420
    local height = opts.Height or 340
    
    -- Main frame
    local main = new("Frame", {
        Name = "TenHubWindow",
        Size = UDim2.new(0, width, 0, height),
        Position = opts.Position or UDim2.new(0.5, -width/2, 0.5, -height/2),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, sg)
    corner(main, 12)
    local mainStroke = stroke(main, P.NEON, 2, 0.1)
    GuiUtil.pulse(mainStroke, 0.05, 0.55, 1.6)
    
    -- Scanlines
    local scanContainer = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, main)
    for y = 15, height, 15 do
        new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, y),
            BackgroundColor3 = P.NEON,
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
        }, scanContainer)
    end
    
    local sweep = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 55),
        BackgroundColor3 = P.NEON,
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, scanContainer)
    gradient(sweep, ColorSequence.new(P.DARKPURPLE, P.NEON), 0)
    TweenService:Create(
        sweep,
        TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false),
        {Position = UDim2.new(0, 0, 1, 0)}
    ):Play()
    
    -- Title bar
    local title = new("Frame", {
        Size = UDim2.new(1, 0, 0, 55),
        BackgroundColor3 = P.DEEP,
        BorderSizePixel = 0,
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
    
    -- Logo in title
    local logo = GuiUtil.createLogo(title, 42, 42)
    logo.Position = UDim2.new(0, 8, 0, 6)
    
    -- Title shadow
    new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 22),
        Position = UDim2.new(0, 62, 0, 8),
        BackgroundTransparency = 1,
        Text = opts.Title or "TEN HUB",
        TextColor3 = P.NEON,
        TextTransparency = 0.5,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    }, title)
    
    -- Title text
    local titleLabel = new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 22),
        Position = UDim2.new(0, 61, 0, 7),
        BackgroundTransparency = 1,
        Text = opts.Title or "TEN HUB",
        TextColor3 = P.WHITE,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    }, title)
    textGlow(titleLabel, P.NEON, 1, 0.5)
    
    -- Subtitle
    new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 14),
        Position = UDim2.new(0, 62, 0, 30),
        BackgroundTransparency = 1,
        Text = opts.Subtitle or "T E N   H U B",
        TextColor3 = P.ACCENT,
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
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
    }, title)
    corner(close, 6)
    local closeStroke = stroke(close, P.NEON, 1, 0.3)
    GuiUtil.pulse(closeStroke, 0.2, 0.7, 1.2)
    
    close.MouseEnter:Connect(function()
        GuiUtil.tween(close, {BackgroundColor3 = Color3.fromRGB(220, 50, 100)}, 0.15)
    end)
    close.MouseLeave:Connect(function()
        GuiUtil.tween(close, {BackgroundColor3 = P.NEON}, 0.15)
    end)
    
    close.MouseButton1Click:Connect(function()
        GuiUtil.tween(main, {Size = UDim2.new(0, width, 0, 0)}, 0.25)
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
    }, title)
    corner(min, 6)
    stroke(min, P.DARKPURPLE, 1, 0.3)
    
    local expanded = true
    min.MouseButton1Click:Connect(function()
        if expanded then
            GuiUtil.tween(main, {Size = UDim2.new(0, width, 0, 55)}, 0.25)
            min.Text = "o"
        else
            GuiUtil.tween(main, {Size = UDim2.new(0, width, 0, height)}, 0.25)
            min.Text = "_"
        end
        expanded = not expanded
    end)
    
    GuiUtil.makeDraggable(main, title)
    
    -- Accent line
    local accent = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 55),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
    }, main)
    local accentStroke = Instance.new("UIStroke")
    accentStroke.Color = P.NEON
    accentStroke.Thickness = 2
    accentStroke.Transparency = 0.3
    accentStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    accentStroke.Parent = accent
    GuiUtil.pulse(accentStroke, 0.15, 0.8, 1.3)
    
    -- Body
    local body = new("ScrollingFrame", {
        Name = "Body",
        Size = UDim2.new(1, -16, 1, -73),
        Position = UDim2.new(0, 8, 0, 63),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = P.NEON,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, main)
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
    }, body)
    
    -- ========================================================
    -- WINDOW OBJECT
    -- ========================================================
    local win = {
        Instance = main,
        Body = body,
        Title = title,
        Palette = P,
        _order = 0,
    }
    
    function win:AddSection(text)
        win._order = win._order + 1
        local frame = new("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = win._order,
        }, body)
        
        local lbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = P.NEON,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, frame)
        textGlow(lbl, P.NEON, 1, 0.5)
        
        local line = new("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0, 22),
            BackgroundColor3 = P.NEON,
            BorderSizePixel = 0,
        }, frame)
        gradient(line, ColorSequence.new(P.NEON, P.DEEP), 0)
        
        return frame
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
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = P.DARKPURPLE,
            Text = text,
            TextColor3 = P.WHITE,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = win._order,
        }, body)
        corner(btn, 6)
        stroke(btn, P.NEON, 1, 0.4)
        
        btn.MouseEnter:Connect(function()
            GuiUtil.tween(btn, {BackgroundColor3 = P.NEON}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            GuiUtil.tween(btn, {BackgroundColor3 = P.DARKPURPLE}, 0.15)
        end)
        btn.MouseButton1Click:Connect(function()
            GuiUtil.tween(btn, {Size = UDim2.new(1, -4, 0, 32)}, 0.08)
            task.wait(0.1)
            GuiUtil.tween(btn, {Size = UDim2.new(1, 0, 0, 36)}, 0.08)
            if callback then pcall(callback) end
        end)
        return btn
    end
    
    function win:AddToggle(text, default, callback)
        win._order = win._order + 1
        local frame = new("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = P.PANEL,
            BorderSizePixel = 0,
            LayoutOrder = win._order,
        }, body)
        corner(frame, 6)
        stroke(frame, P.DARKPURPLE, 1, 0.5)
        
        new("TextLabel", {
            Size = UDim2.new(1, -70, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = P.TEXT,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, frame)
        
        local toggleBg = new("Frame", {
            Size = UDim2.new(0, 40, 0, 20),
            Position = UDim2.new(1, -52, 0.5, -10),
            BackgroundColor3 = Color3.fromRGB(50, 30, 70),
            BorderSizePixel = 0,
        }, frame)
        corner(toggleBg, 10)
        stroke(toggleBg, P.DARKPURPLE, 1, 0.3)
        
        local knob = new("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = P.GRAY,
            BorderSizePixel = 0,
        }, toggleBg)
        corner(knob, 8)
        
        local state = default or false
        local function update()
            if state then
                GuiUtil.tween(toggleBg, {BackgroundColor3 = P.NEON}, 0.2)
                GuiUtil.tween(knob, {Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = P.WHITE}, 0.2)
            else
                GuiUtil.tween(toggleBg, {BackgroundColor3 = Color3.fromRGB(50, 30, 70)}, 0.2)
                GuiUtil.tween(knob, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = P.GRAY}, 0.2)
            end
        end
        
        local clickArea = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, frame)
        clickArea.MouseButton1Click:Connect(function()
            state = not state
            update()
            if callback then pcall(callback, state) end
        end)
        
        update()
        return frame
    end
    
    function win:AddTextBox(placeholder, callback)
        win._order = win._order + 1
        local box = new("TextBox", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = P.PANEL,
            Text = "",
            PlaceholderText = placeholder or "Type here...",
            PlaceholderColor3 = P.GRAY,
            TextColor3 = P.TEXT,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            LayoutOrder = win._order,
        }, body)
        corner(box, 6)
        stroke(box, P.DARKPURPLE, 1, 0.4)
        
        box.Focused:Connect(function()
            GuiUtil.tween(box, {Size = UDim2.new(1, 0, 0, 36)}, 0.15)
        end)
        box.FocusLost:Connect(function(enter)
            GuiUtil.tween(box, {Size = UDim2.new(1, 0, 0, 34)}, 0.15)
            if enter and callback then pcall(callback, box.Text) end
        end)
        return box
    end
    
    return win
end

-- ============================================================
-- NOTIFICATION
-- ============================================================
function GuiUtil.Notify(title, text, duration)
    local sg = GuiUtil.init()
    duration = duration or 3
    
    local frame = new("Frame", {
        Size = UDim2.new(0, 280, 0, 60),
        Position = UDim2.new(1, 0, 1, -80),
        BackgroundColor3 = P.BG,
        BorderSizePixel = 0,
        ZIndex = 200,
    }, sg)
    corner(frame, 8)
    local s = stroke(frame, P.NEON, 2, 0.1)
    GuiUtil.pulse(s, 0.1, 0.6, 1.2)
    
    local strip = new("Frame", {
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = P.NEON,
        BorderSizePixel = 0,
        ZIndex = 201,
    }, frame)
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
    }, frame)
    
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
    }, frame)
    
    GuiUtil.tween(frame, {Position = UDim2.new(1, -300, 1, -80)}, 0.3)
    
    task.delay(duration, function()
        GuiUtil.tween(frame, {Position = UDim2.new(1, 0, 1, -80)}, 0.3)
        task.wait(0.35)
        if frame and frame.Parent then frame:Destroy() end
    end)
end

_G.TenHub.GuiUtil = GuiUtil
return GuiUtil
