-- AutoFarm: walk to "C" in workspace.collectibles (ONE LocalScript)
-- Put into: StarterPlayerScripts (LocalScript)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ====== ZONE SETTINGS ======
local X1, X2 = -102.6, 39.3
local Z1, Z2 = 255, 184.0
local Y = 4.0

local Zone = {
	min = Vector3.new(math.min(X1, X2), Y, math.min(Z1, Z2)),
	max = Vector3.new(math.max(X1, X2), Y, math.max(Z1, Z2)),
}

local function isPointInZone(pos: Vector3)
	return pos.X >= Zone.min.X and pos.X <= Zone.max.X
		and pos.Z >= Zone.min.Z and pos.Z <= Zone.max.Z
end

local function getZoneCenter()
	return Vector3.new((Zone.min.X + Zone.max.X) / 2, Y, (Zone.min.Z + Zone.max.Z) / 2)
end

local function getRandomPointInZone()
	local x = math.random() * (Zone.max.X - Zone.min.X) + Zone.min.X
	local z = math.random() * (Zone.max.Z - Zone.min.Z) + Zone.min.Z
	return Vector3.new(x, Y, z)
end

-- ====== Character refs (safe on respawn) ======
local character, humanoid, root

local function refreshCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
end

refreshCharacter()
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	refreshCharacter()
end)

-- ====== Collectibles ======
local function getCollectiblesFolder()
	return workspace:FindFirstChild("collectibles")
end

local function getObjPos(obj)
	if obj:IsA("BasePart") then
		return obj.Position -- точные координаты
	elseif obj:IsA("Model") then
		return obj:GetPivot().Position -- точный центр модели
	end
end

-- Проверка, что у объекта есть BackDecal, FrontDecal и Sound
local function hasRequiredStuff(obj)
	local hasBack = false
	local hasFront = false
	local hasSound = false

	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("Decal") then
			if d.Name == "BackDecal" then
				hasBack = true
			elseif d.Name == "FrontDecal" then
				hasFront = true
			end
		elseif d:IsA("Sound") then
			hasSound = true
		end
	end

	return hasBack and hasFront and hasSound
end



local function getNearestCInZone()
	local folder = getCollectiblesFolder()
	if not folder then return nil end

	local best, bestDist = nil, math.huge
	for _, obj in ipairs(folder:GetChildren()) do
		if obj.Name == "C" then
			local pos = getObjPos(obj)
			if pos and isPointInZone(pos) then
				local d = (root.Position - pos).Magnitude
				if d < bestDist then
					bestDist = d
					best = obj
				end
			end
		end
	end
	return best, bestDist
end

-- ====== Movement ======
local STOP_RADIUS = 3.5          -- насколько близко "подойти"
local WAYPOINT_TIMEOUT = 2.8     -- таймаут на одну точку пути
local FAILSAFE_MOVE_TIMEOUT = 4  -- таймаут для прямого MoveTo

local function moveDirect(targetPos: Vector3, timeoutSec: number)
	humanoid:MoveTo(targetPos)
	local done = false
	local conn = humanoid.MoveToFinished:Connect(function()
		done = true
	end)

	local t = 0
	while not done and t < timeoutSec and _G.__FARMING do
		t += task.wait(0.05)
	end

	if conn then conn:Disconnect() end
	return done
end

local function movePath(targetPos: Vector3)
	-- если уже рядом — не дергаем pathfinding
	if (root.Position - targetPos).Magnitude <= STOP_RADIUS then
		return true
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 7,
		WaypointSpacing = 4,
	})

	path:ComputeAsync(root.Position, targetPos)
	if path.Status ~= Enum.PathStatus.Success then
		return moveDirect(targetPos, FAILSAFE_MOVE_TIMEOUT)
	end

	for _, wp in ipairs(path:GetWaypoints()) do
		if not _G.__FARMING then return false end

		-- если уже рядом с целью — стоп
		if (root.Position - targetPos).Magnitude <= STOP_RADIUS then
			return true
		end

		humanoid:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		local done = false
		local conn = humanoid.MoveToFinished:Connect(function()
			done = true
		end)

		local t = 0
		while not done and t < WAYPOINT_TIMEOUT and _G.__FARMING do
			t += task.wait(0.05)
		end

		if conn then conn:Disconnect() end

		-- если завис — маленький пинок
		if not done then
			humanoid.Jump = true
			task.wait(0.1)
		end
	end

	return (root.Position - targetPos).Magnitude <= STOP_RADIUS + 1
end

local function approachObject(obj)
	local pos = getObjPos(obj)
	if not pos then return false end

	-- идем к координатам C, фиксируем Y чтоб не улетало по высоте
	local target = Vector3.new(pos.X, Y, pos.Z)

	-- если по дороге C исчез/вышел из зоны — бросаем
	if not isPointInZone(target) then return false end

	-- идти, пока не подойдем достаточно близко
	local ok = movePath(target)
	if ok then
		-- финальный микро-дожим прямым MoveTo (иногда path стопает на 1-2м)
		if (root.Position - target).Magnitude > STOP_RADIUS then
			moveDirect(target, 1.2)
		end
	end
	return true
end

-- ====== Farm loop ======
_G.__FARMING = false

local function farmLoop()
	-- старт: чуть в центр (чтобы не упираться в стену/край)
	movePath(getZoneCenter())
	task.wait(0.2)

	while _G.__FARMING do

		-- перереспавн/слом ссылок
		if not player.Character or not humanoid or not root then
			refreshCharacter()
		end

		local cObj, dist = getNearestCInZone()

		if cObj then
			-- Подходим к C. Всё. Никаких кликов, просто "подошел" 
			if obj.Name == "C" and hasRequiredStuff(obj) then
				approachObject(cObj)
				task.wait(0.1)
			end
		else
			-- если C нет — гуляем
			local p = getRandomPointInZone()
			moveDirect(p, 2.5)
			print("false detect C obj")
			task.wait(0.2)
			
		end
	end
end

local function startFarm()
	if _G.__FARMING then return end
	_G.__FARMING = true
	task.spawn(farmLoop)
end

local function stopFarm()
	_G.__FARMING = false
end

-- ====== GUI ======
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarm_C_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = player:WaitForChild("PlayerGui")

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

-- Independent close (always top-right screen)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
closeBtn.Parent = frame -- ВАЖНО: именно в окно
closeBtn.ZIndex = 10

local function hardClose()
	stopFarm()
	gui:Destroy()
end

btnOn.MouseButton1Click:Connect(function()
	startFarm()
	status.Text = "Status: ON"
	status.TextColor3 = Color3.fromRGB(140, 255, 140)
end)

btnOff.MouseButton1Click:Connect(function()
	stopFarm()
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
