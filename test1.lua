if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    error("[K4 Tween] LocalPlayer not found")
end

getgenv().TyrantConfig = getgenv().TyrantConfig or {}
local TyrantConfig = getgenv().TyrantConfig

local tweenDefaults = {
    TweenSpeed = 190,
    FarmFollowSpeed = 190,
    FarmArrivalDistance = 7,
    FarmFollowDeadZone = 1.25,
    FarmFollowGain = 7.5,
    FarmFollowPrediction = 0.08,
    FarmTargetVelocityCap = 95,
    FarmHeight = 18,
    BossHeight = 25
}

for key, value in pairs(tweenDefaults) do
    if TyrantConfig[key] == nil then
        TyrantConfig[key] = value
    end
end

local module = {}
local activeMoveTarget = nil
local activeMoveOptions = {}
local activeMoveEnabled = false
local activeMoveRoot = nil
local activeMoveVelocity = Vector3.zero
local activeMoveSmoothedPosition = nil
local activeMoveLastCommandAt = 0

local K4_MOVE_VELOCITY_NAME = "K4SmoothMoveVelocity"
local K4_MOVE_GYRO_NAME = "K4SmoothMoveGyro"

local function K4GetCharacterParts()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, root
end

local function K4SetCharacterNoclip(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function K4GetMoveActuators(root)
    if not root or not root.Parent then return nil, nil end

    local velocity = root:FindFirstChild(K4_MOVE_VELOCITY_NAME)
    if not velocity then
        velocity = Instance.new("BodyVelocity")
        velocity.Name = K4_MOVE_VELOCITY_NAME
        velocity.P = 1600
        velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        velocity.Velocity = Vector3.zero
        velocity.Parent = root
    end

    local gyro = root:FindFirstChild(K4_MOVE_GYRO_NAME)
    if not gyro then
        gyro = Instance.new("BodyGyro")
        gyro.Name = K4_MOVE_GYRO_NAME
        gyro.P = 5000
        gyro.D = 850
        gyro.MaxTorque = Vector3.new(0, 1e9, 0)
        gyro.CFrame = root.CFrame
        gyro.Parent = root
    end

    return velocity, gyro
end

local function K4MoveVectorTowards(current, target, maximumChange)
    local difference = target - current
    local magnitude = difference.Magnitude
    if magnitude <= maximumChange or magnitude <= 1e-4 then
        return target
    end
    return current + difference.Unit * maximumChange
end

local function K4ClampVectorMagnitude(vector, maximumMagnitude)
    local magnitude = vector.Magnitude
    if magnitude <= maximumMagnitude or magnitude <= 1e-4 then
        return vector
    end
    return vector.Unit * maximumMagnitude
end

local function K4CancelMoveTween(clearTarget)
    activeMoveEnabled = false
    activeMoveVelocity = Vector3.zero
    activeMoveSmoothedPosition = nil
    activeMoveLastCommandAt = 0

    local _, humanoid, root = K4GetCharacterParts()
    if humanoid then
        humanoid.AutoRotate = true
    end

    if root then
        local velocity = root:FindFirstChild(K4_MOVE_VELOCITY_NAME)
        if velocity then
            pcall(function()
                velocity:Destroy()
            end)
        end

        local gyro = root:FindFirstChild(K4_MOVE_GYRO_NAME)
        if gyro then
            pcall(function()
                gyro:Destroy()
            end)
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    activeMoveRoot = nil

    if clearTarget ~= false then
        activeMoveTarget = nil
        activeMoveOptions = {}
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    if not activeMoveEnabled or typeof(activeMoveTarget) ~= "CFrame" then return end

    local character, humanoid, root = K4GetCharacterParts()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return
    end

    if activeMoveRoot ~= root then
        activeMoveRoot = root
        activeMoveVelocity = Vector3.zero
        activeMoveSmoothedPosition = activeMoveTarget.Position
    end

    K4SetCharacterNoclip(character)
    humanoid.Sit = false
    humanoid.AutoRotate = false

    local velocityMover, gyro = K4GetMoveActuators(root)
    if not velocityMover or not gyro then return end

    deltaTime = math.clamp(tonumber(deltaTime) or 0.016, 0.001, 0.10)

    local options = activeMoveOptions
    local followPart = options.FollowPart
    local followingPart = typeof(followPart) == "Instance"
        and followPart:IsA("BasePart")
        and followPart:IsDescendantOf(Workspace)

    local rawTargetPosition = activeMoveTarget.Position
    local targetVelocity = Vector3.zero
    local lookPosition = rawTargetPosition + activeMoveTarget.LookVector

    if followingPart then
        local followOffset = options.FollowOffset
        if typeof(followOffset) ~= "Vector3" then
            followOffset = Vector3.new(0, tonumber(options.FollowHeight) or 18, 0)
        end

        targetVelocity = followPart.AssemblyLinearVelocity
        local targetVelocityCap = math.max(tonumber(options.TargetVelocityCap) or 95, 1)
        targetVelocity = K4ClampVectorMagnitude(targetVelocity, targetVelocityCap)

        local prediction = math.clamp(tonumber(options.PredictionTime) or 0.08, 0, 0.25)
        rawTargetPosition = followPart.Position + followOffset + targetVelocity * prediction
        lookPosition = followPart.Position
    end

    local targetResponsiveness = math.max(
        tonumber(options.TargetResponsiveness) or (followingPart and 24 or 18),
        1
    )
    local targetAlpha = 1 - math.exp(-targetResponsiveness * deltaTime)

    if not activeMoveSmoothedPosition then
        activeMoveSmoothedPosition = rawTargetPosition
    else
        activeMoveSmoothedPosition = activeMoveSmoothedPosition:Lerp(rawTargetPosition, targetAlpha)
    end

    local offset = activeMoveSmoothedPosition - root.Position
    local distance = offset.Magnitude
    local maximumSpeed = math.max(tonumber(options.Speed) or 300, 1)
    local acceleration = math.max(tonumber(options.Acceleration) or 750, 50)
    local deceleration = math.max(tonumber(options.Deceleration) or 850, 50)
    local desiredVelocity = Vector3.zero

    if followingPart then
        local deadZone = math.max(tonumber(options.FollowDeadZone) or 1.25, 0.25)
        local followGain = math.max(tonumber(options.FollowGain) or 7.5, 0.5)
        local correction = Vector3.zero

        if distance > deadZone and distance > 1e-3 then
            local correctedDistance = distance - deadZone
            correction = offset.Unit * math.min(maximumSpeed, correctedDistance * followGain)
        end

        desiredVelocity = K4ClampVectorMagnitude(targetVelocity + correction, maximumSpeed)
    else
        local arrivalDistance = math.max(tonumber(options.ArrivalDistance) or 5, 2)

        if distance > arrivalDistance and distance > 1e-3 then
            local brakingDistance = math.max(distance - arrivalDistance, 0)
            local brakingSpeed = math.sqrt(2 * deceleration * brakingDistance)
            local desiredSpeed = math.min(maximumSpeed, brakingSpeed)

            if distance > 30 then
                desiredSpeed = math.max(desiredSpeed, math.min(maximumSpeed, 45))
            end

            desiredVelocity = offset.Unit * desiredSpeed
        end
    end

    local velocityChangeRate = desiredVelocity.Magnitude < activeMoveVelocity.Magnitude
        and deceleration
        or acceleration

    activeMoveVelocity = K4MoveVectorTowards(
        activeMoveVelocity,
        desiredVelocity,
        velocityChangeRate * deltaTime
    )

    if not followingPart and desiredVelocity.Magnitude < 0.5 and activeMoveVelocity.Magnitude < 3 then
        activeMoveVelocity = Vector3.zero
    end

    velocityMover.Velocity = activeMoveVelocity
    root.AssemblyAngularVelocity = Vector3.zero

    local flatLook = Vector3.new(
        lookPosition.X - root.Position.X,
        0,
        lookPosition.Z - root.Position.Z
    )

    if flatLook.Magnitude > 0.05 then
        gyro.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
    end
end)

function module:topos(targetCF, moveOptions)
    if typeof(targetCF) ~= "CFrame" then return false end

    local character, humanoid, root = K4GetCharacterParts()
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return false
    end

    moveOptions = type(moveOptions) == "table" and moveOptions or {}

    local targetPosition = targetCF.Position
    targetPosition = Vector3.new(targetPosition.X, math.max(targetPosition.Y, 5), targetPosition.Z)
    targetCF = CFrame.new(targetPosition) * (targetCF - targetCF.Position)

    local wasActive = activeMoveEnabled
    local previousTarget = activeMoveTarget

    activeMoveTarget = targetCF
    activeMoveOptions = moveOptions
    activeMoveEnabled = true
    activeMoveLastCommandAt = tick()

    if not wasActive or activeMoveRoot ~= root then
        activeMoveRoot = root
        activeMoveVelocity = Vector3.zero
        activeMoveSmoothedPosition = targetPosition
    elseif moveOptions.ResetVelocity == true then
        activeMoveVelocity = Vector3.zero
    elseif moveOptions.Follow ~= true
        and previousTarget
        and (previousTarget.Position - targetPosition).Magnitude > 250
    then
        activeMoveSmoothedPosition = targetPosition
    end

    humanoid.Sit = false
    humanoid.AutoRotate = false
    K4SetCharacterNoclip(character)
    K4GetMoveActuators(root)

    return true
end

local function TyrRoot()
    local _, _, root = K4GetCharacterParts()
    return root
end

local function TyrHumanoid()
    local _, humanoid = K4GetCharacterParts()
    return humanoid
end

local function TyrMoveTo(targetCF, waitForArrival, timeout)
    if typeof(targetCF) ~= "CFrame" then return false end

    local root = TyrRoot()
    if not root then return false end

    local initialDistance = (root.Position - targetCF.Position).Magnitude
    local configuredSpeed = math.max(tonumber(TyrantConfig.TweenSpeed) or 300, 1)
    local minimumTimeout = math.max(5, initialDistance / configuredSpeed + 10)
    timeout = math.max(tonumber(timeout) or 0, minimumTimeout)

    local moveOptions = {
        Speed = configuredSpeed,
        ArrivalDistance = 5,
        TargetResponsiveness = 30,
        Acceleration = 700,
        Deceleration = 800,
        Follow = false
    }

    module:topos(targetCF, moveOptions)

    if not waitForArrival then
        return true
    end

    local started = tick()
    local lastProgressAt = started
    local lastDistance = initialDistance

    repeat
        task.wait(0.10)

        root = TyrRoot()
        local humanoid = TyrHumanoid()

        if not root or not humanoid or humanoid.Health <= 0 then
            return false
        end

        local distance = (root.Position - targetCF.Position).Magnitude

        if distance <= 7 then
            K4CancelMoveTween(false)
            activeMoveTarget = targetCF
            return true
        end

        if distance < lastDistance - 1 then
            lastDistance = distance
            lastProgressAt = tick()
        elseif tick() - lastProgressAt > 3 then
            moveOptions.ResetVelocity = true
            module:topos(targetCF, moveOptions)
            moveOptions.ResetVelocity = nil
            lastProgressAt = tick()
            lastDistance = distance
        elseif not activeMoveEnabled then
            module:topos(targetCF, moveOptions)
        end
    until tick() - started >= timeout

    root = TyrRoot()

    if root and (root.Position - targetCF.Position).Magnitude <= 15 then
        K4CancelMoveTween(false)
        activeMoveTarget = targetCF
        return true
    end

    K4CancelMoveTween()
    return false
end

local function TyrTargetCFrame(targetPart, height)
    if not targetPart or not targetPart:IsA("BasePart") then return nil end
    height = tonumber(height) or 18
    local position = targetPart.Position + Vector3.new(0, height, 0)
    return CFrame.new(position, targetPart.Position)
end

local function TyrFollowEnemy(enemyRoot, height, isBoss, resetVelocity)
    if not enemyRoot or not enemyRoot:IsA("BasePart") then return false end

    height = tonumber(height) or (isBoss and TyrantConfig.BossHeight or TyrantConfig.FarmHeight)
    local targetCF = TyrTargetCFrame(enemyRoot, height)
    if not targetCF then return false end

    return module:topos(targetCF, {
        Speed = tonumber(TyrantConfig.FarmFollowSpeed) or 300,
        Follow = true,
        FollowPart = enemyRoot,
        FollowOffset = Vector3.new(0, height, 0),
        FollowDeadZone = tonumber(TyrantConfig.FarmFollowDeadZone) or 1.25,
        FollowGain = tonumber(TyrantConfig.FarmFollowGain) or 7.5,
        PredictionTime = tonumber(TyrantConfig.FarmFollowPrediction) or 0.08,
        TargetVelocityCap = tonumber(TyrantConfig.FarmTargetVelocityCap) or 95,
        TargetResponsiveness = isBoss and 20 or 24,
        Acceleration = isBoss and 720 or 820,
        Deceleration = isBoss and 880 or 980,
        ResetVelocity = resetVelocity == true
    })
end

function module:cancel(clearTarget)
    K4CancelMoveTween(clearTarget)
end

function module:moveTo(targetCF, waitForArrival, timeout)
    return TyrMoveTo(targetCF, waitForArrival, timeout)
end

function module:followPart(targetPart, height, isBoss, resetVelocity)
    return TyrFollowEnemy(targetPart, height, isBoss == true, resetVelocity == true)
end

function module:isMoving()
    return activeMoveEnabled
end

function module:getTarget()
    return activeMoveTarget
end

LocalPlayer.CharacterAdded:Connect(function()
    K4CancelMoveTween()
end)

getgenv().K4TweenModule = module
getgenv().K4CancelMoveTween = K4CancelMoveTween
getgenv().K4MoveTo = TyrMoveTo
getgenv().K4FollowPart = TyrFollowEnemy

return module
