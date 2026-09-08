-- ==========================================
-- [ CONFIG AREA ]
-- ==========================================
getgenv().Team = "Pirates"
getgenv().Key = getgenv().Key or "NHAP_KEY_VAO_DAY"
getgenv().Settings = {
    ["Max Chests"] = 30;
    ["Reset After Collect Chests"] = 15;
}

-- ==========================================
-- [ EXECUTE LINKS - CHỈNH LINK Ở NGOÀI ]
-- Có thể set getgenv().EXECUTE_LINKS trước khi chạy file.
-- Link ngoài còn lại nếu không set thì giữ default cũ.
-- ==========================================
getgenv().EXECUTE_LINKS = getgenv().EXECUTE_LINKS or {}

getgenv().EXECUTE_LINKS.UltimaXRada =
    getgenv().EXECUTE_LINKS.UltimaXRada
    or "https://raw.githubusercontent.com/longvu26092007-eng/ml7/refs/heads/main/ultmiaxrada.lua"

local EXECUTE_LINKS = getgenv().EXECUTE_LINKS

-- ==========================================
-- [ HOP CONFIG - CHỈNH Ở ĐÂY ]
-- ==========================================
getgenv().HOP_CONFIG = {
    MaxPlayers    = 9,       -- Chỉ hop vào server < MaxPlayers người (nil = bỏ qua)
    ForcedRegion  = nil,     -- Ép region: "US", "EU", "AP" (nil = bỏ qua)
    MaxRetries    = 5,      -- Số lần thử tối đa
    RetryDelay    = 2,       -- Giây chờ giữa mỗi lần thử
    CacheDuration = 60,      -- Giây cache danh sách server
    MaxPages      = 100,     -- Số trang tối đa khi lấy danh sách server
}

-- Đổi folder sau khi Completed-melee.
-- id1/id2 bắt buộc, id3 optional.
getgenv().ChangeFolderOnCompleted = getgenv().ChangeFolderOnCompleted ~= false
getgenv().id1 = getgenv().id1 or "........."
getgenv().id2 = getgenv().id2 or "........."
-- Không set default cho id3. Nếu không dùng thì để nil thật:
-- getgenv().id3 = nil

-- ==========================================
-- [ GAME LOAD - Source_SG Style ]
-- ==========================================
if not game:IsLoaded() then game.Loaded:Wait() end
repeat task.wait(0.5) until game:IsLoaded()
    and game.Players.LocalPlayer
    and game.Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")

task.wait(1) -- chờ executor ổn định, tránh lỗi tab không load

getgenv().cloneref       = cloneref or clonereference or function(x) return x end
getgenv().isnetworkowner = isnetworkowner or isNetworkOwner or function() return true end
workspace = cloneref(workspace) or cloneref(Workspace)
    or (getrenv and (getrenv().workspace or getrenv().Workspace))
    or cloneref(game:GetService("Workspace"))
getfenv = getfenv or _G or _ENV or shared or function() return {} end

-- ==========================================
-- [ SERVICES & GLOBALS ]
-- ==========================================
RunService          = game:GetService("RunService")
TweenService        = game:GetService("TweenService")
HttpService         = game:GetService("HttpService")
Players             = game:GetService("Players")
ReplicatedStorage   = game:GetService("ReplicatedStorage")
Lighting            = game:GetService("Lighting")
CollectionService   = game:GetService("CollectionService")
UserInputService    = game:GetService("UserInputService")
VirtualInputManager = game:GetService("VirtualInputManager")
StarterGui          = game:GetService("StarterGui")
GuiService          = game:GetService("GuiService")
TeleportService     = game:GetService("TeleportService")

COMMF_      = ReplicatedStorage:WaitForChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("CommF_")
LocalPlayer = Players.LocalPlayer
PlaceId, JobId = game.PlaceId, game.JobId

LocalPlayer.CharacterAdded:Connect(function(v)
    Character        = v
    Humanoid         = v:WaitForChild("Humanoid")
    HumanoidRootPart = v:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    Character        = LocalPlayer.Character
    Humanoid         = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

local Player = LocalPlayer

local success, services = pcall(function()
    return {
        UserInputService = UserInputService,
        CoreGui          = game:GetService("CoreGui"),
        Players          = Players,
        CommF            = COMMF_
    }
end)
if not success then return end

-- ==========================================
-- [ FORCE TEAM - KATA COORDINATOR STYLE ]
-- 1 authority cho cả file + KAITUNBOSS nested source.
-- ==========================================
local function NormalizeTeam(value)
    local key = tostring(value or "Pirates")
        :lower()
        :gsub("[^%a]", "")

    if key == "marine" or key == "marines" then
        return "Marines"
    end

    return "Pirates"
end

local RequestedTeam = NormalizeTeam(getgenv().Team)
getgenv().Team = RequestedTeam

local function CurrentTeamName()
    return LocalPlayer.Team
        and tostring(LocalPlayer.Team.Name)
        or "NONE"
end

local function ClickRequestedTeamButton()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then
        return false
    end

    local main =
        pg:FindFirstChild("Main (minimal)")
        or pg:FindFirstChild("Main")

    if not main then
        for _, child in ipairs(pg:GetChildren()) do
            if child.Name:find("Main", 1, true) then
                main = child
                break
            end
        end
    end

    local choose =
        main
        and main:FindFirstChild("ChooseTeam", true)

    if not choose then
        choose = pg:FindFirstChild("ChooseTeam", true)
    end

    local container =
        choose
        and choose:FindFirstChild("Container")

    local teamFrame =
        container
        and container:FindFirstChild(RequestedTeam)

    if not teamFrame then
        return false
    end

    local function Activate(button)
        if not button
            or not button:IsA("GuiButton")
        then
            return false
        end

        return pcall(function()
            if type(firesignal) == "function" then
                firesignal(button.Activated)
            else
                button:Activate()
            end
        end)
    end

    if teamFrame:IsA("GuiButton")
        and Activate(teamFrame)
    then
        return true
    end

    for _, obj in ipairs(teamFrame:GetDescendants()) do
        if obj:IsA("GuiButton")
            and Activate(obj)
        then
            return true
        end
    end

    return false
end

local function EnsureTeam()
    if CurrentTeamName() == RequestedTeam then
        return true
    end

    for _ = 1, 20 do
        if CurrentTeamName() == RequestedTeam then
            return true
        end

        pcall(function()
            COMMF_:InvokeServer(
                "SetTeam",
                RequestedTeam
            )
        end)

        task.wait(0.35)

        if CurrentTeamName() == RequestedTeam then
            return true
        end

        pcall(ClickRequestedTeamButton)
        task.wait(0.35)
    end

    return CurrentTeamName() == RequestedTeam
end

-- HARD GATE: business logic không chạy nếu đang sai team.
while not EnsureTeam() do
    warn(
        "[TEAM] Force "
        .. RequestedTeam
        .. " chưa thành công -> retry"
    )
    task.wait(0.75)
end

repeat task.wait(0.25) until Character
    and Character:FindFirstChild("HumanoidRootPart")
    and Character:FindFirstChildWhichIsA("Humanoid")
    and Character:IsDescendantOf(workspace.Characters)

-- ==========================================
-- [ SOURCE_SG HELPER FUNCTIONS ]
-- ==========================================
function CheckSea(v) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end

local remoteAttack, idremote
local seed = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("seed"):InvokeServer()
task.spawn(function()
    for _, v in next, {ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX} do
        for _, n in next, v:GetChildren() do
            if n:IsA("RemoteEvent") and n:GetAttribute("Id") then
                remoteAttack, idremote = n, n:GetAttribute("Id")
            end
        end
        v.ChildAdded:Connect(function(n)
            if n:IsA("RemoteEvent") and n:GetAttribute("Id") then
                remoteAttack, idremote = n, n:GetAttribute("Id")
            end
        end)
    end
end)

CheckTool = function(v)
    for _, x in next, {LocalPlayer.Backpack, Character} do
        for _, v2 in next, x:GetChildren() do
            if v2:IsA("Tool") and (v2.Name == v or v2.Name:find(v)) then return true end
        end
    end
    return false
end

CheckMaterial = function(x)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
        if v.Type == "Material" then
            if v.Name == x then return v.Count end
        end
    end
    return 0
end

CheckInventory = function(...)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
        for _, n in next, {...} do
            if v.Name == n then return true end
        end
    end
    return false
end

CheckMonster = function(...) local args = {...}
    local containers = {workspace.Enemies, ReplicatedStorage}
    for i = 1, #args do local n = args[i]
        local m = workspace.Enemies:FindFirstChild(n) or ReplicatedStorage:FindFirstChild(n)
        if m and m:IsA("Model") and m.Name ~= "Blank Buddy" then
            local h = m:FindFirstChild("Humanoid") local r = m:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then return m end
        end
    end
    for c = 1, #containers do local container = containers[c] local ms = container:GetChildren()
        for m = 1, #ms do local m = ms[m] local h = m:FindFirstChild("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if m:IsA("Model") and h and r and h.Health > 0 and m.Name ~= "Blank Buddy" then
                for i = 1, #args do local n = args[i]
                    if m.Name == n or m.Name:lower():find(n:lower()) then return m end
                end
            end
        end
    end
    return false
end

EquipWeapon = function(v)
    if not Character then return end
    local tool = Character:FindFirstChildWhichIsA("Tool")
    if tool and (tool.ToolTip and tool.ToolTip == v) then return end
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") and x.ToolTip == v then
            Humanoid:EquipTool(x)
            return
        end
    end
end

local lastCallFA = tick()
FastAttack = function(x)
    if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid")
        or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
    local FAD = 0.01
    if FAD ~= 0 and tick() - lastCallFA <= FAD then return end
    local t = {}
    for _, e in next, workspace.Enemies:GetChildren() do
        local h = e:FindFirstChild("Humanoid") local hrp = e:FindFirstChild("HumanoidRootPart")
        if e ~= Character and (x and e.Name == x or not x) and h and hrp and h.Health > 0
            and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then
            t[#t + 1] = e
        end
    end
    local n = ReplicatedStorage.Modules.Net
    local h = {[2] = {}}
    for i = 1, #t do local v = t[i]
        local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
        if not h[1] then h[1] = part end
        h[2][#h[2] + 1] = {v, part}
    end
    n:FindFirstChild("RE/RegisterAttack"):FireServer()
    n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
    cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".", function(c)
        return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
    end), bit32.bxor(idremote+909090, seed*2), unpack(h))
    lastCallFA = tick()
end

-- ======================================================================
-- [ HOP SERVER - DRACO HUNTER V17.3 (NGUYÊN BẢN) ]
-- Chỉ dùng __ServerBrowser, giữ nguyên logic V17.3
-- ======================================================================
local function IfTableHaveIndex(j)
    for _ in j do
        return true
    end
end

local LastServersDataPulled, CachedServers

local function GetServers()
    if LastServersDataPulled then
        if os.time() - LastServersDataPulled < getgenv().HOP_CONFIG.CacheDuration then
            return CachedServers
        end
    end

    for i = 1, getgenv().HOP_CONFIG.MaxPages do
        local ok, data = pcall(function()
            return ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer(i)
        end)

        if ok and data and IfTableHaveIndex(data) then
            LastServersDataPulled = os.time()
            CachedServers = data
            return data
        end
    end

    warn("[HOP] Không lấy được danh sách server!")
    return nil
end

local function HopServer(Reason, MaxPlayers, ForcedRegion)
    -- Ưu tiên tham số truyền vào, nếu không thì lấy từ config
    MaxPlayers   = MaxPlayers   or getgenv().HOP_CONFIG.MaxPlayers
    ForcedRegion = ForcedRegion or getgenv().HOP_CONFIG.ForcedRegion

    local Servers = GetServers()
    if not Servers then
        warn("[HOP] Không có dữ liệu server, thử hop random bằng TeleportService...")
        TeleportService:Teleport(PlaceId, LocalPlayer)
        return
    end

    -- Chuyển dictionary → mảng, loại bỏ server hiện tại
    local ArrayServers = {}
    for id, v in Servers do
        if id ~= JobId then
            table.insert(ArrayServers, {
                JobId      = id,
                Players    = v.Count,
                LastUpdate = v.__LastUpdate,
                Region     = v.Region
            })
        end
    end

    print("[HOP] Nhận được", #ArrayServers, "servers")

    if #ArrayServers == 0 then
        warn("[HOP] Danh sách server rỗng, hop random...")
        TeleportService:Teleport(PlaceId, LocalPlayer)
        return
    end

    -- Lọc server theo điều kiện
    local FilteredServers = {}
    for _, server in ipairs(ArrayServers) do
        local passPlayers = true
        local passRegion  = true

        if MaxPlayers and server.Players >= MaxPlayers then
            passPlayers = false
        end

        if ForcedRegion and server.Region ~= ForcedRegion then
            passRegion = false
        end

        if passPlayers and passRegion then
            table.insert(FilteredServers, server)
        end
    end

    print("[HOP] Sau lọc:", #FilteredServers, "servers phù hợp",
        "(MaxPlayers <", tostring(MaxPlayers) .. ",",
        "Region:", tostring(ForcedRegion) .. ")")

    -- Nếu không có server nào phù hợp, nới lỏng điều kiện
    if #FilteredServers == 0 then
        warn("[HOP] Không có server nào khớp filter, thử bỏ filter region...")
        for _, server in ipairs(ArrayServers) do
            if not MaxPlayers or server.Players < MaxPlayers then
                table.insert(FilteredServers, server)
            end
        end
    end

    -- Vẫn không có → dùng toàn bộ
    if #FilteredServers == 0 then
        warn("[HOP] Vẫn không có server phù hợp, dùng toàn bộ danh sách...")
        FilteredServers = ArrayServers
    end

    -- Chọn random từ danh sách đã lọc
    local ServerData = FilteredServers[math.random(1, #FilteredServers)]

    print("[HOP] Đã chọn server:", ServerData.JobId,
        "| Players:", ServerData.Players,
        "| Region:", ServerData.Region)

    if Reason then
        print("[HOP] Lý do:", Reason)
    end

    -- Teleport bằng __ServerBrowser
    print("[HOP] Đang teleport đến", ServerData.JobId, "...")
    ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer('teleport', ServerData.JobId)
end

-- Gán global để BananaHub và script bên ngoài gọi được
getgenv().GetServers = GetServers
getgenv().HopServer  = HopServer

-- ==========================================
-- ERROR HANDLING V17.3 (GLOBAL - GIỮ NGUYÊN TỪ V17.2)
-- ==========================================
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
    if teleportResult == Enum.TeleportResult.GameFull then
        warn("[HOP] Server đầy, thử hop lại...")
        task.delay(2, function()
            HopServer("Retry - Server đầy")
        end)
    elseif teleportResult == Enum.TeleportResult.IsTeleporting
        and (message:find("previous teleport")) then
        StarterGui:SetCore("SendNotification", {
            Title    = "Death Hop Found",
            Text     = message,
            Duration = 8
        })
        task.delay(10, function() game:Shutdown() end)
    else
        warn("[HOP] Teleport thất bại:", tostring(teleportResult), message)
        task.delay(3, function()
            HopServer("Retry - Teleport fail")
        end)
    end
end)

GuiService.ErrorMessageChanged:Connect(newcclosure(function()
    if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
        while true do
            TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer)
            task.wait(5)
        end
    end
end))

-- ======================================================================
-- [ HẾT PHẦN HOP SERVER V17.3 ]
-- ======================================================================

local function getCFrame(v)
    if not v then return nil end
    if typeof(v) == "CFrame" then return v end
    if typeof(v) == "Vector3" then return CFrame.new(v) end
    if typeof(v) ~= "Instance" then return end
    if v:IsA("BasePart") then return v.CFrame end
    if v:IsA("Model") then
        if v.GetPivot then return v:GetPivot() end
        local root = v.PrimaryPart or v:FindFirstChild("HumanoidRootPart")
        if root then return root.CFrame end
    end
    if v:IsA("CFrameValue") then return v.Value end
    if v:IsA("Vector3Value") then return CFrame.new(v.Value) end
end

-- ======================================================================
-- [ TWEEN - KATA PROXY CORE | FIXED 150 STUDS/S ]
--
-- Giữ nguyên API cũ:
--   Tween(CFrame)
--   Tween(false)          -> cancel
--   Tween(CFrame, target)
--
-- Player target giữ offset +5 studs như Tween cũ.
-- target khác HRP giữ offset +30 studs như Tween cũ.
-- Không còn instant teleport <200.
-- Caller gọi liên tục sẽ RETARGET proxy, không bỏ lệnh vì isTweening=true.
-- ======================================================================
local TWEEN_SPEED = 150

local TWEEN_CFG = {
    ArriveDistance = 1.5,
    AlreadyThere = 2,
    SameTarget = 2.5,
    SettleMin = 0.65,
    QuietNeed = 0.35,
    SettlePull = 4,
    ReleaseConfirm = 0.35,
    ReleasePull = 7,
    MaxReleaseRetry = 3,
    StuckSec = 10,
    StreamTimeout = 5,
}

local _tweenSerial = 0
local _activeTweenMove = nil

local function TweenSetVelocity(root, velocity)
    if not root or not root.Parent then
        return
    end

    pcall(function()
        root.AssemblyLinearVelocity = velocity
        root.AssemblyAngularVelocity = Vector3.zero
    end)

    pcall(function()
        root.Velocity = velocity
        root.RotVelocity = Vector3.zero
    end)
end

local function TweenMovementLocked(char)
    if not char then
        return true
    end

    if char:FindFirstChild("AntiMover") then
        return true
    end

    local ok, tagged = pcall(function()
        return CollectionService:HasTag(
            char,
            "Teleporting"
        )
    end)

    return ok and tagged == true
end

local function CleanupTweenMove(data)
    if not data or data.cleaned then
        return
    end

    data.cleaned = true

    if data.proxyTween then
        pcall(function()
            data.proxyTween:Cancel()
        end)
    end

    if data.stepConnection then
        pcall(function()
            data.stepConnection:Disconnect()
        end)
    end

    if data.characterConnection then
        pcall(function()
            data.characterConnection:Disconnect()
        end)
    end

    if data.humanoid
        and data.humanoid.Parent
    then
        pcall(function()
            data.humanoid.AutoRotate =
                data.autoRotate
        end)
    end

    if data.stabilizer
        and data.stabilizer.Parent
    then
        pcall(function()
            data.stabilizer:Destroy()
        end)
    end

    if data.proxy
        and data.proxy.Parent
    then
        pcall(function()
            data.proxy:Destroy()
        end)
    end

    if data.root
        and data.root.Parent
    then
        TweenSetVelocity(
            data.root,
            Vector3.zero
        )
    end
end

local function CancelTweenCore()
    _tweenSerial += 1

    local old = _activeTweenMove
    _activeTweenMove = nil

    CleanupTweenMove(old)
end

local function LaunchProxyTween(data)
    if not data
        or data.cleaned
        or not data.proxy
        or not data.proxy.Parent
    then
        return
    end

    if data.proxyTween then
        pcall(function()
            data.proxyTween:Cancel()
        end)
    end

    local remaining =
        (
            data.proxy.Position
            - data.target.Position
        ).Magnitude

    if remaining <= TWEEN_CFG.ArriveDistance then
        data.proxy.CFrame = data.target
        return
    end

    data.proxyTween =
        TweenService:Create(
            data.proxy,
            TweenInfo.new(
                math.max(
                    remaining / TWEEN_SPEED,
                    0.05
                ),
                Enum.EasingStyle.Linear,
                Enum.EasingDirection.Out
            ),
            {
                CFrame = data.target
            }
        )

    data.proxyTween:Play()
end

local function BuildTweenTarget(targetCFrame, root, target)
    local offset =
        target ~= root
        and CFrame.new(0, 30, 0)
        or CFrame.new(0, 5, 0)

    return targetCFrame * offset
end

local function RetargetTween(data, newTarget)
    local changed =
        (
            data.target.Position
            - newTarget.Position
        ).Magnitude > TWEEN_CFG.SameTarget
        or (
            data.target.LookVector
            - newTarget.LookVector
        ).Magnitude > 0.05

    if not changed then
        return true
    end

    data.target = newTarget
    data.rotation =
        newTarget - newTarget.Position

    data.phase = "travel"
    data.phaseStartedAt = os.clock()
    data.lastCorrectionAt = os.clock()
    data.bestRemaining =
        (
            data.proxy.Position
            - newTarget.Position
        ).Magnitude
    data.lastProgressAt = os.clock()
    data.releaseRetries = 0

    task.spawn(function()
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(
                newTarget.Position,
                TWEEN_CFG.StreamTimeout
            )
        end)
    end)

    LaunchProxyTween(data)

    return true
end

local function StartPlayerTween(targetCFrame, target)
    local char =
        LocalPlayer
        and LocalPlayer.Character

    if not char then
        return false
    end

    local root =
        char:FindFirstChild("HumanoidRootPart")

    local humanoid =
        char:FindFirstChildOfClass("Humanoid")

    if not root
        or not humanoid
        or humanoid.Health <= 0
    then
        CancelTweenCore()
        return false
    end

    humanoid.Sit = false
    target = target or root

    -- Preserve old function semantics.
    -- Current script only passes root, but keep target support.
    if target ~= root then
        local cf = BuildTweenTarget(
            targetCFrame,
            root,
            target
        )

        local distance =
            (
                target.Position
                - cf.Position
            ).Magnitude

        local objectTween =
            TweenService:Create(
                target,
                TweenInfo.new(
                    math.max(
                        distance / TWEEN_SPEED,
                        0.05
                    ),
                    Enum.EasingStyle.Linear,
                    Enum.EasingDirection.Out
                ),
                {
                    CFrame = cf
                }
            )

        objectTween.Completed:Once(function()
            pcall(function()
                objectTween:Destroy()
            end)
        end)

        objectTween:Play()
        return objectTween
    end

    local desired =
        BuildTweenTarget(
            targetCFrame,
            root,
            target
        )

    if _activeTweenMove
        and not _activeTweenMove.cleaned
        and _activeTweenMove.character == char
        and _activeTweenMove.root == root
    then
        RetargetTween(
            _activeTweenMove,
            desired
        )
        return _activeTweenMove
    end

    CancelTweenCore()

    local distance =
        (
            root.Position
            - desired.Position
        ).Magnitude

    if distance <= TWEEN_CFG.AlreadyThere then
        return true
    end

    _tweenSerial += 1
    local id = _tweenSerial
    local now = os.clock()

    task.spawn(function()
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(
                desired.Position,
                TWEEN_CFG.StreamTimeout
            )
        end)
    end)

    local proxy = Instance.new("Part")
    proxy.Name = "SanguineKataMoveProxy"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanQuery = false
    proxy.CanTouch = false
    proxy.Transparency = 1
    proxy.Size = Vector3.new(1, 1, 1)
    proxy.CFrame = root.CFrame
    proxy.Parent = workspace

    local stabilizer = Instance.new("BodyVelocity")
    stabilizer.Name =
        "SanguineKataMoveStabilizer"
    stabilizer.MaxForce =
        Vector3.new(1e9, 1e9, 1e9)
    stabilizer.P = 1000000
    stabilizer.Velocity = Vector3.zero
    stabilizer.Parent = root

    local data = {
        id = id,
        character = char,
        root = root,
        humanoid = humanoid,

        proxy = proxy,
        stabilizer = stabilizer,

        target = desired,
        rotation =
            desired - desired.Position,

        phase = "travel",
        phaseStartedAt = now,
        lastCorrectionAt = now,

        lastApplied = root.Position,
        bestRemaining = distance,
        lastProgressAt = now,

        releaseRetries = 0,
        lockedSeen = false,
        autoRotate = humanoid.AutoRotate,
    }

    _activeTweenMove = data
    humanoid.AutoRotate = false

    LaunchProxyTween(data)

    data.characterConnection =
        LocalPlayer.CharacterAdded:Connect(function()
            if id == _tweenSerial
                and _activeTweenMove == data
            then
                CancelTweenCore()
            end
        end)

    data.stepConnection =
        RunService.PreSimulation:Connect(function(dt)
            if id ~= _tweenSerial
                or _activeTweenMove ~= data
                or data.cleaned
            then
                return
            end

            if not root.Parent
                or not humanoid.Parent
                or humanoid.Health <= 0
                or not proxy.Parent
            then
                CancelTweenCore()
                return
            end

            dt =
                math.clamp(
                    dt or 0.016,
                    0.001,
                    0.1
                )

            local nowFrame = os.clock()

            humanoid.Sit = false

            -- Character noclip while moving.
            for _, part in ipairs(
                char:GetDescendants()
            ) do
                if part:IsA("BasePart")
                    and part.CanCollide
                then
                    part.CanCollide = false
                end
            end

            -- Game/server teleport owns the character.
            if TweenMovementLocked(char) then
                if not data.lockedSeen then
                    data.lockedSeen = true

                    if data.proxyTween then
                        pcall(function()
                            data.proxyTween:Cancel()
                        end)
                    end
                end

                return
            end

            -- Resume from server-approved position after lock.
            if data.lockedSeen then
                data.lockedSeen = false

                local newPos = root.Position

                proxy.CFrame =
                    CFrame.new(newPos)
                    * data.rotation

                data.lastApplied = newPos
                data.bestRemaining =
                    (
                        newPos
                        - data.target.Position
                    ).Magnitude
                data.lastProgressAt =
                    nowFrame

                LaunchProxyTween(data)
            end

            local serverPos = root.Position
            local proxyPos = proxy.Position

            local remaining =
                (
                    proxyPos
                    - data.target.Position
                ).Magnitude

            local velocity =
                (
                    proxyPos
                    - data.lastApplied
                ) / dt

            local maxVelocity =
                TWEEN_SPEED * 1.03

            if velocity.Magnitude > maxVelocity then
                velocity =
                    velocity.Unit * maxVelocity
            end

            stabilizer.Velocity =
                data.phase == "travel"
                and velocity
                or Vector3.zero

            root.CFrame =
                CFrame.new(proxyPos)
                * data.rotation

            TweenSetVelocity(
                root,
                velocity
            )

            data.lastApplied = proxyPos

            if data.phase == "travel" then
                if remaining
                    <= TWEEN_CFG.ArriveDistance
                then
                    data.phase = "settle"
                    data.phaseStartedAt = nowFrame
                    data.lastCorrectionAt = nowFrame

                    if data.proxyTween then
                        pcall(function()
                            data.proxyTween:Cancel()
                        end)
                    end

                    proxy.CFrame = data.target
                    root.CFrame = data.target

                    TweenSetVelocity(
                        root,
                        Vector3.zero
                    )

                else
                    if remaining
                        < data.bestRemaining - 1
                    then
                        data.bestRemaining = remaining
                        data.lastProgressAt = nowFrame

                    elseif nowFrame
                            - data.lastProgressAt
                        > TWEEN_CFG.StuckSec
                    then
                        CancelTweenCore()
                        return
                    end
                end

            elseif data.phase == "settle" then
                proxy.CFrame = data.target
                root.CFrame = data.target

                TweenSetVelocity(
                    root,
                    Vector3.zero
                )

                local serverOff =
                    (
                        serverPos
                        - data.target.Position
                    ).Magnitude

                if serverOff
                    > TWEEN_CFG.SettlePull
                then
                    data.lastCorrectionAt = nowFrame
                end

                if nowFrame
                        - data.phaseStartedAt
                        >= TWEEN_CFG.SettleMin
                    and nowFrame
                        - data.lastCorrectionAt
                        >= TWEEN_CFG.QuietNeed
                then
                    data.phase = "release"
                    data.phaseStartedAt = nowFrame
                end

            elseif data.phase == "release" then
                local serverOff =
                    (
                        serverPos
                        - data.target.Position
                    ).Magnitude

                if serverOff
                    > TWEEN_CFG.ReleasePull
                then
                    data.releaseRetries += 1

                    if data.releaseRetries
                        > TWEEN_CFG.MaxReleaseRetry
                    then
                        CancelTweenCore()
                        return
                    end

                    data.phase = "settle"
                    data.phaseStartedAt = nowFrame
                    data.lastCorrectionAt = nowFrame

                    proxy.CFrame = data.target
                    root.CFrame = data.target

                elseif nowFrame
                        - data.phaseStartedAt
                        >= TWEEN_CFG.ReleaseConfirm
                then
                    CancelTweenCore()
                    return
                end
            end
        end)

    return data
end

Tween = function(targetCFrame, target)
    if targetCFrame == false then
        CancelTweenCore()
        return
    end

    targetCFrame = getCFrame(targetCFrame)

    if not targetCFrame then
        return false
    end

    return StartPlayerTween(
        targetCFrame,
        target
    )
end

BringMonster = function(name, count) count = count or 3
    if count < 2 then return end
    pcall(function() setscriptable(LocalPlayer, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge) end)
    xpcall(function()
        local mob, t = {}, nil
        for _, v in next, workspace.Enemies:GetChildren() do
            local h   = v:FindFirstChild("Humanoid")
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 and (not name or v.Name == name)
                and (HumanoidRootPart.Position - hrp.Position).Magnitude <= ((count or 3) * 250) then
                if not table.find(mob, function(chosen)
                    local chrp = chosen:FindFirstChild("HumanoidRootPart")
                    return chrp and (hrp.Position - chrp.Position).Magnitude <= 5
                end) then mob[#mob+1], t = v, t or hrp.CFrame
                end
                if #mob >= (count or 3) then break end
            end
        end
        if not t then return end
        for i = 1, #mob do
            local hrp = mob[i]:FindFirstChild("HumanoidRootPart")
            if hrp and (not isnetworkowner or isnetworkowner(hrp)) then
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = t * CFrame.new((i-1) * 2, 0, 0)
            end
        end
    end, function(r) warn("Modules Error [BM]: " .. r) end)
end

local lastKenCall = tick()
KillMonster = function(x)
    xpcall(function()
        if workspace.Enemies:FindFirstChild(x) then
            for _, v in next, workspace.Enemies:GetChildren() do
                local vh   = v:FindFirstChild("Humanoid")
                local vhrp = v:FindFirstChild("HumanoidRootPart")
                if vh and vh.Health > 0 and vhrp and v.Name == x then
                    local dx = HumanoidRootPart.Position.X - vhrp.Position.X
                    local dy = HumanoidRootPart.Position.Y - vhrp.Position.Y
                    local dz = HumanoidRootPart.Position.Z - vhrp.Position.Z
                    local sqrMag = dx*dx + dy*dy + dz*dz
                    if sqrMag <= 4900 then
                        BringMonster(x, 3)
                        FastAttack(x)
                        if tick() - lastKenCall >= 10 then
                            lastKenCall = tick()
                            ReplicatedStorage.Remotes.CommE:FireServer("Ken", true)
                        end
                        Tween(CFrame.new(vhrp.Position + (vhrp.CFrame.LookVector * 20) + Vector3.new(0, vhrp.Position.Y > 60 and -20 or 20, 0)))
                        EquipWeapon("Melee")
                        return
                    end
                    Tween(vhrp.CFrame) return
                end
            end
        end
        for _, v in next, ReplicatedStorage:GetChildren() do
            local vhrp = v:FindFirstChild("HumanoidRootPart")
            if v:IsA("Model") and vhrp and v.Name == x then Tween(vhrp.CFrame) return end
        end
    end, function(e) warn("Modules ERROR:", e) end)
end

local function GetInventory()
    local ok, inv = pcall(function() return COMMF_:InvokeServer("getInventory") end)
    if ok and type(inv) == "table" then return inv end
    return {}
end

local function GetMaterialCount(matName, inv)
    if not inv then inv = GetInventory() end
    for _, item in ipairs(inv) do
        if item.Name == matName then return item.Count end
    end
    return 0
end

-- ==========================================
-- [ UI (XANH DƯƠNG - ĐEN) ]
-- ==========================================
if services.CoreGui:FindFirstChild("VFAndSA_UI") then
    services.CoreGui.VFAndSA_UI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui", services.CoreGui)
ScreenGui.Name = "VFAndSA_UI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size             = UDim2.new(0, 300, 0, 175)
MainFrame.Position         = UDim2.new(0.5, -150, 0.5, -87)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MainFrame.Active           = true
MainFrame.Draggable        = true
Instance.new("UIStroke", MainFrame).Color        = Color3.fromRGB(0, 120, 255)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size                   = UDim2.new(1, 0, 0, 30)
Title.Text                   = "Sanguine Art Kaitun By Vu Nguyen"
Title.TextColor3             = Color3.fromRGB(0, 150, 255)
Title.BackgroundTransparency = 1
Title.Font                   = Enum.Font.GothamBold
Title.TextSize               = 14

local Line = Instance.new("Frame", MainFrame)
Line.Size             = UDim2.new(1, -20, 0, 1)
Line.Position         = UDim2.new(0, 10, 0, 30)
Line.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
Line.BorderSizePixel  = 0

local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size                   = UDim2.new(1, -20, 0, 20)
StatusLabel.Position               = UDim2.new(0, 10, 0, 34)
StatusLabel.Text                   = "Status: Checking..."
StatusLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font                   = Enum.Font.GothamSemibold
StatusLabel.TextSize               = 11
StatusLabel.TextXAlignment         = Enum.TextXAlignment.Left

local MeleeLabel = Instance.new("TextLabel", MainFrame)
MeleeLabel.Size                   = UDim2.new(1, -20, 0, 16)
MeleeLabel.Position               = UDim2.new(0, 10, 0, 54)
MeleeLabel.Text                   = "🥊 Melee: Checking..."
MeleeLabel.TextColor3             = Color3.fromRGB(0, 150, 255)
MeleeLabel.BackgroundTransparency = 1
MeleeLabel.Font                   = Enum.Font.GothamSemibold
MeleeLabel.TextSize               = 11
MeleeLabel.TextXAlignment         = Enum.TextXAlignment.Left

local MatFrame = Instance.new("Frame", MainFrame)
MatFrame.Size                   = UDim2.new(1, -20, 0, 78)
MatFrame.Position               = UDim2.new(0, 10, 0, 73)
MatFrame.BackgroundTransparency = 1
Instance.new("UIListLayout", MatFrame).Padding = UDim.new(0, 3)

local MaterialChecks = {
    {"Dark Fragment", 2},
    {"Vampire Fang",  20},
    {"Demonic Wisp",  20}
}

local matLabels = {}
for _, data in ipairs(MaterialChecks) do
    local l = Instance.new("TextLabel", MatFrame)
    l.Size                   = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text                   = "📦 " .. data[1] .. ": .../" .. data[2]
    l.TextColor3             = Color3.fromRGB(200, 200, 200)
    l.Font                   = Enum.Font.Gotham
    l.TextSize               = 11
    l.TextXAlignment         = Enum.TextXAlignment.Left
    matLabels[data[1]] = l
end

local fragL = Instance.new("TextLabel", MatFrame)
fragL.Size                   = UDim2.new(1, 0, 0, 16)
fragL.BackgroundTransparency = 1
fragL.Text                   = "💎 Fragment: .../5000"
fragL.TextColor3             = Color3.fromRGB(200, 200, 200)
fragL.Font                   = Enum.Font.Gotham
fragL.TextSize               = 11
fragL.TextXAlignment         = Enum.TextXAlignment.Left
matLabels["Fragment"] = fragL

local function UpdateMaterials()
    local inv = GetInventory()
    for _, data in ipairs(MaterialChecks) do
        local count = GetMaterialCount(data[1], inv)
        local label = matLabels[data[1]]
        if label then
            label.Text       = string.format("📦 %s: %d/%d", data[1], count, data[2])
            label.TextColor3 = (count >= data[2]) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(200, 200, 200)
        end
    end
    local fragCount = 0
    pcall(function() fragCount = Player.Data.Fragments.Value end)
    local fragLabel = matLabels["Fragment"]
    if fragLabel then
        fragLabel.Text       = string.format("💎 Fragment: %d/5000", fragCount)
        fragLabel.TextColor3 = (fragCount >= 5000) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(200, 200, 200)
    end
end

UpdateMaterials()
task.spawn(function()
    while task.wait(10) do UpdateMaterials() end
end)

services.UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.LeftAlt then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

StatusLabel.Text       = "Status: Checking Fragment..."
StatusLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
print("[VFAndSA P1] ✅ Loaded | LeftAlt ẩn/hiện")

-- ==========================================
-- CHECK FRAGMENT
-- ==========================================
local fragmentOk = false

task.spawn(function()
    local fragCount = 0
    pcall(function()
        fragCount = Player:FindFirstChild("Data")
            and Player.Data:FindFirstChild("Fragments")
            and Player.Data.Fragments.Value or 0
    end)

    print("[Fragment] Fragments: " .. fragCount .. "/5000")

    if fragCount >= 5000 then
        fragmentOk             = true
        StatusLabel.Text       = "Fragment: " .. fragCount .. "/5000 ✅"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        print("[Fragment] Đủ! Tiếp tục Phần 0...")
    else
        StatusLabel.Text       = "Fragment: " .. fragCount .. "/5000 → Farm Katakuri..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        print("[Fragment] Chưa đủ! Farm Katakuri...")

        task.spawn(function()
            while task.wait(15) do
                local currentFrag = 0
                pcall(function() currentFrag = Player.Data.Fragments.Value end)
                StatusLabel.Text = "Fragment: " .. currentFrag .. "/5000 | Farming..."
                if currentFrag >= 5000 then
                    StatusLabel.Text       = "Fragment: 5000 ✅ KICK!"
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                    print("[Fragment] Đủ 5000! Kick rejoin...")
                    task.wait(2)
                    Player:Kick("\n[ VFAndSA Kaitun ]\nĐã đủ 5000 Fragments!\nRejoin để tiếp tục.")
                    break
                end
            end
        end)

        task.spawn(function()
            getgenv().NewUI  = true
            getgenv().Config = {
                ["Select Method Farm"] = "Farm Katakuri",
                ["Hop Find Katakuri"]  = true,
                ["Start Farm"]         = true,
            }
            getgenv().__BANANA_SCRIPT_ROUTE = "bf_main"
            return loadstring(game:HttpGet("https://banana-hub.xyz/loader/banana.lua"))()
        end)

        return
    end
end)

repeat task.wait(1) until fragmentOk

-- ==========================================
-- PHẦN 0: CHECK SANGUINE ART STATUS
-- ==========================================
local saActive = false

task.spawn(function()
    local ok, result = pcall(function()
        return COMMF_:InvokeServer("BuySanguineArt", true)
    end)
    if ok then
        if type(result) == "string" and result:lower():find("bring me") then
            saActive               = false
            StatusLabel.Text       = "SA: ❌ Chưa active"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            print("[P0] Sanguine Art chưa active. Server:", result)
        else
            saActive               = true
            StatusLabel.Text       = "SA: ✅ Đã active! (" .. tostring(result) .. ")"
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            print("[P0] Sanguine Art đã active! Response:", tostring(result))
        end
    else
        StatusLabel.Text       = "SA: ⚠ Lỗi check"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        warn("[P0] Lỗi check SA:", tostring(result))
    end
end)

-- ==========================================
-- PHẦN 0.5: CHECK MELEE ĐANG EQUIP
-- ==========================================
local currentMelee = "None"

local function GetEquippedMelee()
    local char = Player.Character
    local bp   = Player:FindFirstChild("Backpack")
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == "Melee" then return tool.Name, true end
        end
    end
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == "Melee" then return tool.Name, false end
        end
    end
    return "None", false
end

task.spawn(function()
    task.wait(1)
    while true do
        local meleeName, isHolding = GetEquippedMelee()
        currentMelee = meleeName
        if meleeName ~= "None" then
            MeleeLabel.Text       = "🥊 Melee: " .. meleeName .. " (" .. (isHolding and "cầm" or "BP") .. ")"
            MeleeLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            MeleeLabel.Text       = "🥊 Melee: Không có"
            MeleeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
        task.wait(5)
    end
end)

-- ==========================================
-- HÀM GET SA (dùng chung cho cả 2 nhánh)
-- ==========================================

-- Lock tránh gọi ChangeToFolder nhiều lần khi flow có nhiều nhánh rẽ vào Completed-melee.
local CompletedFolderLock = false

-- Chuẩn hóa id1/id2/id3 trước khi truyền vào ChangeToFolder.
--   id1/id2 (allowNil=false): rỗng / placeholder / "nil" -> (nil, false) -> caller BỎ QUA.
--   id3 (allowNil=true):     rỗng / placeholder / "nil" -> (nil, true)  -> caller VẪN GỌI với nil thật.
local function NormalizeFolderId(value, allowNil)
    if value == nil then
        return nil, allowNil
    end

    local s = tostring(value)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")

    if s == "" or s == "........." or s:match("^%.+$") or s:lower() == "nil" then
        return nil, allowNil
    end

    return s, true
end

-- Đổi folder ngay sau khi ghi Completed-melee.
-- Không crash nếu thiếu client / id1 / id2; chỉ warn và skip.
local function ChangeFolderAfterCompleted(reason)
    if CompletedFolderLock then
        return false
    end

    if getgenv().ChangeFolderOnCompleted == false then
        warn("[Completed] ChangeFolderOnCompleted = false - bỏ qua đổi folder")
        return false
    end

    if not getgenv().client then
        warn("[Completed] getgenv().client chưa được set - bỏ qua đổi folder")
        return false
    end

    if typeof(getgenv().client.ChangeToFolder) ~= "function" then
        warn("[Completed] getgenv().client.ChangeToFolder không tồn tại - bỏ qua đổi folder")
        return false
    end

    local id1, ok1 = NormalizeFolderId(getgenv().id1, false)
    local id2, ok2 = NormalizeFolderId(getgenv().id2, false)
    local id3, ok3 = NormalizeFolderId(getgenv().id3, true)

    if not ok1 or not ok2 then
        warn("[Completed] id1/id2 bắt buộc nhưng đang rỗng - bỏ qua đổi folder")
        return false
    end

    CompletedFolderLock = true

    -- Log args trước khi gọi (chỉ để xem, id3 vẫn là nil thật khi truyền vào API).
    warn(("[Completed] %s -> ChangeToFolder args: id1=%s id2=%s id3=%s"):format(
        tostring(reason or "Completed"),
        tostring(id1),
        tostring(id2),
        id3 == nil and "nil" or tostring(id3)
    ))

    local ok, changed = pcall(function()
        return getgenv().client:ChangeToFolder(id1, id2, true, id3)
    end)

    if not ok then
        warn("[Completed] Lỗi khi gọi ChangeToFolder: " .. tostring(changed))
        CompletedFolderLock = false
        return false
    end

    if changed then
        warn("[Client] Successfully changed folder after completed, disconnecting to apply changes...")
        pcall(function()
            getgenv().client:Disconnect()
        end)
        task.wait(5)
        pcall(function()
            game:Shutdown()
        end)
        return true
    else
        warn("[Client] Failed to change folder after completed")
        task.wait(10)
        CompletedFolderLock = false
        return false
    end
end

-- ==========================================
-- [ EMBEDDED GETSA - thay hoàn toàn link gist cũ ]
--
-- Giữ nguyên logic của getSA cũ:
--   Sea 3 -> bay tới Shafi -> BuySanguineArt
--   Sea 2 -> TravelZou
--   Sea 1 -> TravelMain
--
-- Chỉ thay movement:
--   SafeTween cũ tự CFrame theo direction/300 -> dùng Tween Kata proxy 150
--   của file chính để không có 2 tween engine đánh nhau.
-- ==========================================
local GETSA_SHAFI_POS =
    CFrame.new(
        -16515.066,
        22.812,
        -188.573
    )

local GETSA_WORLD_1 = {
    [2753915549] = true,
    [85211729168715] = true,
}

local GETSA_WORLD_2 = {
    [4442272183] = true,
    [79091703265657] = true,
}

local GETSA_WORLD_3 = {
    [7449423635] = true,
    [100117331123089] = true,
}

local _embeddedGetSARunning = false

local function EmbeddedGetSASafeTween(targetCFrame)
    if typeof(targetCFrame) ~= "CFrame" then
        return false
    end

    local character =
        Player.Character
        or Player.CharacterAdded:Wait()

    local rootPart =
        character
        and character:FindFirstChild("HumanoidRootPart")

    local humanoid =
        character
        and character:FindFirstChildOfClass("Humanoid")

    if not rootPart
        or not humanoid
        or humanoid.Health <= 0
    then
        return false
    end

    -- Dùng 1 tween authority duy nhất của file:
    -- Kata proxy / fixed 150 studs/s.
    Tween(targetCFrame)

    local startDistance =
        (rootPart.Position - targetCFrame.Position).Magnitude

    local timeout =
        math.max(
            12,
            startDistance / TWEEN_SPEED + 12
        )

    local deadline =
        os.clock() + timeout

    while os.clock() < deadline do
        character = Player.Character
        rootPart =
            character
            and character:FindFirstChild("HumanoidRootPart")
        humanoid =
            character
            and character:FindFirstChildOfClass("Humanoid")

        if not rootPart
            or not humanoid
            or humanoid.Health <= 0
        then
            Tween(false)
            return false
        end

        local distance =
            (rootPart.Position - targetCFrame.Position).Magnitude

        -- Giữ đúng threshold của getSA cũ.
        if distance <= 7 then
            Tween(false)

            -- Chốt đúng tọa độ Shafi như code gist cũ,
            -- vì Tween chính giữ offset +5 để bảo toàn logic combat của file.
            pcall(function()
                rootPart.CFrame = targetCFrame
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end)

            return true
        end

        task.wait(0.05)
    end

    Tween(false)

    return rootPart
        and rootPart.Parent
        and (
            rootPart.Position
            - targetCFrame.Position
        ).Magnitude <= 7
end

local function RunEmbeddedGetSA()
    if _embeddedGetSARunning then
        return
    end

    _embeddedGetSARunning = true

    local ok, err = pcall(function()
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end

        local placeId =
            tonumber(game.PlaceId)

        if GETSA_WORLD_3[placeId] then
            print(
                "[Hệ Thống] Đang ở Sea 3. "
                .. "Bắt đầu bay đến Shafi..."
            )

            local arrived =
                EmbeddedGetSASafeTween(
                    GETSA_SHAFI_POS
                )

            if arrived then
                task.wait(0.5)

                pcall(function()
                    ReplicatedStorage
                        .Remotes
                        .CommF_
                        :InvokeServer(
                            "BuySanguineArt"
                        )
                end)
            else
                warn(
                    "[getSA] Không tới được Shafi, "
                    .. "sẽ để flow chính retry."
                )
            end

        elseif GETSA_WORLD_2[placeId] then
            print(
                "[Hệ Thống] Đang ở Sea 2. "
                .. "Đang di chuyển lên Sea 3..."
            )

            pcall(function()
                ReplicatedStorage
                    .Remotes
                    .CommF_
                    :InvokeServer(
                        "TravelZou"
                    )
            end)

        elseif GETSA_WORLD_1[placeId] then
            print(
                "[Hệ Thống] Đang ở Sea 1. "
                .. "Đang di chuyển lên Sea 2..."
            )

            -- Giữ NGUYÊN remote từ code getSA user cung cấp.
            pcall(function()
                ReplicatedStorage
                    .Remotes
                    .CommF_
                    :InvokeServer(
                        "TravelMain"
                    )
            end)

        else
            warn(
                "[Lỗi] Không nhận diện được Place ID!"
            )
        end
    end)

    _embeddedGetSARunning = false

    if not ok then
        warn(
            "[getSA embedded] Error: "
            .. tostring(err)
        )
    end
end

local function RunGetSA()
    print("[getSA] SA đã active! Check melee...")
    task.wait(2)

    if currentMelee == "Sanguine Art" then
        StatusLabel.Text       = "✅ Có SA! Ghi file..."
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        print("[getSA] Đang cầm Sanguine Art → Ghi file!")
        pcall(function() writefile(Player.Name .. ".txt", "Completed-melee") end)
        warn("[getSA] Đã ghi: " .. Player.Name .. ".txt → Completed-melee")
        StatusLabel.Text = "✅ Completed-melee!"
        ChangeFolderAfterCompleted("Completed-melee")
        return
    end

    StatusLabel.Text       = "SA Active → Chạy getSA..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    print("[getSA] Chưa cầm SA → Load getSA script...")

    task.spawn(function()
        RunEmbeddedGetSA()
    end)

    while true do
        task.wait(5)
        local meleeName = GetEquippedMelee()
        currentMelee = meleeName

        if meleeName == "Sanguine Art" then
            StatusLabel.Text       = "✅ Có SA! Ghi file..."
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            print("[getSA] Phát hiện Sanguine Art → Ghi file!")
            pcall(function() writefile(Player.Name .. ".txt", "Completed-melee") end)
            warn("[getSA] Đã ghi: " .. Player.Name .. ".txt → Completed-melee")
            StatusLabel.Text = "✅ Completed-melee!"
            ChangeFolderAfterCompleted("Completed-melee")
            break
        else
            StatusLabel.Text       = "Đợi SA... (" .. meleeName .. ")"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end
end

-- ==========================================
-- PHẦN 1: AUTOMATION
-- ==========================================
task.spawn(function()
    -- Đợi kết quả check SA xong
    repeat task.wait(1) until StatusLabel.Text:find("SA:") and not StatusLabel.Text:find("Checking")

    -- ====================================================
    -- NHÁNH A: SA đã active → chạy getSA ngay, không cần farm gì
    -- ====================================================
    if saActive then
        print("[P1] SA đã active ngay từ đầu → RunGetSA")
        RunGetSA()
        return
    end

    -- ====================================================
    -- NHÁNH B: SA chưa active → kiểm tra và farm nguyên liệu
    -- ====================================================
    print("[P1B] SA chưa active → Check nguyên liệu...")

    local inv     = GetInventory()
    local dfCount = GetMaterialCount("Dark Fragment", inv)

    if dfCount >= 2 then
        -- ==========================================
        -- PHẦN 1C: ĐỦ DF → CHECK VAMPIRE FANG
        -- ==========================================
        StatusLabel.Text       = "P1B: DF " .. dfCount .. "/1 ✅ → Tiếp..."
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        print("[P1B] Dark Fragment " .. dfCount .. "/1 → Đủ! Chuyển bước tiếp...")

        local vfCount = GetMaterialCount("Vampire Fang", inv)

        if vfCount >= 20 then
            StatusLabel.Text       = "P1C: VF " .. vfCount .. "/20 ✅ → P1D..."
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            print("[P1C] Vampire Fang " .. vfCount .. "/20 → Đủ! Chuyển P1D...")

            local dwCount = GetMaterialCount("Demonic Wisp", inv)

            if dwCount >= 20 then
                -- Đủ tất cả materials, SA vẫn chưa active → đợi
                StatusLabel.Text       = "P1D: DW " .. dwCount .. "/20 ✅ Đủ tất cả! Đợi SA..."
                StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                print("[P1D] Demonic Wisp đủ → Đủ tất cả! Đợi SA active...")

                -- Đợi SA active rồi getSA
                task.spawn(function()
                    while true do
                        task.wait(10)
                        local saOk, saResult = pcall(function()
                            return COMMF_:InvokeServer("BuySanguineArt", true)
                        end)
                        if saOk and type(saResult) ~= "string" then saActive = true
                        elseif saOk and type(saResult) == "string" and not saResult:lower():find("bring me") then saActive = true end

                        if saActive then
                            StatusLabel.Text       = "P1D: SA Active! → GetSA..."
                            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                            RunGetSA()
                            break
                        end
                    end
                end)
            else
                StatusLabel.Text       = "P1D: DW " .. dwCount .. "/20 → Farm..."
                StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                print("[P1D] Demonic Wisp " .. dwCount .. "/20 → Farm!")

                task.spawn(function()
                    loadstring(game:HttpGet(EXECUTE_LINKS.UltimaXRada))()
                end)
                task.wait(10)

                task.spawn(function()
                    getgenv().NewUI  = true
                    getgenv().Config = {
                        ["Select Material"] = "Demonic Wisp",
                        ["Farm Material"]   = true,
                        ["Start Farm"]      = true,
                        ["Hop Sever"]       = true
                    }
                    getgenv().__BANANA_SCRIPT_ROUTE = "bf_main"
            return loadstring(game:HttpGet("https://banana-hub.xyz/loader/banana.lua"))()
                end)

                task.spawn(function()
                    while true do
                        local checkInv  = GetInventory()
                        local currentDW = GetMaterialCount("Demonic Wisp", checkInv)
                        local currentVF = GetMaterialCount("Vampire Fang",  checkInv)
                        local currentDF = GetMaterialCount("Dark Fragment", checkInv)
                        StatusLabel.Text = string.format("P1D: DW %d/20 | VF %d/20 | DF %d/1", currentDW, currentVF, currentDF)

                        local saOk, saResult = pcall(function()
                            return COMMF_:InvokeServer("BuySanguineArt", true)
                        end)
                        if saOk and type(saResult) ~= "string" then saActive = true
                        elseif saOk and type(saResult) == "string" and not saResult:lower():find("bring me") then saActive = true end

                        if saActive then
                            StatusLabel.Text       = "P1D: SA Active! → GetSA..."
                            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                            warn("[P1D] SA đã active trong lúc farm! Chạy getSA...")
                            RunGetSA()
                            break
                        end

                        local meleeName = GetEquippedMelee()
                        currentMelee = meleeName
                        if meleeName ~= "None" then
                            MeleeLabel.Text       = "🥊 Melee: " .. meleeName
                            MeleeLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                        end
                        task.wait(15)
                    end
                end)
            end

        else
            StatusLabel.Text       = "P1C: VF " .. vfCount .. "/20 → Farm..."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
            print("[P1C] Vampire Fang " .. vfCount .. "/20 → Farm!")

            task.spawn(function()
                loadstring(game:HttpGet(EXECUTE_LINKS.UltimaXRada))()
            end)
            task.wait(10)

            task.spawn(function()
                while task.wait(10) do
                    local checkInv  = GetInventory()
                    local currentVF = GetMaterialCount("Vampire Fang", checkInv)
                    StatusLabel.Text = "P1C: VF " .. currentVF .. "/20 | Farming..."

                    local saOk, saResult = pcall(function()
                        return COMMF_:InvokeServer("BuySanguineArt", true)
                    end)
                    if saOk and type(saResult) ~= "string" then saActive = true
                    elseif saOk and type(saResult) == "string" and not saResult:lower():find("bring me") then saActive = true end

                    if saActive then
                        StatusLabel.Text       = "P1C: SA Active! → GetSA..."
                        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                        warn("[P1C] SA đã active trong lúc farm VF! Chạy getSA...")
                        RunGetSA()
                        break
                    end

                    if currentVF >= 20 then
                        StatusLabel.Text       = "P1C: VF 20/20 ✅ KICK!"
                        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                        task.wait(2)
                        Player:Kick("\n[ VFAndSA Kaitun ]\nĐã đủ 20/20 Vampire Fang!\nRejoin để tiếp tục.")
                        break
                    end
                end
            end)

            task.spawn(function()
                getgenv().NewUI  = true
                getgenv().Config = {
                    ["Select Material"] = "Vampire Fang",
                    ["Farm Material"]   = true,
                    ["Start Farm"]      = true,
                    ["Hop Sever"]       = true
                }
                getgenv().__BANANA_SCRIPT_ROUTE = "bf_main"
            return loadstring(game:HttpGet("https://banana-hub.xyz/loader/banana.lua"))()
            end)
        end

    else
        -- ==========================================
        -- PHẦN 1B: CHƯA ĐỦ DF → FARM DARKBEARD (Source_SG Full)
        -- ==========================================
        StatusLabel.Text       = "P1B: DF " .. dfCount .. "/1 → Farm Darkbeard..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        print("[P1B] Dark Fragment " .. dfCount .. "/1 → Chưa đủ, bật farm Darkbeard!")

        -- Monitor: kick khi đủ DF hoặc SA active → getSA
        -- + Watchdog: chống kẹt khi farm đủ chest nhưng hop fail
        local _lastHopAttempt = 0
        task.spawn(function()
            while task.wait(10) do
                local currentDF = CheckMaterial("Dark Fragment")
                StatusLabel.Text = "P1B: DF " .. currentDF .. "/1 | Farming Darkbeard..."

                local saOk, saResult = pcall(function()
                    return COMMF_:InvokeServer("BuySanguineArt", true)
                end)
                if saOk and type(saResult) ~= "string" then saActive = true
                elseif saOk and type(saResult) == "string" and not saResult:lower():find("bring me") then saActive = true end

                if saActive then
                    StatusLabel.Text       = "P1B: SA Active! → GetSA..."
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                    warn("[P1B] SA đã active trong lúc farm DF! Chạy getSA...")
                    RunGetSA()
                    break
                end

                if currentDF >= 2 then
                    StatusLabel.Text       = "P1B: DF 1/1 ✅ KICK!"
                    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                    print("[P1B] Dark Fragment đủ 2/2! Kick rejoin...")
                    task.wait(2)
                    Player:Kick("\n[ VFAndSA Kaitun ]\nĐã đủ 1/1 Dark Fragment!\nRejoin để tiếp tục.")
                    break
                end

                -- Watchdog: nếu đã farm đủ chest mà vẫn ở server cũ → force hop lại
                if getgenv().Settings and type(getgenv().Settings["Max Chests"]) == "number" then
                    local chestsDone = true
                    pcall(function()
                        local tagged = CollectionService:GetTagged("_ChestTagged")
                        local touchable = 0
                        for _, v in next, tagged do
                            if v and v.CanTouch then touchable = touchable + 1 end
                        end
                        if touchable > 3 then chestsDone = false end
                    end)
                    if chestsDone and not CheckTool("Fist of Darkness") and not CheckMonster("Darkbeard") then
                        if tick() - _lastHopAttempt > 30 then
                            _lastHopAttempt = tick()
                            warn("[Watchdog] Phát hiện kẹt server (hết chest, không có mob/item) → Force hop!")
                            StatusLabel.Text = "P1B: Watchdog → Force Hop..."
                            pcall(function() HopServer("Watchdog - stuck server") end)
                        end
                    end
                end
            end
        end)

        -- ==========================================
        -- KAITUNBOSS FULL SOURCE (NGUYÊN BẢN)
        -- ==========================================
        task.spawn(function()
            getgenv().Settings = {
                ["Max Chests"] = 50; -- if you collected 50 chests, hop server
                ["Reset After Collect Chests"] = 10; -- if you collected 10 chests, it will reset for safe (anti kick)
            };
            PlaceId, JobId = game.PlaceId, game.JobId
            RunService = game:GetService("RunService")
            TweenService = game:GetService("TweenService")
            HttpService = game:GetService("HttpService")
            Players = game:GetService("Players")
            ReplicatedStorage = game:GetService("ReplicatedStorage")
            Lighting = game:GetService("Lighting")
            CollectionService = game:GetService("CollectionService")
            UserInputService = game:GetService("UserInputService")
            VirtualInputManager = game:GetService("VirtualInputManager")
            StarterGui = game:GetService("StarterGui")
            GuiService = game:GetService("GuiService")
            TeleportService = game:GetService("TeleportService")
            COMMF_ = ReplicatedStorage:WaitForChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("CommF_")
            LocalPlayer = Players.LocalPlayer
            LocalPlayer.CharacterAdded:Connect(function(v)
                Character = v Humanoid = v:WaitForChild("Humanoid")
                HumanoidRootPart = v:WaitForChild("HumanoidRootPart")
            end)
            if LocalPlayer.Character then
                Character = LocalPlayer.Character
                Humanoid = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
                HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
            end

            StarterGui:SetCore("SendNotification", {Title = "Executed", Text = "Loading… Please wait", Duration = 5})
            if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
                task.wait(10 - workspace.DistributedGameTime)
            end
            if not COMMF_ then repeat task.wait(1) until COMMF_ end
            -- Reuse ForceTeam authority ở đầu file; không chạy lại Source_SG team cũ.
            while not EnsureTeam() do
                task.wait(0.75)
            end
            repeat task.wait(2) until Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChildWhichIsA("Humanoid") and Character:IsDescendantOf(workspace.Characters) -- workspace.CurrentCamera.CameraSubject, Players.CharacterAdded:Wait()
            function CheckSea(v: number) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end
            local remoteAttack, idremote
            local seed = ReplicatedStorage.Modules.Net.seed:InvokeServer()
            task.spawn((function() for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
                for _, n in next, v:GetChildren() do if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id") end
                end v.ChildAdded:Connect(function(n) if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id")
                end end) end
            end))
            print("file")
            CheckTool = (function(v)
                for _, x in next, {LocalPlayer.Backpack, Character} do
                for _, v2 in next, x:GetChildren() do if v2:IsA("Tool") and (v2.Name == v or v2.Name:find(v)) then return true end
                end end return false
            end)
            CheckMaterial = (function(x)
                for _, v in pairs(COMMF_:InvokeServer("getInventory")) do if v.Type == "Material" then if v.Name == x then return v.Count end end
                end return 0
            end)
            CheckInventory = (function(...)
                for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
                for _, n in next, {...} do if v.Name == n then return true end end
                end return false
            end)
            CheckMonster = (function(...) local args = {...}
                local v2 = {workspace.Enemies, ReplicatedStorage}
                for i = 1, #args do local n = args[i]
                    local m = workspace.Enemies:FindFirstChild(n) or ReplicatedStorage:FindFirstChild(n)
                    if m and m:IsA("Model") and m.Name ~= "Blank Buddy" then
                        local h = m:FindFirstChild("Humanoid") local r = m:FindFirstChild("HumanoidRootPart")
                        if h and r and h.Health > 0 then return m end
                    end
                end
                for c = 1, #v2 do local container = v2[c] local ms = container:GetChildren()
                    for m = 1, #ms do local m = ms[m] local h = m:FindFirstChild("Humanoid")
                        local r = m:FindFirstChild("HumanoidRootPart")
                        if m:IsA("Model") and h and r and h.Health > 0 and m.Name ~= "Blank Buddy" then
                            for i = 1, #args do local n = args[i]
                                if m.Name == n or m.Name:lower():find(n:lower()) then
                                    return m
                                end
                            end
                        end
                    end
                end
                return false
            end)

            EquipWeapon = (function(v)
                if not Character then return end
                local tool = Character:FindFirstChildWhichIsA("Tool")
                if tool and (tool.ToolTip and tool.ToolTip == v) then return end --((tool:GetAttribute("WeaponType") or "") == v
                for _, x in next, LocalPlayer.Backpack:GetChildren() do
                    if x:IsA("Tool") and x.ToolTip == v then
                        Humanoid:EquipTool(x)
                        return
                    end
                end
            end)

            local lastCallFA = tick()
            FastAttack = (function(x)
                if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid") or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
                local FAD = 0.01 -- throttle
                if FAD ~= 0 and tick() - lastCallFA <= FAD then return end
                local t = {}
                for _, e in next, workspace.Enemies:GetChildren() do
                    local h = e:FindFirstChild("Humanoid") local hrp = e:FindFirstChild("HumanoidRootPart")
                    if e ~= Character and (x and e.Name == x or not x) and h and hrp and h.Health > 0 and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then t[#t + 1] = e end
                end
                local n = ReplicatedStorage.Modules.Net
                local h = {[2] = {}}
                local last
                for i = 1, #t do local v = t[i]
                    local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
                    if not h[1] then h[1] = part end
                    h[2][#h[2] + 1] = {v, part} last = v
                end
                -- h[2][#h[2] + 1] = last
                n:FindFirstChild("RE/RegisterAttack"):FireServer()
                n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
                cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".",function(c)
                    return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
                end), bit32.bxor(idremote+909090, seed*2), unpack(h))
                lastCallFA = tick()
            end)
            print('func')
            function IfTableHaveIndex(j)
                for _ in j do
                    return true
                end
            end
            local LastServersDataPulled, CachedServers
            function GetServers()
                if LastServersDataPulled then
                    if os.time() - LastServersDataPulled < 60 then
                        return CachedServers
                    end
                end

                for i = 1, 100, 1 do
                    local data = game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer(i)
                    if IfTableHaveIndex(data) then
                        LastServersDataPulled = os.time()
                        CachedServers = data
                        return data
                    end
                end
            end
            HopServer = function(Reason, MaxPlayers, ForcedRegion)
                local Servers = GetServers()
                local ArrayServers = {}

                for i, v in Servers do
                    table.insert(ArrayServers, {
                        JobId = i,
                        Players = v.Count,
                        LastUpdate = v.__LastUpdate,
                        Region = v.Region
                    })
                end
                print(#ArrayServers, 'servers received')
                local ServerData
                for i = 1, #ArrayServers do
                    while task.wait() do
                        local Index = math.random(1, #ArrayServers)
                        ServerData = ArrayServers[Index]
                        if ServerData then
                            if not MaxPlayers or ServerData.Players < 5 then
                                if not ForcedRegion or ServerData.Regoin == ForcedRegion then
                                    print("Found Server:", ServerData.JobId, 'Player Count:', ServerData.Players, "Region:",
                                        ServerData.Region)
                                    break
                                end
                            end
                        end
                    end

                    print('Teleporting to', ServerData.JobId, '...')
                    game:GetService("ReplicatedStorage"):WaitForChild("__ServerBrowser"):InvokeServer('teleport', ServerData.JobId)
                end
            end
            -- Tween authority dùng chung ở đầu file:
            -- Kata proxy core 150 studs/s. KHÔNG override bằng tween cũ 250.

            local lastKenCall=tick() -- pray
            KillMonster=(function(x)
                xpcall(function()
                    if workspace.Enemies:FindFirstChild(x) then
                        for _,v in next,workspace.Enemies:GetChildren() do
                            local vh=v:FindFirstChild("Humanoid") local vhrp=v:FindFirstChild("HumanoidRootPart")
                            if vh and vh.Health > 0 and vhrp and v.Name==x then
                                local dx,dy,dz=HumanoidRootPart.Position.X-vhrp.Position.X, HumanoidRootPart.Position.Y-vhrp.Position.Y, HumanoidRootPart.Position.Z-vhrp.Position.Z
                                local sqrMag=dx*dx+dy*dy+dz*dz
                                if sqrMag<=4900 then
                                    FastAttack(x)
                                    if tick()-lastKenCall>=10 then lastKenCall=tick() ReplicatedStorage.Remotes.CommE:FireServer("Ken",true) end
                                    Tween(CFrame.new(vhrp.Position + (vhrp.CFrame.LookVector * 20) + Vector3.new(0, vhrp.Position.Y > 60 and -20 or 20, 0)))
                                    EquipWeapon("Melee")
                                    return
                                end
                                Tween(vhrp.CFrame) return
                            end
                        end
                    end
                    for _,v in next,ReplicatedStorage:GetChildren() do
                        local vhrp=v:FindFirstChild("HumanoidRootPart")
                        if v:IsA("Model") and vhrp and v.Name==x then Tween(vhrp.CFrame) return end
                    end
                end,function(e) warn("Modules ERROR:",e) end)
            end)
            local WorldsConfig = {
                ["1"] = "TravelMain",
                ["2"] = "TravelDressrosa",
                ["3"] = "TravelZou"
            }
            TeleportSea = function(sea, msg)
                local s = tostring(sea)
                local target = WorldsConfig[s]
                if not target then return end
                pcall(function() print(msg) end)
                COMMF_:InvokeServer(target)
            end
            PressKeyEvent = newcclosure(function(k, d)
                game:GetService("VirtualInputManager"):SendKeyEvent(true, k, false, game) task.wait(d or 0)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, k, false, game)
            end)
            local all = 0; FarmBeli = (function(x)
                if type(x) ~= "function" then warn("ddijt con me may") end
                local chests, c = {}, 0 local m = CollectionService:GetTagged("_ChestTagged")
                if all < getgenv().Settings["Max Chests"] and not CheckTool("Fist of Darkness") then
                    for _, v in next, CollectionService:GetTagged("_ChestTagged") do if v and v.CanTouch then local dist = (v.Position - HumanoidRootPart.Position).Magnitude table.insert(chests, {obj = v, dist = dist}) end end
                        table.sort(chests, function(a, b) return a.dist < b.dist end)
                        if not CheckTool("Fist of Darkness") then 
                            for i, t in next, chests do local v = t.obj
                                if v:IsA("BasePart") and v.Name:find("Chest") then
                                    if v.CanTouch then
                                        repeat task.wait()
                                            print("Collect Chests | Collected: " .. c.."/"..all .. "/"..getgenv().Settings["Max Chests"].." Chests")
                                            task.delay(2, function() v.CanTouch = false end)
                                            if Character and Character.Humanoid and Character.Humanoid.Health > 0 then
                                                Character:SetPrimaryPartCFrame(v.CFrame)
                                            end
                                            PressKeyEvent("Space")
                                        until not v.CanTouch or CheckTool("Fist of Darkness") c += 1 all += 1
                                        if all >= getgenv().Settings["Max Chests"] then print("Stopped: Max Chests reached") HopServer(8) break
                                        elseif CheckTool("Fist of Darkness") then print("Stopped: Fist of Darkness detected") break
                                        elseif CheckMonster("Darkbeard") then print("Stopped: Darkbeard nearby") HopServer(8) break
                                        end
                                        print(c, getgenv().Settings["Reset After Collect Chests"])
                                        if Character and c >= getgenv().Settings["Reset After Collect Chests"] and not CheckTool("Fist of Darkness") then
                                            if Character and Character:FindFirstChildWhichIsA("Humanoid")then
                                                Character:FindFirstChildWhichIsA("Humanoid"):ChangeState(Enum.HumanoidStateType.Dead)
                                                print("Collect Chests | Reset: Collected: "..tostring(getgenv().Settings["Reset After Collect Chests"]) .." Chests")
                                            end
                                            c = 0 task.wait(1)
                                        end
                                    end
                                    if i % 250 == 0 then task.wait(0.1) end
                                end
                            end
                        else
                            Tween(false)
                            print("Stopped: Found Special Item")
                        end
                    if not CheckTool("Fist of Darkness") and not CheckMonster("Darkbeard") then HopServer(10) end 
                end
            end)
            local hasLeviHeart = CheckInventory("Leviathan Heart")
            spawn(function()
                while task.wait(0.2) do
                    xpcall(function()
                        if CheckSea(2) then Tween(false)
                            if CheckMonster("Darkbeard") then
                                for _, v2 in next, {workspace.Enemies, ReplicatedStorage} do
                                    for _, v in next, v2:GetChildren() do
                                        if v.Name == "Darkbeard" then
                                            repeat task.wait() print("Killing Darkbeard\nHealth: ".. math.floor(v.Humanoid.Health / v.Humanoid.MaxHealth * 100).."%") KillMonster(v.Name)
                                            until not v or not v:FindFirstChild("Humanoid") or v.Humanoid.Health <= 0 Tween(false)
                                        end
                                    end
                                end
                            elseif CheckTool("Fist of Darkness") then local Detection = workspace.Map.DarkbeardArena.Summoner.Detection
                                Tween(false) print("Spawn Darkbeard\nTweening") Tween(Detection.CFrame)
                                if (HumanoidRootPart.Position - Detection.Position).Magnitude <= 200 then
                                    firetouchinterest(Detection, HumanoidRootPart, 0) task.wait(0.2)
                                    firetouchinterest(Detection, HumanoidRootPart, 1)
                                end
                            else
                                FarmBeli(function()
                                    return all >= getgenv().Settings["Max Chests"] or CheckTool("Fist of Darkness") or CheckTool("Darkbeard")
                                end)
                            end
                        else TeleportSea(2, "Travel to sea 2 for farm Dark Fragments")
                        end
                    end, function(err) warn(err) end)
                end
            end)

            task.spawn(function()
                while task.wait(4) do
                    xpcall(function()
                        if not Character.Humanoid or Character.Humanoid.Health <= 0 then
                            Tween(false)
                            return
                        end
                        if not Character:FindFirstChild("HasBuso") then COMMF_:InvokeServer("Buso") end
                        for _, v in next, {"Buso", "Geppo", "Soru"} do
                            if not CollectionService:HasTag(Character, v) then
                                if LocalPlayer.Data.Beli.Value >= ((function(t)
                                    return t == "Geppo" and 1e4 or t == "Buso" and 2.5e4 or t == "Soru" and 1e5 or 0
                                end)(v)) then print("Buy Abilies: ".. v) COMMF_:InvokeServer("BuyHaki", v)
                                end
                            end
                        end
                    end, function(err) warn("LL: ".. err) end)
                end
            end)
            TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
                if teleportResult == Enum.TeleportResult.GameFull then inHopPP = false
                elseif teleportResult == Enum.TeleportResult.IsTeleporting and (message:find("previous teleport")) then
                    StarterGui:SetCore("SendNotification", {Title = "Death Hop Found", Text = message, Duration = 8})
                    task.delay(10, function() game:Shutdown() end)
                end
                -- player.Name -- my LocalPlayer
                -- teleportResult -- Enum.TeleportResult
                -- message -- Request experience is full
            end)
            GuiService.ErrorMessageChanged:Connect(newcclosure(function()
                if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
                    while true do TeleportService:TeleportToPlaceInstance(PlaceId, JobId, LocalPlayer) task.wait(5) end
                end
            end))
        end)
    end
end)
