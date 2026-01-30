-- main.lua (Farming logic and movement)
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local tokens = workspace:WaitForChild("Collectibles")

-- ====== ZONE SETTINGS (Field coordinates) ======
local Fields = {
    ["Pine Tree Forest"] = {X1 = -340, X2 = -280, Z1 = -210, Z2 = -130, Y = 65.5},
    ["Pepper Patch"]    = {X1 = -400, X2 = -300, Z1 = -350, Z2 = -250, Y = 105.0},
    ["Mountain Top Field"] = {X1 = 55,  X2 = 95,  Z1 = -225, Z2 = -145, Y = 176.0},
}
local fieldList = {"Pine Tree Forest", "Pepper Patch", "Mountain Top Field"}
local currentField = fieldList[1]  -- default field

-- Table to hold current zone boundaries
local Zone = { min = Vector3.new(0,0,0), max = Vector3.new(0,0,0) }
-- Apply field coordinates to Zone
local function applyField(name)
    local coords = Fields[name]
    if not coords then return end
    Zone.min = Vector3.new(math.min(coords.X1, coords.X2), coords.Y, math.min(coords.Z1, coords.Z2))
    Zone.max = Vector3.new(math.max(coords.X1, coords.X2), coords.Y, math.max(coords.Z1, coords.Z2))
    currentField = name
end
-- Initialize Zone with default field
applyField(currentField)

local function isPointInZone(pos: Vector3)
    return pos.X >= Zone.min.X and pos.X <= Zone.max.X
       and pos.Z >= Zone.min.Z and pos.Z <= Zone.max.Z
end

local function getZoneCenter()
    return Vector3.new(
        (Zone.min.X + Zone.max.X) / 2,
        Zone.min.Y,
        (Zone.min.Z + Zone.max.Z) / 2
    )
end

-- ====== Character references (safe on respawn) ======
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

-- ====== Token object helpers ======
local function getObjPos(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        return obj:GetPivot().Position
    end
    return nil
end

local function hasRequiredStuff(obj)
    -- Check that the token has BackDecal, FrontDecal, and a Sound
    local hasBack, hasFront, hasSound = false, false, false
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("Decal") then
            if d.Name == "BackDecal" then hasBack = true end
            if d.Name == "FrontDecal" then hasFront = true end
        elseif d:IsA("Sound") then
            hasSound = true
        end
        if hasBack and hasFront and hasSound then
            break  -- all found
        end
    end
    return hasBack and hasFront and hasSound
end

-- ====== Pick a random valid token ("C") within the zone ======
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
    if #list == 0 then
        return nil
    end
    return list[math.random(1, #list)]
end

-- ====== Smooth movement using PathfindingService ======
local STOP_RADIUS = 3.5          -- distance at which we consider the token "reached"
local WAYPOINT_TIMEOUT = 2.8     -- max wait per waypoint
local FAILSAFE_MOVE_TIMEOUT = 4  -- fallback timeout for direct move

local function moveDirect(targetPos: Vector3, timeoutSec: number)
    if not humanoid then return false end
    humanoid:MoveTo(targetPos)
    local done = false
    local conn
    conn = humanoid.MoveToFinished:Connect(function(reached)
        done = true
        if conn then conn:Disconnect() end
    end)
    local t = 0
    while not done and t < timeoutSec and _G.__FARMING do
        t += task.wait(0.05)
    end
    if conn then conn:Disconnect() end
    return done
end

local function movePath(targetPos: Vector3)
    if not root or not humanoid then return false end
    if (root.Position - targetPos).Magnitude <= STOP_RADIUS then
        return true  -- already close enough
    end
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7,
        WaypointSpacing = 5,  -- bigger spacing for smoother turns
    })
    path:ComputeAsync(root.Position, targetPos)
    if path.Status ~= Enum.PathStatus.Success then
        -- If pathfinding fails, fall back to a direct move attempt
        return moveDirect(targetPos, FAILSAFE_MOVE_TIMEOUT)
    end
    local waypoints = path:GetWaypoints()
    for _, wp in ipairs(waypoints) do
        if not _G.__FARMING then return false end
        if (root.Position - targetPos).Magnitude <= STOP_RADIUS then
            return true
        end
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
        -- If stuck on this waypoint, try recomputing path (recursively)
        if not reached then
            return movePath(targetPos)
        end
    end
    return ((root.Position - targetPos).Magnitude <= STOP_RADIUS + 1)
end

local function approachObject(obj)
    local pos = getObjPos(obj)
    if not pos then return false end
    -- Ensure the token is still within the zone
    if not isPointInZone(pos) then
        return false
    end
    local ok = movePath(pos)
    -- If path got us close but not within stop radius, finish with a short direct move
    if ok and (root.Position - pos).Magnitude > STOP_RADIUS then
        moveDirect(pos, 1.2)
    end
    return ok
end

-- ====== Speed control loop ======
local function round1(x)  -- helper to round to 1 decimal place
    return math.floor(x * 10) / 10
end
local DEFAULT_WALKSPEED = 16
if humanoid then
    DEFAULT_WALKSPEED = humanoid.WalkSpeed
end
local currentSpeed = round1(DEFAULT_WALKSPEED)

_G.__SPEED_LOOP = true  -- flag to control the speed loop
_G.GetSpeed = function() return currentSpeed end

local function setSpeed(v)
    v = tonumber(v)
    if not v then return end
    currentSpeed = v
end

-- Spawn a loop to continuously apply the current speed to Humanoid
task.spawn(function()
    while _G.__SPEED_LOOP do
        task.wait(0.1)
        if humanoid then
            humanoid.WalkSpeed = currentSpeed
        end
    end
end)

-- ====== Farming loop control ======
_G.__FARMING = false
local currentTarget = nil
local lastSwitch = 0
local TARGET_SWITCH_COOLDOWN = 0.6

local function farmLoop()
    -- Move player to the center of the field once at start
    movePath(getZoneCenter())
    task.wait(0.2)
    while _G.__FARMING do
        -- If character or humanoid was lost (e.g. died), refresh references
        if not player.Character or not humanoid or not root then
            refreshCharacter()
        end
        -- Continue approaching current target if it's still valid
        if currentTarget and currentTarget.Parent == tokens then
            local pos = getObjPos(currentTarget)
            if pos and isPointInZone(pos) then
                approachObject(currentTarget)
                task.wait(0.1)
                continue  -- keep farming current target
            end
        end
        -- If we reach here, need to find a new target token
        local now = os.clock()
        if (now - lastSwitch) < TARGET_SWITCH_COOLDOWN then
            -- Small cooldown to avoid rapidly switching targets
            task.wait(0.1)
            continue
        end
        currentTarget = getRandomCInZone()
        lastSwitch = now
        if currentTarget then
            approachObject(currentTarget)
            task.wait(0.1)
        else
            -- No token available in zone, wait a bit before retrying
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
        farming = (_G.__FARMING == true),
        speed   = currentSpeed,
        target  = currentTarget and currentTarget:GetFullName() or nil,
        field   = currentField,
    }
end

local function setField(name)
    if not Fields[name] then return end
    local wasFarming = _G.__FARMING
    if wasFarming then
        stopFarm()
    end
    applyField(name)
    if wasFarming then
        startFarm()
    else
        -- If farm was off, just move the character to the new field center
        task.spawn(function()
            movePath(getZoneCenter())
        end)
    end
end

local function resetAll()
    -- Stop farming and reset speed/field
    stopFarm()
    currentSpeed = DEFAULT_WALKSPEED
    if humanoid then
        humanoid.WalkSpeed = DEFAULT_WALKSPEED
    end
    _G.__SPEED_LOOP = false  -- end the speed apply loop
    -- (GUI will be destroyed by itself on close)
end

-- Expose functions for GUI
_G.StartFarm = startFarm
_G.StopFarm  = stopFarm
_G.SetField  = setField
_G.SetSpeed  = setSpeed
_G.GetState  = getState
_G.ResetAll  = resetAll

-- Also expose field list for the GUI dropdown
_G.GetFields = function()
    return fieldList
end
