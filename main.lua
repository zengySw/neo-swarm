-- functions.lua (LOGIC ONLY) - smooth movement, random C in zone
-- Exports:
--   _G.StartFarm()
--   _G.StopFarm()
--   _G.SetSpeed(value)
--   _G.GetState() -> { farming=bool, speed=number, target=string? }
--
-- Requirements:
--   workspace.Collectibles exists (Folder)
--   Objects named "C" inside it
--   Optional filter: must have BackDecal + FrontDecal + Sound (descendants)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local tokens = workspace:WaitForChild("Collectibles")

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
	return Vector3.new(
		(Zone.min.X + Zone.max.X) / 2,
		Y,
		(Zone.min.Z + Zone.max.Z) / 2
	)
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

-- ====== Object helpers ======
local function getObjPos(obj)
	if obj:IsA("BasePart") then
		return obj.Position
	elseif obj:IsA("Model") then
		return obj:GetPivot().Position
	end
	return nil
end

local function hasRequiredStuff(obj)
	-- BackDecal + FrontDecal + any Sound (descendant)
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

-- ====== Pick random C in zone (filtered) ======
local function getRandomCInZone()
	if not tokens then return nil end

	local list = {}
	for _, obj in ipairs(tokens:GetChildren()) do
		if obj.Name == "C" and hasRequiredStuff(obj) then
			local pos = getObjPos(obj)
			if pos and isPointInZone(pos) then
				list[#list + 1] = obj
			end
		end
	end

	if #list == 0 then return nil end
	return list[math.random(1, #list)]
end

-- ====== Movement (smooth) ======
local STOP_RADIUS = 3.5
local WAYPOINT_TIMEOUT = 2.8
local FAILSAFE_MOVE_TIMEOUT = 4

local function moveDirect(targetPos: Vector3, timeoutSec: number)
	if not humanoid then return false end
	humanoid:MoveTo(targetPos)

	local done = false
	local conn
	conn = humanoid.MoveToFinished:Connect(function()
		done = true
		if conn then conn:Disconnect() end
	end)

	local t = 0
	while not done and t < timeoutSec and _G.__FARMING do
		t += task.wait(0.05) -- IMPORTANT: no micro-spam
	end

	if conn then conn:Disconnect() end
	return done
end

local function movePath(targetPos: Vector3)
	if (root.Position - targetPos).Magnitude <= STOP_RADIUS then
		return true
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 7,
		WaypointSpacing = 5, -- bigger = smoother
	})

	path:ComputeAsync(root.Position, targetPos)
	if path.Status ~= Enum.PathStatus.Success then
		return moveDirect(targetPos, FAILSAFE_MOVE_TIMEOUT)
	end

	local waypoints = path:GetWaypoints()
	for _, wp in ipairs(waypoints) do
		if not _G.__FARMING then return false end
		if (root.Position - targetPos).Magnitude <= STOP_RADIUS then return true end

		humanoid:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		local reached = false
		local conn
		conn = humanoid.MoveToFinished:Connect(function()
			reached = true
			if conn then conn:Disconnect() end
		end)

		local t = 0
		while not reached and t < WAYPOINT_TIMEOUT and _G.__FARMING do
			t += task.wait(0.05)
		end
		if conn then conn:Disconnect() end

		-- stuck -> recompute (but not spam)
		if not reached then
			return movePath(targetPos)
		end
	end

	return (root.Position - targetPos).Magnitude <= STOP_RADIUS + 1
end

local function approachObject(obj)
	local pos = getObjPos(obj)
	if not pos then return false end

	-- must still be in zone (exact coords)
	if not isPointInZone(pos) then
		return false
	end

	local ok = movePath(pos)
	if ok and (root.Position - pos).Magnitude > STOP_RADIUS then
		moveDirect(pos, 1.2)
	end
	return ok
end

-- ====== Speed control (loop apply) ======
local DEFAULT_WALKSPEED = 16
local currentSpeed = DEFAULT_WALKSPEED

if humanoid then
	DEFAULT_WALKSPEED = humanoid.WalkSpeed
	currentSpeed = DEFAULT_WALKSPEED
end


-- вызывается из GUI
local function setSpeed(v)
	v = tonumber(v)
	if not v then return end
	currentSpeed = v
end

-- ОТДЕЛЬНЫЙ ЦИКЛ, КОТОРЫЙ ПОСТОЯННО ПРИМЕНЯЕТ СКОРОСТЬ
task.spawn(function()
	while true do
		task.wait(0.1) -- как ты и хотел
		if humanoid then
			humanoid.WalkSpeed = currentSpeed
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		if humanoid then
			humanoid.WalkSpeed = currentSpeed
		end
	end
end)

-- ====== Farm loop (no twitching) ======
_G.__FARMING = false


if typeof(_G.SetSpeed) == "function" then
	_G.SetSpeed(v)
	speedLabel.Text = "Speed: "..v
else
	warn("_G.SetSpeed not found (load main.lua first)")
end


local TARGET_SWITCH_COOLDOWN = 0.6
local currentTarget = nil
local lastSwitch = 0

local function farmLoop()
	-- move to center once
	movePath(getZoneCenter())
	task.wait(0.2)

	while _G.__FARMING do
		-- respawn safety
		if not player.Character or not humanoid or not root then
			refreshCharacter()
		end

		-- keep current target until invalid
		if currentTarget and currentTarget.Parent == tokens then
			local pos = getObjPos(currentTarget)
			if pos and isPointInZone(pos) then
				approachObject(currentTarget)
				task.wait(0.1)
				continue
			end
		end

		-- cooldown to prevent target thrash
		local now = os.clock()
		if (now - lastSwitch) < TARGET_SWITCH_COOLDOWN then
			task.wait(0.1)
			continue
		end

		currentTarget = getRandomCInZone()
		lastSwitch = now

		if currentTarget then
			approachObject(currentTarget)
			task.wait(0.1)
		else
			-- nothing to do -> idle a bit
			task.wait(0.25)
		end
	end
end

-- ====== Public API for GUI ======
local function startFarm()
	if _G.__FARMING then return end
	_G.__FARMING = true
	task.spawn(farmLoop)
end

local function stopFarm()
	_G.__FARMING = false
	currentTarget = nil
end

local function getState()
	return {
		farming = _G.__FARMING == true,
		speed = currentSpeed,
		target = currentTarget and currentTarget:GetFullName() or nil,
	}
end

local function resetAll()
	-- стоп фарм
	stopFarm()
	-- вернуть дефолтную скорость
	currentSpeed = DEFAULT_WALKSPEED
	if humanoid then
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
	end
end

-- Export to globals for gui.lua
_G.StartFarm = startFarm
_G.StopFarm = stopFarm
_G.SetSpeed = setSpeed
_G.GetState = getState
_G.ResetAll = resetAll
