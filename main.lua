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

-- ====== CONFIGURATION ======
local Config = {
    -- Zone
    dandelion = {
        X1 = -102.6, X2 = 39.3,
        Z1 = 255, Z2 = 184.0,
        Y = 4.0,
    },

    -- Movement
    STOP_RADIUS = 2.5,               -- уменьшил для точности
    WAYPOINT_TIMEOUT = 0.8,          -- быстрее таймаут
    FAILSAFE_MOVE_TIMEOUT = 1.5,
    MOVEMENT_TICK = 0.016,           -- ~60fps проверка

    -- Farm loop
    TARGET_SWITCH_COOLDOWN = 0.05,   -- почти без кулдауна
    IDLE_WAIT = 0.05,
    LOOP_TICK = 0.016,

    -- Speed
    SPEED_APPLY_INTERVAL = 0.1,

    -- Pathfinding
    AGENT_RADIUS = 2,
    AGENT_HEIGHT = 5,
    AGENT_JUMP_HEIGHT = 7,
    WAYPOINT_SPACING = 6,            -- больше = меньше точек = быстрее

    -- Smart targeting
    VISITED_RADIUS = 8,              -- радиус "уже был тут"
    VISITED_EXPIRE = 3,              -- секунд помнить посещённое место
    MAX_VISITED = 10,                -- максимум запомненных мест
}

local function isPointInZone(pos: Vector3)
	local zone = Config.dandelion
	local minX = math.min(zone.X1, zone.X2)
	local maxX = math.max(zone.X1, zone.X2)
	local minZ = math.min(zone.Z1, zone.Z2)
	local maxZ = math.max(zone.Z1, zone.Z2)
	return pos.X >= minX and pos.X <= maxX and pos.Z >= minZ and pos.Z <= maxZ
end

local function getZoneCenter()
	return Vector3.new(
		(Config.dandelion.X1 + Config.dandelion.X2) / 2,
		Config.dandelion.Y,
		(Config.dandelion.Z1 + Config.dandelion.Z2) / 2
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
    local hasBack, hasFront, hasSound = false, false, false

    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("Decal") then
            local name = d.Name
            if name == "BackDecal" then 
                hasBack = true 
            elseif name == "FrontDecal" then 
                hasFront = true 
            end
        elseif d:IsA("Sound") then
            hasSound = true
        end
        
        -- Ранний выход как только всё найдено
        if hasBack and hasFront and hasSound then
            return true
        end
    end

    return false
end


-- ====== Smart target selection ======
local visitedPositions = {} -- {pos: Vector3, time: number}

local function isRecentlyVisited(pos)
    local now = os.clock()
    -- Очистка старых записей
    for i = #visitedPositions, 1, -1 do
        if (now - visitedPositions[i].time) > Config.VISITED_EXPIRE then
            table.remove(visitedPositions, i)
        end
    end
    -- Проверка близости к посещённым
    for _, v in ipairs(visitedPositions) do
        if (v.pos - pos).Magnitude < Config.VISITED_RADIUS then
            return true
        end
    end
    return false
end

local function markVisited(pos)
    -- Ограничиваем размер
    if #visitedPositions >= Config.MAX_VISITED then
        table.remove(visitedPositions, 1)
    end
    visitedPositions[#visitedPositions + 1] = {pos = pos, time = os.clock()}
end

local function getNearestToken()
    if not tokens or not root then return nil end

    local best = nil
    local bestDist = math.huge
    local rootPos = root.Position

    for _, obj in ipairs(tokens:GetChildren()) do
        if obj.Name == "C" and obj.Parent == tokens and hasRequiredStuff(obj) then
            local pos = getObjPos(obj)
            if pos and isPointInZone(pos) then
                local dist = (pos - rootPos).Magnitude
                -- Пропускаем недавно посещённые места
                if not isRecentlyVisited(pos) and dist < bestDist then
                    best = obj
                    bestDist = dist
                end
            end
        end
    end

    -- Если все места посещены — сбросить и взять любой ближайший
    if not best then
        visitedPositions = {}
        for _, obj in ipairs(tokens:GetChildren()) do
            if obj.Name == "C" and obj.Parent == tokens and hasRequiredStuff(obj) then
                local pos = getObjPos(obj)
                if pos and isPointInZone(pos) then
                    local dist = (pos - rootPos).Magnitude
                    if dist < bestDist then
                        best = obj
                        bestDist = dist
                    end
                end
            end
        end
    end

    return best
end


-- ====== Movement (smooth) ======

local function moveDirect(targetPos: Vector3, timeoutSec: number)
    if not humanoid then return false end
    humanoid:MoveTo(targetPos)

    local done = false
    local conn
    conn = humanoid.MoveToFinished:Once(function()
        done = true
    end)

    local t = 0
    while not done and t < timeoutSec and _G.__FARMING do
        t += task.wait(Config.MOVEMENT_TICK)
    end

    conn:Disconnect()
    return done
end


local function movePath(targetPos: Vector3)
    local MAX_RETRIES = 3
    
    for attempt = 1, MAX_RETRIES do
        if (root.Position - targetPos).Magnitude <= Config.STOP_RADIUS then
            return true
        end
        
        local path = PathfindingService:CreatePath({
            AgentRadius = Config.AGENT_RADIUS,
            AgentHeight = Config.AGENT_HEIGHT,
            AgentCanJump = true,
            AgentJumpHeight = Config.AGENT_JUMP_HEIGHT,
            WaypointSpacing = Config.WAYPOINT_SPACING,
        })

        path:ComputeAsync(root.Position, targetPos)
        if path.Status ~= Enum.PathStatus.Success then
            return moveDirect(targetPos, Config.FAILSAFE_MOVE_TIMEOUT)
        end

        local waypoints = path:GetWaypoints()
        local completed = true
        
        for _, wp in ipairs(waypoints) do
            if not _G.__FARMING then return false end
            if (root.Position - targetPos).Magnitude <= Config.STOP_RADIUS then return true end

            humanoid:MoveTo(wp.Position)
            if wp.Action == Enum.PathWaypointAction.Jump then
                humanoid.Jump = true
            end

            local reached = false
            local conn = humanoid.MoveToFinished:Once(function()
                reached = true
            end)

            local t = 0
            while not reached and t < Config.WAYPOINT_TIMEOUT and _G.__FARMING do
                t += task.wait(Config.MOVEMENT_TICK)
            end
            conn:Disconnect()

            if not reached then
                completed = false
                break
            end
        end
        
        if completed then
            return (root.Position - targetPos).Magnitude <= Config.STOP_RADIUS + 1
        end
    end
    
    return false
end


local function approachObject(obj)
    local pos = getObjPos(obj)
    if not pos then return false end
    if not isPointInZone(pos) then return false end

    -- Просто идём напрямую — быстрее чем pathfinding для близких целей
    local dist = (root.Position - pos).Magnitude
    local ok
    if dist < 15 then
        ok = moveDirect(pos, Config.FAILSAFE_MOVE_TIMEOUT)
    else
        ok = movePath(pos)
    end

    -- Отмечаем место как посещённое
    if ok then
        markVisited(pos)
    end

    return ok
end

-- ====== Speed control (loop apply) ======
local function round1(x)
	return math.floor(x * 10) / 10
end
local DEFAULT_WALKSPEED = 30
if humanoid then DEFAULT_WALKSPEED = humanoid.WalkSpeed end
local currentSpeed = round1(DEFAULT_WALKSPEED)

_G.GetSpeed = function() return currentSpeed end

local function setSpeed(v)
	v = tonumber(v)
	if not v then return end
	currentSpeed = v
end

task.spawn(function()
	while true do
		task.wait(Config.SPEED_APPLY_INTERVAL)
		if humanoid then
			humanoid.WalkSpeed = currentSpeed
		end
	end
end)

-- ====== Farm loop ======
_G.__FARMING = false
local currentTarget = nil

local function farmLoop()
    -- Быстрый старт — идём к центру только если далеко
    local center = getZoneCenter()
    if (root.Position - center).Magnitude > 50 then
        moveDirect(center, 3)
    end

    while _G.__FARMING do
        -- respawn safety
        if not player.Character or not humanoid or not root then
            refreshCharacter()
            task.wait(0.1)
            continue
        end

        -- Цель ещё валидна? Продолжаем к ней
        if currentTarget and currentTarget.Parent == tokens then
            local pos = getObjPos(currentTarget)
            if pos and isPointInZone(pos) then
                -- Уже близко — сразу ищем следующую
                if (root.Position - pos).Magnitude <= Config.STOP_RADIUS then
                    markVisited(pos)
                    currentTarget = nil
                else
                    approachObject(currentTarget)
                    continue
                end
            else
                currentTarget = nil
            end
        end

        -- Ищем ближайший токен (умный выбор)
        currentTarget = getNearestToken()

        if currentTarget then
            approachObject(currentTarget)
        else
            task.wait(Config.IDLE_WAIT)
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
	stopFarm()
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