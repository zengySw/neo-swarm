-- gui.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "NeoSwarmGUI"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(260, 160)
frame.Position = UDim2.new(0.05, 0, 0.5, 0)
frame.BackgroundColor3 = Color3.fromRGB(25,25,30)
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame)

-- Title
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.fromOffset(10, 5)
title.Text = "Neo Swarm | Speed"
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold

-- Close
local close = Instance.new("TextButton", frame)
close.Size = UDim2.fromOffset(26,26)
close.Position = UDim2.new(1,-32,0,6)
close.Text = "✕"
close.BackgroundColor3 = Color3.fromRGB(60,40,40)
close.TextColor3 = Color3.fromRGB(255,200,200)
Instance.new("UICorner", close)

close.MouseButton1Click:Connect(function()
	if typeof(_G.ResetAll) == "function" then
		_G.ResetAll() -- всё откатили, как будто скрипта не было
	end
	gui:Destroy()
end)


local speedLabel = Instance.new("TextLabel", frame)
speedLabel.Position = UDim2.fromOffset(10, 40)
speedLabel.Size = UDim2.new(1,-20,0,20)

local function round1(x)
	return math.floor(x * 10) / 10
end

local speedText = "Speed: "

if typeof(_G.GetSpeed) == "function" then
	local value = _G.GetSpeed()
	speedText = "Speed: " .. tostring(round1(value))
else
	speedText = "Speed: error"
end

speedLabel.Text = speedText
speedLabel.BackgroundTransparency = 1
speedLabel.TextColor3 = Color3.fromRGB(200,200,200)


local box = Instance.new("TextBox", frame)
box.Position = UDim2.fromOffset(10, 70)
box.Size = UDim2.fromOffset(100,30)
box.Text = "16"
box.BackgroundColor3 = Color3.fromRGB(40,40,50)
box.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", box)

local apply = Instance.new("TextButton", frame)
apply.Position = UDim2.fromOffset(120, 70)
apply.Size = UDim2.fromOffset(120,30)
apply.Text = "Apply Speed"
apply.BackgroundColor3 = Color3.fromRGB(60,120,255)
apply.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", apply)

apply.MouseButton1Click:Connect(function()
	local v = tonumber(box.Text)
	if v then
		_G.SetSpeed(v)
		speedLabel.Text = "Speed: "..v
	end
end)



-- Farm Buttons
local onBtn = Instance.new("TextButton", frame)
onBtn.Position = UDim2.fromOffset(10, 115)
onBtn.Size = UDim2.fromOffset(110,30)
onBtn.Text = "START FARM"
onBtn.BackgroundColor3 = Color3.fromRGB(60,180,80)
onBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", onBtn)

local offBtn = Instance.new("TextButton", frame)
offBtn.Position = UDim2.fromOffset(130, 115)
offBtn.Size = UDim2.fromOffset(110,30)
offBtn.Text = "STOP FARM"
offBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
offBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", offBtn)


onBtn.MouseButton1Click:Connect(function()
	_G.StartFarm()
end)

offBtn.MouseButton1Click:Connect(function()
	_G.StopFarm()
end)
-- End of gui.lua