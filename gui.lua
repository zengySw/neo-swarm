-- gui.lua (Interface and controls)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui in CoreGui for exploit environment
local gui = Instance.new("ScreenGui")
gui.Name = "NeoSwarmGUI"
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(gui)
    end
    gui.Parent = gethui and gethui() or game:GetService("CoreGui")
end)
-- Fallback to PlayerGui if CoreGui parenting fails
if not gui.Parent then
    gui.Parent = PlayerGui
end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(260, 190)
frame.Position = UDim2.new(0.05, 0, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame)  -- Rounded corners for the main frame

-- Title
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.fromOffset(10, 5)
title.Text = "Neo Swarm | Speed"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold

-- Close button
local close = Instance.new("TextButton", frame)
close.Size = UDim2.fromOffset(26, 26)
close.Position = UDim2.new(1, -32, 0, 6)
close.Text = "✕"
close.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
close.TextColor3 = Color3.fromRGB(255, 200, 200)
Instance.new("UICorner", close)
close.MouseButton1Click:Connect(function()
    if typeof(_G.ResetAll) == "function" then
        _G.ResetAll()  -- stop all processes and reset values
    end
    gui:Destroy()
end)

-- Field selection dropdown
local fieldNames = {}
if typeof(_G.GetFields) == "function" then
    fieldNames = _G.GetFields()
end
local currentFieldName = fieldNames[1] or "Pine Tree Forest"

local fieldButton = Instance.new("TextButton", frame)
fieldButton.Position = UDim2.fromOffset(10, 40)
fieldButton.Size = UDim2.new(1, -20, 0, 30)
fieldButton.Text = "Field: " .. currentFieldName
fieldButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
fieldButton.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", fieldButton)

local listFrame = Instance.new("Frame", frame)
listFrame.Position = UDim2.fromOffset(10, 72)
listFrame.Size = UDim2.new(1, -20, 0, #fieldNames * 30)
listFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
listFrame.BorderSizePixel = 0
listFrame.Visible = false
-- Put the list frame on top of other UI elements
fieldButton.ZIndex = 2
listFrame.ZIndex = 3

for i, fname in ipairs(fieldNames) do
    local option = Instance.new("TextButton", listFrame)
    option.Size = UDim2.new(1, 0, 0, 30)
    option.Position = UDim2.fromOffset(0, (i-1) * 30)
    option.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    option.TextColor3 = Color3.new(1, 1, 1)
    option.Text = fname
    option.ZIndex = 3
    Instance.new("UICorner", option)
    option.MouseEnter:Connect(function()
        option.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    end)
    option.MouseLeave:Connect(function()
        option.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    end)
    option.MouseButton1Click:Connect(function()
        -- Update selected field display
        fieldButton.Text = "Field: " .. fname
        listFrame.Visible = false
        -- Trigger field change in main logic
        if typeof(_G.SetField) == "function" then
            _G.SetField(fname)
        end
    end)
end

fieldButton.MouseButton1Click:Connect(function()
    -- Toggle dropdown visibility
    listFrame.Visible = not listFrame.Visible
end)

-- Speed display label
local speedLabel = Instance.new("TextLabel", frame)
speedLabel.Position = UDim2.fromOffset(10, 75)
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedLabel.Text = "Speed: 0"
speedLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Initialize speed label with current speed
local function round1(x)
    return math.floor(x * 10) / 10
end
if typeof(_G.GetSpeed) == "function" then
    local currentSpeed = _G.GetSpeed()
    speedLabel.Text = "Speed: " .. tostring(round1(currentSpeed))
else
    speedLabel.Text = "Speed: N/A"
end

-- Speed slider UI
local sliderContainer = Instance.new("Frame", frame)
sliderContainer.Position = UDim2.fromOffset(10, 105)
sliderContainer.Size = UDim2.new(1, -20, 0, 30)
sliderContainer.BackgroundTransparency = 1

local sliderBar = Instance.new("Frame", sliderContainer)
sliderBar.Size = UDim2.fromOffset(200, 4)
sliderBar.Position = UDim2.new(0, 0, 0.5, -2)  -- center vertically in the container
sliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
Instance.new("UICorner", sliderBar)

local knob = Instance.new("TextButton", sliderContainer)
knob.Size = UDim2.fromOffset(10, 10)
knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knob.Text = ""
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
-- Set initial knob position based on current speed value
local minSpeed, maxSpeed = 0, 100
local startSpeed = (typeof(_G.GetSpeed) == "function") and _G.GetSpeed() or 16
startSpeed = math.clamp(startSpeed, minSpeed, maxSpeed)
local trackWidth = sliderBar.Size.X.Offset - knob.Size.X.Offset
local initX = 0
if maxSpeed > minSpeed then
    initX = trackWidth * ((startSpeed - minSpeed) / (maxSpeed - minSpeed))
end
knob.Position = UDim2.fromOffset(initX, (30 - knob.Size.Y.Offset) / 2)

-- Dragging functionality for the slider knob
local dragging = false
knob.MouseButton1Down:Connect(function()
    dragging = true
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mousePos = UserInputService:GetMouseLocation()
        local barPos = sliderBar.AbsolutePosition
        local barSize = sliderBar.AbsoluteSize
        -- Calculate knob position relative to slider bar, clamped within [0, trackWidth]
        local relX = math.clamp(mousePos.X - barPos.X - knob.Size.X.Offset/2, 0, barSize.X - knob.Size.X.Offset)
        knob.Position = UDim2.fromOffset(relX, knob.Position.Y.Offset)
        -- Calculate new speed value from knob position
        local newSpeed = minSpeed
        if barSize.X > knob.Size.X.Offset then
            newSpeed = minSpeed + (relX / (barSize.X - knob.Size.X.Offset)) * (maxSpeed - minSpeed)
        end
        -- Apply the new speed
        if typeof(_G.SetSpeed) == "function" then
            _G.SetSpeed(newSpeed)
        end
        speedLabel.Text = "Speed: " .. tostring(round1(newSpeed))
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Farm control buttons
local onBtn = Instance.new("TextButton", frame)
onBtn.Position = UDim2.fromOffset(10, 145)
onBtn.Size = UDim2.fromOffset(110, 30)
onBtn.Text = "START FARM"
onBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
onBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", onBtn)

local offBtn = Instance.new("TextButton", frame)
offBtn.Position = UDim2.fromOffset(130, 145)
offBtn.Size = UDim2.fromOffset(110, 30)
offBtn.Text = "STOP FARM"
offBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
offBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", offBtn)

onBtn.MouseButton1Click:Connect(function()
    if typeof(_G.StartFarm) == "function" then
        _G.StartFarm()
    end
end)
offBtn.MouseButton1Click:Connect(function()
    if typeof(_G.StopFarm) == "function" then
        _G.StopFarm()
    end
end)
