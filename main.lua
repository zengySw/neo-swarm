local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local tokens = workspace:WaitForChild("Collectibles")
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
	local hasBack, hasFront, hasSound = false, false, false

	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("Decal") then
			if d.Name == "BackDecal" then hasBack = true end
			if d.Name == "FrontDecal" then hasFront = true end
		elseif d:IsA("Sound") then
			hasSound = true
		end
	end

	return hasBack and hasFront and hasSound
end



local function getRandomCInZone()
	if not tokens then return nil end

	local list = {}

	for _, obj in ipairs(tokens:GetChildren()) do
		if obj.Name == "C" then
			local pos = getObjPos(obj)
			if pos and isPointInZone(pos) then
				table.insert(list, obj)
			end
		end
	end

	if #list == 0 then
		return nil
	end

	return list[math.random(1, #list)]
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
		t += task.wait(0.01)
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
			t += task.wait(0.01)
		end

		if conn then conn:Disconnect() end

		-- если завис — маленький пинок
		
	end

	return (root.Position - targetPos).Magnitude <= STOP_RADIUS + 1
end

local function approachObject(obj)
	local pos = getObjPos(obj)
	if not pos then return false end

	-- ТОЧНО в координаты объекта (без подмены Y)
	if not isPointInZone(pos) then 
		warn("C moved out of zone before approach:", obj:GetFullName())
		return false 
	end

	local ok = movePath(pos)
	if ok then
		-- финальный дожим (точно в pos)
		if (root.Position - pos).Magnitude > STOP_RADIUS then
			moveDirect(pos, 1.2)
		end
	end
	return true
end


-- ====== Farm loop ======
_G.__FARMING = false

local function farmLoop()
	-- старт: чуть в центр (чтобы не упираться в стену/край)
	movePath(getZoneCenter())
	task.wait(0.01)

	while _G.__FARMING do

		-- перереспавн/слом ссылок
		if not player.Character or not humanoid or not root then
			refreshCharacter()
		end

		local cObj, dist = getRandomCInZone()

			if cObj then
				-- cObj уже гарантированно "C" + hasRequiredStuff (ты это проверяешь в getNearestCInZone)
				approachObject(cObj)
				task.wait(0.01)
			else
			-- если C нет — гуляем
			-- local p = getRandomPointInZone()
			-- moveDirect(p, 2.5)
			print("false detect C obj")
			task.wait(0.01)
			
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

_G.StartFarm = startFarm
_G.StopFarm  = stopFarm
