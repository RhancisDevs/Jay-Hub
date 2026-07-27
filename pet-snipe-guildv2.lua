if not game:IsLoaded() then game.Loaded:Wait() end
local HUD = loadstring(game:HttpGet("https://raw.githubusercontent.com/RhancisDevs/jayhub-ui/main/statsv2.lua", true))()
HUD:Init()
task.wait(0.1)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
local PlayerState = require(game:GetService("ReplicatedStorage").ClientModules.PlayerStateClient)
local Gardens = workspace:WaitForChild("Gardens")
local RunService = game:GetService("RunService")
local PetData = require(game:GetService("ReplicatedStorage").SharedData.PetData)

local PetInfo = {}

for petName, data in pairs(PetData) do
    if type(data) == "table" then
        PetInfo[petName] = {
            Rarity = data.Rarity,
            BasePrice = data.BasePrice
        }
    end
end

local LOCAL_PLAYER = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local MAX_PAGES = 5
local TELEPORT_DELAY = 0.3
local HOP_DELAY = 1
local SERVER_FETCH_DELAY = 0.5
local CLAIM_TIMEOUT = 3
local FOLLOW_INTERVAL = 0.05
local WALKSPEED_BOOST = 9
local ARRIVAL_DISTANCE = 4
local BLOCK_ACTION = "JayHubBlockMovement"

local visitedJobIds = {}
local PET_TIMEOUT = 60
local petBuy = {}
local ROTATION_FILE = "jayhub-pet-joiner.json"
local LastHopMethod = nil
local LastAttemptedJobId = nil
local processedPets = {}  
local PendingPets = 0
local BoughtCount = 0
local AvailableServers = {}

local Settings = getgenv().Settings

local Rotation = {
    next_id = nil,
    past_id = {}
}

local Replica

repeat
    local ok, result = pcall(function()
        return PlayerState:GetLocalReplica()
    end)

    if ok and result then
        Replica = result
        break
    end

    task.wait(0.5)
until false

local function saveRotation()
    writefile(
        ROTATION_FILE,
        HttpService:JSONEncode(Rotation)
    )
end

local function loadRotation()
    if not isfile(ROTATION_FILE) then
        Rotation.next_id = Settings.job_id[1]
        Rotation.past_id = {}

        saveRotation()
        return
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(ROTATION_FILE))
    end)

    if not success or type(data) ~= "table" then
        Rotation.next_id = Settings.job_id[1]
        Rotation.past_id = {}

        saveRotation()
        return
    end

    Rotation.next_id = data.next_id or Settings.job_id[1]
    Rotation.past_id = data.past_id or {}
end

local function clearRotation()
    Rotation.next_id = Settings.job_id[1]
    Rotation.past_id = {}

    saveRotation()
end

local function getNextRotationId()
    if #Settings.job_id == 0 then
        return nil
    end

    if #Rotation.past_id >= #Settings.job_id then
        clearRotation()
    end

    local startIndex = 1

    for i, id in ipairs(Settings.job_id) do
        if id == Rotation.next_id then
            startIndex = i
            break
        end
    end

    for offset = 0, #Settings.job_id - 1 do
        local index = ((startIndex + offset - 1) % #Settings.job_id) + 1
        local id = Settings.job_id[index]

        if not table.find(Rotation.past_id, id) then
            return id, index
        end
    end

    clearRotation()

    return Settings.job_id[1], 1
end

local function advanceRotation(joinedId)
    if joinedId and not table.find(Rotation.past_id, joinedId) then
        table.insert(Rotation.past_id, joinedId)
    end

    local nextIndex = 1

    for i, id in ipairs(Settings.job_id) do
        if id == joinedId then
            nextIndex = i + 1
            break
        end
    end

    if nextIndex > #Settings.job_id then
        nextIndex = 1
    end

    Rotation.next_id = Settings.job_id[nextIndex]

    saveRotation()
end

loadRotation()

local rarity_priority = {
    "Super",
    "Mythic",
    "Legendary",
    "Rare",
    "Uncommon",
    "Common"
}

local Priority = {}

for index, rarity in ipairs(rarity_priority) do
    Priority[rarity] = index
end

local WILDPETREF = workspace.Map:WaitForChild("WildPetRef")

local function isMobile()
    return UserInputService.TouchEnabled
end

local function isPC()
    return UserInputService.KeyboardEnabled
        and UserInputService.MouseEnabled
        and not UserInputService.TouchEnabled
end

local function simulateTap()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local x = 35
    local y = viewport.Y - 35
    if isMobile() then
        pcall(function()
            VIM:SendTouchEvent(1, 0, x, y)
            task.wait(0.08)
            VIM:SendTouchEvent(1, 2, x, y)
        end)
    elseif isPC() then
        pcall(function()
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
    end
end

local function destroyIfExists(obj)
    if obj and obj.Parent then obj:Destroy() end
end

local function hidePlants(plot)
    if not plot:GetAttribute("Owner") then return end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return end
    for _, child in ipairs(plants:GetChildren()) do child:Destroy() end
    plants.ChildAdded:Connect(function(child)
        task.defer(function()
            if child and child.Parent then child:Destroy() end
        end)
    end)
end

local function destroyHeavyObjects()
    local map = workspace:FindFirstChild("Map")
    destroyIfExists(workspace:FindFirstChild("NPCS"))
    destroyIfExists(workspace:FindFirstChild("AuctionStand"))
    destroyIfExists(workspace:FindFirstChild("ExplorerStand"))
    if map then
        destroyIfExists(map:FindFirstChild("Stands"))
        destroyIfExists(map:FindFirstChild("Middle"))
    end
    for _, plot in ipairs(Gardens:GetChildren()) do destroyIfExists(plot) end
    Gardens.ChildAdded:Connect(function(plot)
        task.defer(function() destroyIfExists(plot) end)
    end)
end

if isMobile() then
    task.wait(4)
    destroyHeavyObjects()
else
    for _, plot in ipairs(Gardens:GetChildren()) do hidePlants(plot) end
    Gardens.ChildAdded:Connect(function(plot) task.wait(1) hidePlants(plot) end)

    task.spawn(function()
        repeat task.wait(0.5) until LOCAL_PLAYER:GetAttribute("LoadingScreenDone") == true
        destroyHeavyObjects()
    end)
end

repeat
    simulateTap()
    task.wait(1)
until not LOCAL_PLAYER:GetAttribute("LoadingScreenActive") or LOCAL_PLAYER:GetAttribute("LoadingScreenDone") == true

local p = game:GetService("Players").LocalPlayer
local c = p.Character or p.CharacterAdded:Wait()
local h = c:WaitForChild("Humanoid")
local r = c:WaitForChild("HumanoidRootPart")
local rs = game:GetService("RunService")

r.Anchored = false
r.CustomPhysicalProperties = PhysicalProperties.new(100, 0, 0, 100, 100)

local lastPos = r.Position
local lastCF = r.CFrame
local locked = false

local function block()
    p:SetAttribute("RagdollEndTime", nil)
    c:SetAttribute("RagdollEndTime", nil)
end

p.AttributeChanged:Connect(function(a)
    if a == "RagdollEndTime" then
        block()
    end
end)

c.AttributeChanged:Connect(function(a)
    if a == "RagdollEndTime" then
        block()
    end
end)

h.StateChanged:Connect(function(_, n)
    if n == Enum.HumanoidStateType.Physics
        or n == Enum.HumanoidStateType.Ragdoll
        or n == Enum.HumanoidStateType.FallingDown then
        h:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    end
end)

for _, m in pairs(c:GetDescendants()) do
    if m:IsA("Motor6D") then
        m:GetPropertyChangedSignal("Enabled"):Connect(function()
            if not m.Enabled then
                m.Enabled = true
            end
        end)
    end

    if m:IsA("BasePart") and m ~= r then
        m.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 100, 100)
    end
end

c.DescendantAdded:Connect(function(d)
    if d:IsA("BallSocketConstraint")
        or d:IsA("HingeConstraint")
        or d:IsA("BodyVelocity")
        or d:IsA("BodyForce")
        or d:IsA("BodyPosition")
        or d:IsA("BodyGyro")
        or d:IsA("BodyThrust")
        or d:IsA("BodyAngularVelocity") then
        d:Destroy()
    end
end)

rs.Heartbeat:Connect(function()
    for _, d in pairs(c:GetDescendants()) do
        if d:IsA("BodyVelocity")
            or d:IsA("BodyForce")
            or d:IsA("BodyPosition")
            or d:IsA("BodyGyro") then
            d:Destroy()
        end
    end

    local moving =
        h.MoveDirection.Magnitude > 0.1
        or h.Jump
        or Vector3.new(
            r.AssemblyLinearVelocity.X,
            0,
            r.AssemblyLinearVelocity.Z
        ).Magnitude > 2

    if moving then
        lastPos = r.Position
        lastCF = r.CFrame
        locked = false
    end

    local vel = r.AssemblyLinearVelocity

    if vel.Magnitude > 50 and not moving and not locked then
        r.CFrame = lastCF
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        locked = true

        task.delay(0.1, function()
            locked = false
        end)
    end
end)

r:GetPropertyChangedSignal("CFrame"):Connect(function()
    if locked then
        r.CFrame = lastCF
    end
end)

h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
h:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

block()

local AntiFling = {}

local antiFlingConn = nil
local lastSafeCFrame = nil

local MAX_VELOCITY = 80
local SAFE_VELOCITY = 40

function AntiFling.start()
    if antiFlingConn then
        return
    end

    antiFlingConn = RunService.PreSimulation:Connect(function()
        local character = LOCAL_PLAYER.Character
        if not character then
            return
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return
        end

        local velocity = hrp.AssemblyLinearVelocity
        local speed = velocity.Magnitude

        if speed < SAFE_VELOCITY then
            lastSafeCFrame = hrp.CFrame
        end

        if speed > MAX_VELOCITY then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero

            if lastSafeCFrame then
                hrp.CFrame = lastSafeCFrame
            end
        end
    end)
end

function AntiFling.stop()
    if antiFlingConn then
        antiFlingConn:Disconnect()
        antiFlingConn = nil
    end
end

AntiFling.start()

local function getCharacter()
    return LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
end

local HITBOX_SIZE = Vector3.new(15, 15, 15)
local DEFAULT_HRP_SIZE = Vector3.new(2, 2, 1)

local function expandCharacter(character)
    task.defer(function()
        if not character or not character.Parent then return end
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        hrp.Size = HITBOX_SIZE
        hrp.Transparency = 1
    end)
end

local function setupPlayer(player)
    if player == LOCAL_PLAYER then return end
    if player.Character then
        expandCharacter(player.Character)
    end
    player.CharacterAdded:Connect(expandCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

local function click(button)
    if not button then return false end
    local success = pcall(function()
        for _, connection in pairs(getconnections(button.Activated)) do connection:Fire() end
        for _, connection in pairs(getconnections(button.MouseButton1Down)) do connection:Fire() end
    end)
    return success
end

local function boostWalkSpeed()
    local character = getCharacter()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = humanoid.WalkSpeed + WALKSPEED_BOOST
end

local function resetWalkSpeed()
    local character = getCharacter()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    humanoid.WalkSpeed = humanoid.WalkSpeed - WALKSPEED_BOOST
end

local function autoTpMiddle()
    local button = LOCAL_PLAYER.PlayerGui
        :WaitForChild("TeleportButtons")
        :WaitForChild("TeleportButtons")
        :WaitForChild("SeedsButton")
    return click(button)
end

local function PublicHop()
    Networking.AntiAfk.RequestHop:Fire()
end

local function getGuild(maxRetries)
    maxRetries = maxRetries or 10

    for attempt = 1, maxRetries do
        local ok, result = pcall(function()
            return Networking.Guild.GetMyGuild:Fire()
        end)

        if ok
            and typeof(result) == "table"
            and typeof(result.Guild) == "table" then

            local myContribution = 0

            if typeof(result.GuildmateContribs) == "table" then
                for _, member in ipairs(result.GuildmateContribs) do
                    if member.userId == LOCAL_PLAYER.UserId then
                        myContribution = tonumber(member.shekels) or 0
                        break
                    end
                end
            end

            local guildPoints = tonumber(result.WeeklyShekels) or 0

            local currentRank = nil
            local pointsToNextRank = 0

            local success, leaderboard = pcall(function()
                return Networking.Guild.GetLeaderboard:Fire("weekly")
            end)

            if success and typeof(leaderboard) == "table" then
                currentRank = #leaderboard + 1

                for i, entry in ipairs(leaderboard) do
                    local score = tonumber(entry.shekels or entry.Shekels or entry.score) or 0

                    if guildPoints >= score then
                        currentRank = i

                        if i > 1 then
                            local above = leaderboard[i - 1]
                            local aboveScore = tonumber(
                                above.shekels or above.Shekels or above.score
                            ) or 0

                            pointsToNextRank = math.max(0, aboveScore - guildPoints + 1)
                        else
                            pointsToNextRank = 0
                        end

                        break
                    end
                end

                if currentRank == #leaderboard + 1 and #leaderboard > 0 then
                    local lastScore = tonumber(
                        leaderboard[#leaderboard].shekels
                        or leaderboard[#leaderboard].Shekels
                        or leaderboard[#leaderboard].score
                    ) or 0

                    pointsToNextRank = math.max(0, lastScore - guildPoints + 1)
                end
            end

            return {
                Guild = result.Guild,
                GuildId = result.Guild.GuildId,
                Name = result.Guild.Name,
                WeeklyShekels = guildPoints,
                MyContribution = myContribution,

                Rank = currentRank,
                PointsToNextRank = pointsToNextRank,
            }
        end

        warn(string.format(
            "[Guild] Attempt %d/%d failed.",
            attempt,
            maxRetries
        ))

        task.wait(1)
    end

    error("[Guild] Failed to retrieve guild after retries.")
end

LOCAL_PLAYER.SkillData.ShovelPower.Value = 9999999999

local function getHumanoidAndHRP()
    local character = getCharacter()
    return character:WaitForChild("Humanoid"), character:WaitForChild("HumanoidRootPart")
end

local function blockMovementInput()
    local keys = {
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
    }
    ContextActionService:BindAction(BLOCK_ACTION, function()
        return Enum.ContextActionResult.Sink
    end, false, table.unpack(keys))
end

local function unblockMovementInput()
    ContextActionService:UnbindAction(BLOCK_ACTION)
end

local function sellPet(petId)
    local ok, result = pcall(function()
        return Networking.NPCS.SellPet:Fire(petId)
    end)

    if not ok then
        warn("[SellPet]", result)
    end

    return ok
end

local function shouldSellPet(petName)
    local info = PetInfo[petName]
    if not info then
        return false
    end

    return Settings.drop_rarities[info.Rarity] == true
end

local knownPets = {}

repeat
    task.wait(0.2)
until Replica
    and Replica.Data
    and Replica.Data.Inventory
    and Replica.Data.Inventory.Pets

for uuid in pairs(Replica.Data.Inventory.Pets) do
    knownPets[uuid] = true
end

local function onNewPet(uuid, pet)
    local petName = pet.Name
    
    if shouldSellPet(petName) then
        print(string.format(
            "[Pet] Selling %s (%s)",
            petName,
            PetInfo[petName] and PetInfo[petName].Rarity or "Unknown"
        ))

        sellPet(uuid)

        task.wait(0.5)
    else
        print(string.format(
            "[Pet] Keeping %s (%s)",
            petName,
            PetInfo[petName] and PetInfo[petName].Rarity or "Unknown"
        ))
    end

    PendingPets = math.max(PendingPets - 1, 0)
    HUD:SetWaiting(PendingPets)
end   

Replica:OnChange(function(action, path)
    print("OnChange", action, table.concat(path, "."))

    if path[1] ~= "Inventory" then
        return
    end

    if path[2] ~= "Pets" then
        return
    end

    for uuid, pet in pairs(Replica.Data.Inventory.Pets) do
        if not knownPets[uuid] then
            knownPets[uuid] = true
            warn("NEW PET")
            warn(uuid)
            warn(pet.Name)
            onNewPet(uuid, pet)
        end
    end
end)

local function buyPet(ref)
    if not ref or not ref.Parent then
        return false
    end

    local ok, err = pcall(function()
        Networking.Pets.WildPetTame:Fire(ref)
    end)

    print("[BuyPet] Attempted to buy pet:", ref.Name, "Result:", ok, err)

    if not ok then
        warn("[BuyPet] WildPetTame failed:", err)
    end

    return ok
end

local function isNearPet(ref, maxDistance)
    if not ref or not ref.Parent then
        return false
    end

    maxDistance = maxDistance or 10

    local _, hrp = getHumanoidAndHRP()
    return (hrp.Position - ref.Position).Magnitude <= maxDistance
end

local function sendRequest(options)
    local ok, result = pcall(function()
        return (syn and syn.request or request)(options)
    end)
    if ok and result then return true, result.Body end
    return false, nil
end

local function jsonDecodeSafe(body)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    return ok and data or nil
end

local function getTargetCFrame(object)
    if object:IsA("Model") then
        return (object.PrimaryPart and object.PrimaryPart.CFrame) or object:GetModelCFrame()
    end
    return object.CFrame
end

local function isPetGone(ref)
    if not ref or not ref.Parent then return true end
    local lifetime = ref:GetAttribute("Lifetime")
    return lifetime ~= nil and lifetime <= 0
end

local function followPet(ref)
    local humanoid, hrp = getHumanoidAndHRP()

    while ref and ref.Parent and not isPetGone(ref) do
        if isNearPet(ref, 10) then
            break
        end

        local ok, cf = pcall(getTargetCFrame, ref)

        if ok and cf then
            local targetPos = (cf * CFrame.new(0, 0, 3)).Position

            if (hrp.Position - targetPos).Magnitude > ARRIVAL_DISTANCE then
                humanoid:MoveTo(targetPos)
            end
        end

        task.wait(FOLLOW_INTERVAL)
    end

    humanoid:MoveTo(hrp.Position)
end

local function isOwnedByMe(ref)
    return ref:GetAttribute("OwnerName") == LOCAL_PLAYER.Name
        and ref:GetAttribute("State") == "walking_to_garden"
end

local function GetMoney()
    Replica = Replica or PlayerState:GetLocalReplica()

    return (Replica and Replica.Data and Replica.Data.Sheckles) or 0
end

local function fetchServerPage(cursor)
    local url = string.format(
        "https://games.roblox.com/v1/games/%s/servers/Public?cursor=%s&sortOrder=Asc&excludeFullGames=true&orderBy=OccupancyAsc",
        PLACE_ID, cursor
    )
    local ok, body = sendRequest({ Url = url, Method = "GET" })
    if not ok or not body then return nil end
    return jsonDecodeSafe(body)
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function isValidServer(server)
    if not server
        or type(server.playing) ~= "number"
        or type(server.maxPlayers) ~= "number"
        or not server.id then
        return false
    end

    local id = tostring(server.id)

    return server.playing < server.maxPlayers
        and id ~= game.JobId
        and not visitedJobIds[id]
end

local function refillServers(maxPages)
    table.clear(AvailableServers)

    local cursor = ""

    for _ = 1, (maxPages or MAX_PAGES) do
        local data = fetchServerPage(cursor)
        if not data or not data.data then
            break
        end

        for _, server in ipairs(data.data) do
            if isValidServer(server) then
                table.insert(AvailableServers, server.id)
            end
        end

        if not data.nextPageCursor then
            break
        end

        cursor = data.nextPageCursor
        task.wait(SERVER_FETCH_DELAY)
        shuffle(AvailableServers)
    end
end

local function getRandomServer(maxPages)
    if #AvailableServers == 0 then
        refillServers(maxPages)
    end

    if #AvailableServers == 0 then
        return nil
    end

    return table.remove(AvailableServers)
end

local function jobIdHop()
    local jobId = getNextRotationId()

    if not jobId then
        warn("[JobIdHop] No JobIds configured.")
        return
    end

    LastHopMethod = "jobId"
    LastAttemptedJobId = jobId

    advanceRotation(jobId)

    print("[JobIdHop] Joining:", jobId)

    TeleportService:TeleportToPlaceInstance(
        PLACE_ID,
        jobId,
        LOCAL_PLAYER
    )
end

local Hop = {}

function Hop.toNewServer()
    if Settings.hop_method == "ps" then
        print("[Hop] Joining private server...")

        LastHopMethod = "ps"
        LastAttemptedJobId = nil

        LOCAL_PLAYER:Kick("REJOINING....")
        task.wait(1)

        TeleportService:Teleport(
            PLACE_ID,
            LOCAL_PLAYER
        )

        return
    end

    if Settings.hop_method == "psv2" then
        print("[Hop] Joining restricted server...")
        PublicHop()
        return
    end

    if Settings.hop_method == "public" then
        print("[Hop] Joining public server...")

        LastHopMethod = "public"
        LastAttemptedJobId = nil

        local jobId = getRandomServer(maxPages)

        if not jobId then
            warn("No valid server found.")
            return
        end

        visitedJobIds[jobId] = true

        TeleportService:TeleportToPlaceInstance(
            PLACE_ID,
            jobId,
            LOCAL_PLAYER
        )

        return
    end

    if Settings.hop_method == "jobId" then
        jobIdHop()
        return
    end

    warn("[Hop] Unknown hop method:", tostring(Settings.hop_method))
end

TeleportService.TeleportInitFailed:Connect(function(_, result)
    if result == Enum.TeleportResult.GameFull then
        warn("[Hop] Game is full.")
        
        if LastHopMethod == "jobId" and LastAttemptedJobId then
            task.wait(0.5)
            jobIdHop()
            return
        end

    else
        warn("[Hop] "..tostring(result))
    end

    task.wait(0.5)

    Hop.toNewServer()
end)

local function scanWildPetRef()
    local pets = {}

    for _, ref in ipairs(WILDPETREF:GetChildren()) do
        if not ref.Parent or isPetGone(ref) or isOwnedByMe(ref) then
            processedPets[ref] = nil
            continue
        end

        if processedPets[ref] then
            continue
        end

        local petName = ref:GetAttribute("PetName")
        if not petName then
            continue
        end

        local info = PetInfo[petName]
        if not info then
            continue
        end

        local price = ref:GetAttribute("Price")

        if price > GetMoney() then
            continue
        end

        local rank = Priority[info.Rarity]
        if not rank then
            continue
        end

        table.insert(pets, {
            Ref = ref,
            Name = petName,
            Rarity = info.Rarity,
            Rank = rank,
            Price = price
        })
    end

    table.sort(pets, function(a, b)
        if a.Rank ~= b.Rank then
            return a.Rank < b.Rank
        end

        return a.Price < b.Price
    end)

    print(string.format("[Scanner] Found %d eligible pets.", #pets))

    for _, pet in ipairs(pets) do
        print(string.format(
            "  • %s [%s] ($%s)",
            pet.Name,
            pet.Rarity,
            tostring(pet.Price)
        ))
    end

    return pets
end

HUD:SetGuild("TEST")
HUD:SetRank("TEST")
HUD:SetPointsToNextRank(1)
HUD:SetGuildPoints(1)
HUD:SetMyPoints(1)
HUD:SetHop(Settings.hop_method)

table.clear(petBuy)

while true do
    if not Settings.enable_pet_buy then
        HUD:SetStatus("Disabled")
        task.wait(1)
        continue
    end

    HUD:SetStatus("Teleporting to middle...")
    autoTpMiddle()
    task.wait(2.5)

    HUD:SetStatus("Scanning pets...")
    local pets = scanWildPetRef()

    PendingPets = 0

    HUD:SetWaiting(0)

    local boughtAny = false

    for _, pet in ipairs(pets) do

        HUD:SetStatus(("Following %s..."):format(pet.Name))
        followPet(pet.Ref)

        if pet.Ref.Parent
            and not isPetGone(pet.Ref)
            and isNearPet(pet.Ref, 10) then

            HUD:SetStatus(("Buying %s..."):format(pet.Name))

            if buyPet(pet.Ref) then
                PendingPets += 1
                HUD:SetWaiting(PendingPets)

                BoughtCount += 1
                HUD:SetBought(BoughtCount)

                processedPets[pet.Ref] = true
                boughtAny = true
            end

            task.wait(0.03)
        end
    end

    if boughtAny then
        HUD:SetStatus("Waiting for claimed pets...")

        local deadline = os.clock() + PET_TIMEOUT

        repeat
            HUD:SetWaiting(PendingPets)
            task.wait(0.1)
        until PendingPets <= 0 or os.clock() >= deadline

        if PendingPets > 0 then
            warn(string.format(
                "[PetBuy] Timed out waiting for %d pet(s).",
                PendingPets
            ))

            PendingPets = 0
            HUD:SetWaiting(0)
        end

        task.wait(0.5)
    end

    if Settings.hop_petbuy then
        HUD:SetStatus(("Hopping (%s)..."):format(Settings.hop_method))
        HUD:SetHop(Settings.hop_method)
        Hop.toNewServer()
    else
        HUD:SetStatus("Idle")
        HUD:SetHop("Disabled Hop")
        task.wait(1)
    end
end
