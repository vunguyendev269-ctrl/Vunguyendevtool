--[[
    TWEENLAB v1.1 STANDALONE
    - Core: BF49 v5 proxy-part tween (ep HumanoidRootPart theo proxy moi frame)
    - GUI : chon dao, STOP an toan, speed preset + nhap tay + nut - / + (doi giua chung)
    - Debug wall trong Workspace: HUD part + log page, tu tao part moi khi page day
    - FIX v1.1: bo resync proxy khi server keo lai (nguyen nhan giat ~200 studs lap lai)
                 va bug releaseRetries tang moi frame (spam "settle that bai 44 lan")

    Cach dung: execute truc tiep. RightControl = an/hien GUI.
    Env API : getgenv().TweenLab.Go("Hydra Island") / .Stop() / .SetSpeed(340) / .Cleanup()
]]

repeat task.wait() until game:IsLoaded()

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")

local player = Players.LocalPlayer
repeat task.wait() until player

local env = getgenv and getgenv() or _G

-- clean run truoc do -----------------------------------------------------------
if type(env.TweenLabCleanup) == "function" then pcall(env.TweenLabCleanup) end
env.TweenLabCleanup = nil
env.TLSpeed = math.clamp(tonumber(env.TLSpeed) or 325, 100, 500)

for _, name in ipairs({ "TLProxy", "TweenLabDebug" }) do
    local stale = workspace:FindFirstChild(name)
    if stale then stale:Destroy() end
end
local oldRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if oldRoot then
    for _, inst in ipairs(oldRoot:GetChildren()) do
        if inst.Name:match("^TL") then inst:Destroy() end
    end
end

-- cau hinh (sua truc tiep khi chay: env.TweenLabCfg.SettleMin = 1.5) ------------
local CFG = {
    SettleMin       = 1.8,   -- giu tai dich truoc khi release (BF49)
    SettleStopMin   = 2.2,   -- settle khi bam STOP
    QuietNeed       = 1.25,  -- khong bi keo trong bao lau moi release
    ReleaseConfirm  = 2.5,   -- release xong xac nhan on dinh bau lau
    MaxReleaseRetry = 4,     -- tran so lan release bi hoi tui ve settle
    PushSnap        = 28,    -- server keo >28 studs = 1 correction (BF49)
    SettlePull      = 4,     -- settle: server lech dich >4 studs -> chay lai dong ho quiet
    ReleasePull     = 6,     -- release: lech >6 studs -> that bai, ve settle
    StuckSec        = 8,     -- khong tien gan dich trong 8s -> bo cuoc
    AlreadyThere    = 8,     -- gan hon 8 studs thi khong bay
    StreamTimeout   = 5,
    SnapLogGap      = 5,     -- gioi han dong WARN snap moi 5s (chong spam log)
    LogLinesPerPage = 26,    -- PART log day -> TU TAO PART MOI
    HudRefresh      = 0.25,
}
env.TweenLabCfg = CFG

-- danh sach dao (tur BF49 v5) ----------------------------------------------------
local destinations = {
    { "Port Town",          CFrame.new(-450.105, 113, 5950.726) },
    { "Hydra Island",       CFrame.new(5214.339, 1011, 759.507) },
    { "Great Tree",         CFrame.new(2485.733, 81, -6788.625) },
    { "Floating Turtle",    CFrame.new(-12549.724, 350, -7470.363) },
    { "Castle on the Sea",  CFrame.new(-4999.454, 326, -3010.54) },
    { "Haunted Castle",     CFrame.new(-9506.106, 149, 5526.041) },
    { "Peanut Land",        CFrame.new(-2025.785, 45, -10400.823) },
    { "Ice Cream Land",     CFrame.new(-819.377, 73, -10967.283) },
    { "Cake Land",          CFrame.new(-2022.299, 45, -12030.977) },
    { "Chocolate Land",     CFrame.new(231.75, 32, -12200.292) },
    { "Candy Cane Land",    CFrame.new(-1164.498, 68, -14492.618) },
    { "Tiki Outpost",       CFrame.new(-16228.08, 21, 446.065) },
    { "Submerged Island",   CFrame.new(11320.243, -2127, 9725.909) },
    { "Dragon Dojo",        CFrame.new(5704.413, 1178, 937.047) },
}

-- ══════════════════════════ DEBUG WALL TRONG WORKSPACE ══════════════════════
local dbgFolder = Instance.new("Folder")
dbgFolder.Name = "TweenLabDebug"
dbgFolder.Parent = workspace

local PAGE_W, PAGE_H = 24, 15
local hudLabel
local currentPage, currentLines = nil, 0

local function wallBase()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = root and root.Position or Vector3.zero
    return CFrame.lookAt(origin + Vector3.new(0, PAGE_H / 2 + 4, -20), origin)
end

local function makePage(name, idx)
    local cf = wallBase() * CFrame.new((idx % 3) * (PAGE_W + 2) - (PAGE_W + 2),
        math.floor(idx / 3) * -(PAGE_H + 2), 0)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = Vector3.new(PAGE_W, PAGE_H, 0.4)
    part.Material = Enum.Material.SmoothPlastic
    part.Color = Color3.fromRGB(12, 14, 18)
    part.Transparency = 0.15
    part.CFrame = cf
    part.Parent = dbgFolder

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextColor3 = Color3.fromRGB(160, 240, 160)
    label.Text = "-- PAGE " .. (idx + 1)
    label.Parent = gui
    return label, {}
end

local pageIndex = 0
local function newPage()
    pageIndex += 1
    local label, lines = makePage("LogPage_" .. pageIndex, pageIndex - 1)
    currentPage = { label = label, lines = lines }
    currentLines = 0
end

local function dbgLog(line)
    if not currentPage or currentLines >= CFG.LogLinesPerPage then
        newPage()                     -- PAGE DAY -> TU DONG TAO PART MOI
    end
    currentLines += 1
    table.insert(currentPage.lines, line)
    currentPage.label.Text = table.concat(currentPage.lines, "\n")
    if line:find("^RUN:") or line:find("^ERROR") or line:find("^WARN") or line:find("^START") then
        print("[TweenLab] " .. line)
    end
end

local function buildHud()
    local part = Instance.new("Part")
    part.Name = "TL_HUD"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Size = Vector3.new(22, 11, 0.4)
    part.Material = Enum.Material.SmoothPlastic
    part.Color = Color3.fromRGB(14, 18, 26)
    part.Transparency = 0.15
    part.CFrame = wallBase() * CFrame.new(-2, PAGE_H + 7, 2)
    part.Parent = dbgFolder

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.Parent = part

    hudLabel = Instance.new("TextLabel")
    hudLabel.Size = UDim2.new(1, 0, 1, 0)
    hudLabel.BackgroundTransparency = 1
    hudLabel.Font = Enum.Font.Code
    hudLabel.TextSize = 15
    hudLabel.TextXAlignment = Enum.TextXAlignment.Left
    hudLabel.TextYAlignment = Enum.TextYAlignment.Top
    hudLabel.TextColor3 = Color3.fromRGB(255, 210, 120)
    hudLabel.Text = "TWEENLAB v1.1 - idle"
    hudLabel.Parent = gui
end

buildHud()
newPage()
dbgLog("TWEENLAB v1.1 loaded " .. os.date("%H:%M:%S") .. " | FIX: khong con resync proxy khi bi keo")

-- ══════════════════════════ CORE MOVEMENT (BF49 v5) ════════════════════════
local movementId = 0
local currentMovement = nil
local fpsEma, lastFrameTime = nil, os.clock()
local status, screen, hudConn, toggleConn   -- gan o phan GUI, core doc truoc

RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local dt = now - lastFrameTime
    lastFrameTime = now
    if dt > 0 and dt < 0.5 then
        local fps = 1 / dt
        fpsEma = fpsEma and fpsEma * 0.95 + fps * 0.05 or fps
    end
end)

local function getCharacter()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    return character, root, humanoid
end

local function setVelocity(root, velocity)
    if not root or not root.Parent then return end
    root.AssemblyLinearVelocity = velocity
    root.AssemblyAngularVelocity = Vector3.zero
    pcall(function()
        root.Velocity = velocity
        root.RotVelocity = Vector3.zero
    end)
end

local function requestStreaming(position)
    local t0 = os.clock()
    task.spawn(function()
        pcall(function() player:RequestStreamAroundAsync(position, CFG.StreamTimeout) end)
    end)
    return (os.clock() - t0) * 1000
end

-- noclip: raycast theo huong bay, tat CanCollide vat can, tu tra lai sau 0.28s
local function restoreNoclip(data, force)
    if not data or not data.noclipParts then return end
    local now = os.clock()
    for part, info in pairs(data.noclipParts) do
        if not part or not part.Parent then
            data.noclipParts[part] = nil
        elseif force or now - info.seenAt > 0.28 then
            pcall(function() part.CanCollide = info.canCollide end)
            data.noclipParts[part] = nil
        end
    end
end

local function applyNoclip(data, fromPosition, toPosition)
    if not data or not data.rayParams or not data.root or not data.root.Parent then return end
    local motion = toPosition - fromPosition
    local distance = motion.Magnitude
    local now = os.clock()
    if distance <= 0.02 then
        restoreNoclip(data, false)
        return
    end
    local direction = motion.Unit
    local up = Vector3.new(0, 1, 0)
    local right = direction:Cross(up)
    if right.Magnitude < 0.05 then right = Vector3.new(1, 0, 0) else right = right.Unit end
    local offsets = { Vector3.zero, up * 1.55, up * -1.05, right * 1.75, right * -1.75 }
    local castVector = direction * (distance + 4.5)
    for _, offset in ipairs(offsets) do
        for _ = 1, 3 do
            local result = workspace:Raycast(fromPosition + offset, castVector, data.rayParams)
            if not result then break end
            local part = result.Instance
            if not part or not part:IsA("BasePart") or not part.Anchored or not part.CanCollide
                or part:IsDescendantOf(data.character) or dbgFolder:IsAncestorOf(part) then
                break
            end
            local normalY = math.abs(result.Normal.Y)
            if normalY >= 0.72 and direction.Y <= 0.35 then break end
            local info = data.noclipParts[part]
            if not info then
                info = { canCollide = part.CanCollide, seenAt = now }
                data.noclipParts[part] = info
                data.noclipCount = data.noclipCount + 1
            else
                info.seenAt = now
            end
            part.CanCollide = false
        end
    end
    restoreNoclip(data, false)
end

-- keo dich xuong mat dat (BF49 resolveTarget)
local function resolveTarget(character, root, humanoid, target)
    if target.Position.Y < -500 then return target end
    local parameters = RaycastParams.new()
    parameters.FilterType = Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances = { character, dbgFolder }
    parameters.IgnoreWater = true
    local result = workspace:Raycast(target.Position + Vector3.new(0, 45, 0), Vector3.new(0, -90, 0), parameters)
    if not result or result.Normal.Y < 0.55 then return target end
    local difference = target.Position.Y - result.Position.Y
    if difference < -4 or difference > 28 then return target end
    local rotation = target - target.Position
    local height = result.Position.Y + humanoid.HipHeight + root.Size.Y * 0.5 + 0.45
    return CFrame.new(target.Position.X, height, target.Position.Z) * rotation
end

local function cleanupMovement(data)
    if not data or data.cleaned then return end
    data.cleaned = true
    if data.tween then pcall(function() data.tween:Cancel() end) end
    if data.stepConnection then data.stepConnection:Disconnect() end
    if data.characterConnection then data.characterConnection:Disconnect() end
    restoreNoclip(data, true)
    if data.humanoid and data.humanoid.Parent then
        data.humanoid.AutoRotate = data.autoRotate
    end
    for _, instance in ipairs(data.instances or {}) do
        if instance and instance.Parent then instance:Destroy() end
    end
    if data.root and data.root.Parent then
        setVelocity(data.root, Vector3.zero)
        if data.humanoid and data.humanoid.Parent and data.humanoid.Health > 0 then
            pcall(function() data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end
    -- RUN SUMMARY de toi phan tich toi uu -------------------------------------
    local total = os.clock() - data.t0
    dbgLog(string.format(
        "RUN: %s | total=%.2fs stream=%.0fms corr=%d snaps=%d retry=%d dev=%.1f clip=%d fps=%.0f",
        tostring(data.outcome), total, data.streamMs, data.corrections, data.snaps,
        data.releaseRetries, data.maxDev, data.noclipCount, fpsEma or 0))
    dbgLog(string.format(
        "  phases travel=%.2f settle=%.2f release=%.2f | dist=%.0f rem=%.1f best=%.1f",
        data.pTravel or 0, data.pSettle or 0, data.pRelease or 0,
        data.distance or 0, data.lastRemaining or 0, data.bestRemaining or 0))
end

local function clearCurrentMovement()
    local data = currentMovement
    currentMovement = nil
    cleanupMovement(data)
end

local function forceStopMovement(showStatus)
    movementId += 1
    if currentMovement then currentMovement.outcome = "force-stopped" end
    clearCurrentMovement()
    if showStatus ~= false and status then
        status.Text = "Stopped | Speed " .. tostring(math.floor(env.TLSpeed))
        status.TextColor3 = Color3.fromRGB(235, 184, 115)
    end
end

-- STOP an toan: settle tai cho hien tai, khong teleport ve dich
local function stopMovement(showStatus)
    local data = currentMovement
    if not data or data.cleaned or not data.root or not data.root.Parent then
        forceStopMovement(showStatus)
        return
    end
    if data.stopRequested then return end
    data.stopRequested = true
    data.outcome = "stopped-safe"
    if data.tween then pcall(function() data.tween:Cancel() end) end
    local stopPosition = data.lastApplied or data.root.Position
    local stopCFrame = CFrame.new(stopPosition) * data.rotation
    data.target = stopCFrame
    data.phase = "settle"
    data.phaseStartedAt = os.clock()
    data.lastCorrectionAt = os.clock()
    data.lastProxyPosition = stopPosition
    data.lastApplied = stopPosition
    data.releaseRetries = 0
    if data.proxy and data.proxy.Parent then data.proxy.CFrame = stopCFrame end
    if data.stabilizer and data.stabilizer.Parent then
        data.stabilizer.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        data.stabilizer.Velocity = Vector3.zero
    end
    applyNoclip(data, data.root.Position, stopPosition)
    data.root.CFrame = stopCFrame
    setVelocity(data.root, Vector3.zero)
    if showStatus ~= false and status then
        status.Text = "Stopping safely..."
        status.TextColor3 = Color3.fromRGB(235, 184, 115)
    end
end

local function finishMovement(id, data, name, speed)
    if id ~= movementId or currentMovement ~= data or data.finishing then return end
    data.finishing = true
    if not data.outcome then data.outcome = data.stopRequested and "stopped-safe" or "arrived" end
    data.pRelease = os.clock() - (data.releaseEnteredAt or os.clock())
    currentMovement = nil
    cleanupMovement(data)
    if id == movementId and status then
        if data.stopRequested or data.outcome == "release-fail" then
            status.Text = "Stopped: " .. data.outcome .. " | Speed " .. tostring(speed)
            status.TextColor3 = Color3.fromRGB(235, 184, 115)
        else
            status.Text = "Arrived: " .. name .. " | Speed " .. tostring(speed)
            status.TextColor3 = Color3.fromRGB(167, 215, 178)
        end
    end
end

-- tao / tao lai tween proxy (luc khoi dong + khi doi speed giua chung)
local function launchProxyTween(data, speed)
    local remaining = (data.proxy.Position - data.target.Position).Magnitude
    if remaining <= 1 then return end
    if data.tween then pcall(function() data.tween:Cancel() end) end
    local tw = TweenService:Create(
        data.proxy,
        TweenInfo.new(math.max(remaining / speed, 0.05), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = data.target })
    data.tween = tw
    data.tweenSpeed = speed
    tw:Play()
end

-- ham tween chinh: proxy duoc TweenService bay toi dich, nhan vat chi bam theo
local function moveTo(name, rawTarget)
    forceStopMovement(false)  -- cancel cuoc di truoc (serial)

    local character, root, humanoid = getCharacter()
    if not character then
        dbgLog("ERROR: khong tim thay nhan vat")
        if status then status.Text = "Character not found" end
        return
    end

    movementId += 1
    local id = movementId
    local t0 = os.clock()
    local speed = math.clamp(tonumber(env.TLSpeed) or 325, 100, 500)

    local target = resolveTarget(character, root, humanoid, rawTarget)
    local distance = (root.Position - target.Position).Magnitude
    if distance <= CFG.AlreadyThere then
        dbgLog(string.format("%s: chi cach %.1f studs - bo qua", name, distance))
        if status then status.Text = name .. " qua gan (" .. math.floor(distance) .. " studs)" end
        return
    end

    local streamMs = requestStreaming(target.Position)  -- preload StreamingModule

    local proxy = Instance.new("Part")
    proxy.Name = "TLProxy"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanQuery = false
    proxy.CanTouch = false
    proxy.Transparency = 1
    proxy.Size = Vector3.new(1, 1, 1)
    proxy.CFrame = root.CFrame
    proxy.Parent = workspace

    local stabilizer = Instance.new("BodyVelocity")
    stabilizer.Name = "TLStab"
    stabilizer.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    stabilizer.P = 1000000
    stabilizer.Velocity = Vector3.zero
    stabilizer.Parent = root

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character, dbgFolder }
    rayParams.IgnoreWater = true
    pcall(function() rayParams.RespectCanCollide = true end)

    local rotation = target - target.Position
    local data = {
        id = id, name = name, character = character, root = root, humanoid = humanoid,
        proxy = proxy, stabilizer = stabilizer, rayParams = rayParams,
        target = target, rotation = rotation,
        t0 = t0, streamMs = streamMs, distance = distance,
        phase = "travel", phaseStartedAt = t0, lastCorrectionAt = t0,
        lastProxyPosition = root.Position, lastApplied = root.Position,
        noclipParts = {}, noclipCount = 0,
        corrections = 0, releaseRetries = 0, snaps = 0, maxDev = 0,
        bestRemaining = distance, lastNetAt = t0, lastSnapLogAt = 0,
        lastRemaining = distance, releaseEnteredAt = nil,
        stopRequested = false, autoRotate = humanoid.AutoRotate,
        instances = { proxy, stabilizer }, lastStatusAt = 0,
    }
    currentMovement = data

    humanoid.AutoRotate = false
    humanoid.Sit = false
    launchProxyTween(data, speed)
    dbgLog(string.format("START %s | dist=%.0f speed=%d stream=%.0fms", name, distance, speed, streamMs))
    if status then
        status.Text = "Tweening to " .. name .. "..."
        status.TextColor3 = Color3.fromRGB(140, 180, 255)
    end

    data.characterConnection = player.CharacterAdded:Connect(function()
        if id == movementId and currentMovement == data then
            forceStopMovement(false)
        end
    end)

    -- ══════ PHASE MACHINE ══════
    -- FIX v1.1: khi server keo nhan vat lai (chong teleport cua game),
    -- KHONG di chuy proxy theo nua - van tien theo proxy nhu BF49.
    -- (ban cu keo proxy ve vi tri server = vong lap "giat lai 200 studs" moi giay)
    data.stepConnection = RunService.PreSimulation:Connect(function(dt)
        if id ~= movementId or currentMovement ~= data or data.cleaned then return end
        if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then
            forceStopMovement(false)
            return
        end

        dt = math.clamp(dt or 0.016, 0.001, 0.1)
        local now = os.clock()
        local speed = env.TLSpeed  -- doc moi frame: doi speed giua chung hieu luc ngay

        local serverPos = root.Position       -- vi tri server tra ve (truoc khi ep)
        local proxyPos = data.proxy.Position

        -- do bi keo: lech giua cho ta dat frame truoc va cho server tra ve
        local push = (serverPos - data.lastApplied).Magnitude
        data.maxDev = math.max(data.maxDev, push)
        if push > CFG.PushSnap then
            data.snaps += 1
            if now - data.lastSnapLogAt >= CFG.SnapLogGap then
                data.lastSnapLogAt = now
                dbgLog(string.format("WARN server keo %.0f studs (lan %d) - van tien theo proxy", push, data.snaps))
            end
        end

        applyNoclip(data, serverPos, proxyPos)

        -- toc do = xich cua proxy / dt, cap speed*1.03 (BF49 stabilizer)
        local velocity = Vector3.zero
        if dt > 0 then
            velocity = (proxyPos - data.lastApplied) / dt
            local maxVel = speed * 1.03
            if velocity.Magnitude > maxVel then velocity = velocity.Unit * maxVel end
        end
        if data.stabilizer and data.stabilizer.Parent then
            data.stabilizer.Velocity = data.phase == "travel" and velocity or Vector3.zero
        end

        -- ep nhan vat theo proxy (cot loi phuong phap proxy)
        root.CFrame = CFrame.new(proxyPos) * data.rotation
        setVelocity(root, velocity)
        data.lastApplied = proxyPos

        local remaining = (proxyPos - data.target.Position).Magnitude   -- proxy con bao xa
        local srvOff = (serverPos - data.target.Position).Magnitude      -- server giu minh cach dich bao xa
        data.lastRemaining = remaining

        local quietFor = now - data.lastCorrectionAt
        local settleNeed = math.min(
            (data.stopRequested and CFG.SettleStopMin or CFG.SettleMin) + data.releaseRetries * 1.25, 7)
        local quietNeed = math.min(CFG.QuietNeed + data.releaseRetries * 1.1, 6)

        if data.phase == "travel" then
            if remaining <= 1.5 then
                data.phase = "settle"
                data.pTravel = now - data.t0
                data.phaseStartedAt = now
                data.lastCorrectionAt = now
                if data.tween then pcall(function() data.tween:Cancel() end) end
                data.proxy.CFrame = data.target
                setVelocity(root, Vector3.zero)
            else
                if push > CFG.PushSnap and now - data.lastCorrectionAt > 0.5 then
                    data.corrections += 1
                    data.lastCorrectionAt = now
                end
                -- watchdog: khong tien gan dich du => bi ket that
                if remaining < data.bestRemaining - 3 then
                    data.bestRemaining = remaining
                    data.lastNetAt = now
                elseif now - data.lastNetAt > CFG.StuckSec then
                    data.outcome = "stuck"
                    dbgLog(string.format("WARN khong tien duoc (%.0f studs con lai, %.1fs) - bo cuoc",
                        remaining, now - data.lastNetAt))
                    finishMovement(id, data, name, speed)
                    return
                end
            end

        elseif data.phase == "settle" then
            -- giu chat tai dich cho den khi "yen" du lau (KHONG tang retries moi frame - ban cu)
            root.CFrame = data.target
            setVelocity(root, Vector3.zero)
            if srvOff > CFG.SettlePull then
                data.lastCorrectionAt = now   -- chay lai dong ho quiet
            end
            if quietFor >= quietNeed and now - data.phaseStartedAt >= settleNeed then
                data.phase = "release"
                data.pSettle = now - data.phaseStartedAt
                data.phaseStartedAt = now
                data.releaseEnteredAt = now
                dbgLog(string.format("settle %.2fs (quiet %.2fs) -> release", data.pSettle, quietFor))
            end

        elseif data.phase == "release" then
            -- khong ep nua - xem server co giu minh o dich khong
            if srvOff > CFG.ReleasePull then
                data.releaseRetries += 1
                if data.releaseRetries > CFG.MaxReleaseRetry then
                    data.outcome = "release-fail"
                    dbgLog(string.format("WARN release that %d lan - dung cuoc tai day", data.releaseRetries))
                    finishMovement(id, data, name, speed)
                    return
                end
                data.phase = "settle"
                data.phaseStartedAt = now
                data.lastCorrectionAt = now
                data.proxy.CFrame = data.target
                root.CFrame = data.target
                dbgLog(string.format("WARN release bi keo %.1f studs -> settle lai (lan %d)",
                    srvOff, data.releaseRetries))
            elseif now - data.phaseStartedAt >= CFG.ReleaseConfirm then
                finishMovement(id, data, name, speed)
                return
            end
        end

        -- status label (throttle)
        if now - data.lastStatusAt >= CFG.HudRefresh then
            data.lastStatusAt = now
            if status and id == movementId then
                status.Text = string.format("%s | %.0f/%.0f studs | speed %d | %s",
                    name, remaining, data.distance, speed, data.phase)
            end
        end
    end)
end

-- doi speed truc tiep giua chung (nut GUI / textbox / API)
local speedButtons = {}
local speedBox
local function applySpeed(v)
    v = math.floor(math.clamp(tonumber(v) or 325, 100, 500))
    env.TLSpeed = v
    local data = currentMovement
    if data and not data.cleaned and data.phase == "travel" and not data.stopRequested then
        launchProxyTween(data, v)
        dbgLog(string.format("speed doi -> %d giua chung (con %.0f studs)", v, data.lastRemaining))
    end
    for _, btn in ipairs(speedButtons) do
        if btn:GetAttribute("SpeedValue") == v then
            btn.BackgroundColor3 = Color3.fromRGB(75, 110, 220)
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        end
    end
    if speedBox then speedBox.Text = tostring(v) end
    if status and not currentMovement then
        status.Text = "Idle | Speed " .. tostring(v)
    end
end

-- ══════════════════════════ GUI ═════════════════════════════════════════════
local function cleanupScript()
    forceStopMovement(false)
    if hudConn then pcall(function() hudConn:Disconnect() end) end
    if toggleConn then pcall(function() toggleConn:Disconnect() end) end
    if screen then pcall(function() screen:Destroy() end) end
    env.TweenLabCleanup = nil
    dbgLog("cleanup xong - debug wall van con trong Workspace de doc")
end
env.TweenLabCleanup = cleanupScript

local guiParent = (gethui and pcall(gethui)) and gethui() or CoreGui
screen = Instance.new("ScreenGui")
screen.Name = "TweenLabGUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screen.DisplayOrder = 999999 end)
screen.Parent = guiParent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 390, 0, 530)
main.Position = UDim2.new(0.5, -195, 0.5, -265)
main.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
main.BorderSizePixel = 0
main.Active = true
main.Parent = screen
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(230, 235, 245)
title.Text = "TWEENLAB v1.1"
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(70, 35, 40)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Text = "x"
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(cleanupScript)

-- keo tha cua so qua thanh title
local dragging, dragInput, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- hang toc do: preset | - | nhap tay | +
local speedRow = Instance.new("Frame")
speedRow.Size = UDim2.new(1, -20, 0, 36)
speedRow.Position = UDim2.new(0, 10, 0, 44)
speedRow.BackgroundTransparency = 1
speedRow.Parent = main

local function makeSpeedBtn(v, x)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.Position = UDim2.new(0, x, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(220, 225, 235)
    btn.Text = tostring(v)
    btn:SetAttribute("SpeedValue", v)   -- KHONG duoc gan btn.value (Instance khong co thuoc tinh nay)
    btn.Parent = speedRow
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() applySpeed(v) end)
    table.insert(speedButtons, btn)
    return btn
end
makeSpeedBtn(300, 0)
makeSpeedBtn(325, 78)
makeSpeedBtn(350, 156)

local function makeStepBtn(txt, x, w, delta)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, w, 1, 0)
    btn.Position = UDim2.new(0, x, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 18
    btn.TextColor3 = Color3.fromRGB(220, 225, 235)
    btn.Text = txt
    btn.Parent = speedRow
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() applySpeed(env.TLSpeed + delta) end)
    return btn
end
makeStepBtn("-", 234, 32, -10)

speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0, 66, 1, 0)
speedBox.Position = UDim2.new(0, 270, 0, 0)
speedBox.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
speedBox.PlaceholderText = "100-500"
speedBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
speedBox.Font = Enum.Font.Code
speedBox.TextSize = 15
speedBox.TextColor3 = Color3.fromRGB(220, 225, 235)
speedBox.Text = tostring(math.floor(env.TLSpeed))
speedBox.ClearTextOnFocus = false
speedBox.Parent = speedRow
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)
speedBox.FocusLost:Connect(function()          -- mat focus la ap dung (khong bat buoc Enter)
    local v = tonumber(speedBox.Text)
    if v then applySpeed(v) end
    speedBox.Text = tostring(math.floor(env.TLSpeed))
end)

makeStepBtn("+", 340, 30, 10)

-- nut STOP: settle an toan tai cho, khong teleport
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 126, 0, 40)
stopBtn.Position = UDim2.new(0.5, -63, 0, 88)
stopBtn.BackgroundColor3 = Color3.fromRGB(126, 50, 58)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 16
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Text = "STOP"
stopBtn.Parent = main
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
stopBtn.MouseButton1Click:Connect(function() stopMovement(true) end)

status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 22)
status.Position = UDim2.new(0, 10, 0, 134)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Code
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(220, 225, 235)
status.Text = "Idle | Speed " .. tostring(math.floor(env.TLSpeed))
status.Parent = main

-- danh sach dao: scrolling grid 2 cot
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -166)
scroll.Position = UDim2.new(0, 10, 0, 158)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(75, 110, 220)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -5, 0, 40)
grid.CellPadding = UDim2.new(0, 10, 0, 8)
grid.Parent = scroll

for _, entry in ipairs(destinations) do
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(220, 225, 235)
    btn.Text = entry[1]
    btn.Parent = scroll
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() moveTo(entry[1], entry[2]) end)
end

-- HUD part trong Workspace: cap nhat song song status
local hudLast = 0
hudConn = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - hudLast < CFG.HudRefresh then return end
    hudLast = now
    if not hudLabel then return end
    local data = currentMovement
    if data and not data.cleaned then
        hudLabel.Text = string.format(
            "TWEENLAB  %s\nphase=%s  speed=%d  rem=%.0f/%.0f\ncorr=%d snaps=%d retry=%d dev=%.1f clip=%d\nfps=%.0f  stream=%.0fms  t=%.1fs",
            data.name, data.phase, env.TLSpeed, data.lastRemaining, data.distance,
            data.corrections, data.snaps, data.releaseRetries, data.maxDev,
            data.noclipCount, fpsEma or 0, data.streamMs, now - data.t0)
    else
        hudLabel.Text = string.format("TWEENLAB v1.1  idle | speed=%d | RightControl = an/hien GUI", env.TLSpeed)
    end
end)

toggleConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        main.Visible = not main.Visible
    end
end)

-- API goi tu console / script khac
env.TweenLab = {
    Stop = function() stopMovement(true) end,
    ForceStop = function() forceStopMovement(true) end,
    Go = function(nameOrIndex)
        if type(nameOrIndex) == "number" and destinations[nameOrIndex] then
            return moveTo(destinations[nameOrIndex][1], destinations[nameOrIndex][2])
        end
        for _, entry in ipairs(destinations) do
            if entry[1]:lower() == tostring(nameOrIndex):lower() then
                return moveTo(entry[1], entry[2])
            end
        end
    end,
    Cleanup = cleanupScript,
    GetSpeed = function() return env.TLSpeed end,
    SetSpeed = function(v) applySpeed(v) end,
    Destinations = destinations,
}

applySpeed(env.TLSpeed)   -- highlight nut dung speed hien tai
dbgLog('API: TweenLab.Go("Hydra Island") / .Stop() / .SetSpeed(340) / .Cleanup()')
dbgLog("An nut dao de bay | STOP dung an toan | RightControl an/hien GUI")
dbgLog("BUG FIX: server keo lai thi VAN TIEN THEO PROXY (khong keo proxy lai nua)")
