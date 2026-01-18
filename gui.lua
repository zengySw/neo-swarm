-- gui.lua (FIXED, self-contained)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")

-- Подключение к твоему фарму:
-- В основном скрипте задай:
-- _G.StartFarm = startFarm
-- _G.StopFarm  = stopFarm
local StartFarm = _G.StartFarm or function() warn("[GUI] _G.StartFarm not set") end
local StopFarm  = _G.StopFarm  or function() warn("[GUI] _G.StopFarm not set") end

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm_C_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 105)
frame.Position = UDim2.new(0.05, 0, 0.55, 0)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Transparency = 0.25
stroke.Color = Color3.fromRGB(90, 90, 120)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(10, 8)
title.Size = UDim2.new(1, -20, 0, 18)
title.Text = "AutoFarm: go to C"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(245, 245, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(10, 28)
status.Size = UDim2.new(1, -20, 0, 16)
status.Text = "Status: OFF"
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextColor3 = Color3.fromRGB(170, 170, 190)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local btnOn = Instance.new("TextButton")
btnOn.Size = UDim2.new(0.48, 0, 0, 34)
btnOn.Position = UDim2.fromOffset(10, 55)
btnOn.Text = "ON"
btnOn.Font = Enum.Font.GothamBold
btnOn.TextSize = 16
btnOn.TextColor3 = Color3.fromRGB(255, 255, 255)
btnOn.BackgroundColor3 = Color3.fromRGB(60, 170, 80)
btnOn.Parent = frame
Instance.new("UICorner", btnOn).CornerRadius = UDim.new(0, 10)

local btnOff = Instance.new("TextButton")
btnOff.Size = UDim2.new(0.48, 0, 0, 34)
btnOff.Position = UDim2.fromOffset(124, 55)
btnOff.Text = "OFF"
btnOff.Font = Enum.Font.GothamBold
btnOff.TextSize = 16
btnOff.TextColor3 = Color3.fromRGB(255, 255, 255)
btnOff.BackgroundColor3 = Color3.fromRGB(170, 70, 70)
btnOff.Parent = frame
Instance.new("UICorner", btnOff).CornerRadius = UDim.new(0, 10)

-- крестик В ОКНЕ
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
closeBtn.Parent = frame
closeBtn.ZIndex = 10
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local function hardClose()
	pcall(function() StopFarm() end)
	gui:Destroy()
end

btnOn.MouseButton1Click:Connect(function()
	StartFarm()
	status.Text = "Status: ON"
	status.TextColor3 = Color3.fromRGB(140, 255, 140)
end)

btnOff.MouseButton1Click:Connect(function()
	StopFarm()
	status.Text = "Status: OFF"
	status.TextColor3 = Color3.fromRGB(170, 170, 190)
end)

closeBtn.MouseButton1Click:Connect(hardClose)

UserInputService.InputBegan:Connect(function(io, gp)
	if gp then return end
	if io.KeyCode == Enum.KeyCode.End then
		hardClose()
	end
end)

return true
