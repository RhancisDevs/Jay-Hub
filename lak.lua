local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", true))()

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local MESSAGE_INTERVAL = 30
local TOTAL_MINUTES_AT_BOOTH = 10
local MOVE_SPEED_ESTIMATE = 16
local MAX_PATH_RETRIES = 3
local MAX_PAGES = 10
local MAX_TELEPORT_RETRIES = 8

local visitedJobIds = {}
local teleportFails = 0
local placeId = game.PlaceId

local function safeNotify(opts)
    Fluent:Notify(opts)
end

local function sendRequest(params)
    local ok, res = pcall(function() return request(params) end)
    if not ok or not res then return false, nil end
    return true, (res.Body or res.body)
end

local function sendWebhook(data)
    local payload = HttpService:JSONEncode(data)
    for i = 1, 3 do
        local ok = pcall(function()
            request({Url = getgenv().webhook_Url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end)
        if ok then return true end
        task.wait(0.6 * i)
    end
    return false
end

local function getTime()
    local utc = os.time()
    return os.date("%I:%M:%S %p (%m/%d/%y)", utc)
end

local function jsonDecodeSafe(str)
    local ok, res = pcall(function() return HttpService:JSONDecode(str) end)
    if ok then return res end
    return nil
end

local function fetchThumbnail(userId)
    if not userId then return nil end
    local url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..tostring(userId).."&size=420x420&format=Png"
    local ok, body = sendRequest({Url = url, Method = "GET"})
    if not ok or not body then return nil end
    local data = jsonDecodeSafe(body)
    if data and data.data and data.data[1] and data.data[1].imageUrl then
        return data.data[1].imageUrl
    end
    return nil
end

local function getUserIdFromName(name)
    if not name or name == "" then return nil end
    local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
    if ok and id then return id end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name or p.DisplayName == name then return p.UserId end
    end
    return nil
end

local function getRandomServer(maxPages)
    local validServers = {}
    local cursor = ""
    local pagesChecked = 0
    while pagesChecked < (maxPages or MAX_PAGES) do
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?cursor=%s&sortOrder=Desc&limit=100", placeId, cursor)
        local ok, body = sendRequest({Url = url, Method = "GET"})
        if not ok or not body then break end
        local data = jsonDecodeSafe(body)
        if not data or not data.data then break end
        for _, server in ipairs(data.data) do
            if server.playing < (server.maxPlayers or 9999) and tostring(server.id) ~= tostring(game.JobId) and not visitedJobIds[tostring(server.id)] then
                table.insert(validServers, server.id)
            end
        end
        if not data.nextPageCursor then break end
        cursor = data.nextPageCursor
        pagesChecked += 1
        task.wait(0.3)
    end
    if #validServers > 0 then return validServers[math.random(1, #validServers)] end
    return nil
end

local function serverHop()
    safeNotify({Title="Server Hop",Content="Finding a new server...",Duration=4})
    local retries = 0
    while retries < 20 do
        local jobId = getRandomServer(MAX_PAGES)
        if not jobId then
            retries += 1
            task.wait(1)
        else
            if not visitedJobIds[tostring(jobId)] then
                visitedJobIds[tostring(jobId)] = true
                local ok = pcall(function() TeleportService:TeleportToPlaceInstance(placeId, jobId) end)
                if ok then return end
                retries += 1
                task.wait(1)
            else
                retries += 1
            end
        end
    end
    pcall(function() TeleportService:Teleport(placeId) end)
end

TeleportService.TeleportInitFailed:Connect(function(_, result)
    teleportFails += 1
    if result == Enum.TeleportResult.Unauthorized then
        visitedJobIds[tostring(game.JobId)] = true
    end
    if teleportFails >= MAX_TELEPORT_RETRIES then
        teleportFails = 0
        task.wait(2)
        pcall(function() TeleportService:Teleport(placeId) end)
    else
        task.wait(2)
        serverHop()
    end
end)

local function moveToCFrame(cf)
    if not cf then return false end
    local targetPos = (typeof(cf)=="CFrame") and cf.Position or cf
    local retries = 0
    while retries < MAX_PATH_RETRIES do
        local ok, path = pcall(function()
            local p = PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,MinSmoothDistance=0})
            p:Compute(targetPos)
            return p
        end)
        if not ok or not path or path.Status ~= Enum.PathStatus.Success then
            retries += 1
            task.wait(0.5)
        else
            for _, wp in ipairs(path:GetWaypoints()) do
                if not hrp or not hrp.Parent then return false end
                local dest = wp.Position
                if wp.Action == Enum.PathWaypointAction.Jump then dest = dest + Vector3.new(0,3,0) end
                local dist = (hrp.Position - dest).Magnitude
                local t = math.max(0.1, dist / MOVE_SPEED_ESTIMATE)
                local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = CFrame.new(dest)})
                tw:Play()
                pcall(function() tw.Completed:Wait() end)
                task.wait(0.02)
            end
            local fdist = (hrp.Position - targetPos).Magnitude
            if fdist > 2 then
                local t2 = math.max(0.1, fdist / MOVE_SPEED_ESTIMATE)
                local tw2 = TweenService:Create(hrp, TweenInfo.new(t2, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos + Vector3.new(0,2,0))})
                tw2:Play()
                pcall(function() tw2.Completed:Wait() end)
            end
            return true
        end
    end
    if character.PrimaryPart then
        pcall(function() character:SetPrimaryPartCFrame(CFrame.new(targetPos + Vector3.new(0,2,0))) end)
        return true
    end
    return false
end

local function findUnclaimedBooth()
    local root = workspace:FindFirstChild("TradeWorld")
    if not root then return nil end
    local booths = root:FindFirstChild("Booths")
    if not booths then return nil end
    for _, model in ipairs(booths:GetChildren()) do
        local val = nil
        pcall(function()
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text == "Unclaimed Booth" then
                    val = "Unclaimed Booth"
                    break
                end
            end
        end)
        if val == "Unclaimed Booth" then return model end
    end
    return nil
end

local function boothCFrameFromModel(m)
    if not m then return nil end
    local ok, cf = pcall(function()
        return m:GetPivot()
    end)
    if ok and cf then return cf end
    return nil
end

local function runEquipBoothSkin()
    local r = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeBoothSkinService"):WaitForChild("Equip")
    if r then r:FireServer(getgenv().boothSkin) end
    task.wait(0.15)
end

local function claimBooth(b)
    if not b then return false end
    runEquipBoothSkin()
    local r = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("Booths"):WaitForChild("ClaimBooth")
    if r then
        local ok = pcall(function() r:FireServer(b) end)
        return ok
    end
    return false
end

local function autoListItemsIfNeeded(knownBooth)
    print("[AutoList] start")
    local createRem = nil
    local okRem = pcall(function()
        createRem = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("Booths"):WaitForChild("CreateListing")
    end)
    if not createRem then
        print("[AutoList] CreateListing remote missing")
        return
    end
    local DataServiceModule = nil
    pcall(function()
        DataServiceModule = require(ReplicatedStorage.Modules.DataService)
    end)
    local function getPetData(id)
        if not DataServiceModule then return nil end
        local ok, data = pcall(function() return DataServiceModule:GetData() end)
        if not ok or not data then return nil end
        local base = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
        if base and base[id] then return base[id].PetType end
        return nil
    end
    local function findPlayerBoothExact()
        local tw = workspace:FindFirstChild("TradeWorld")
        if not tw then return nil end
        local booths = tw:FindFirstChild("Booths")
        if not booths then return nil end
        local n1 = "@"..LocalPlayer.Name.."'s Booth"
        local n2 = "@"..(LocalPlayer.DisplayName or "").."'s Booth"
        for _, b in ipairs(booths:GetChildren()) do
            local skin = b:FindFirstChild(getgenv().boothSkin)
            if skin then
                local sign = skin:FindFirstChild("Sign")
                if sign then
                    local sg = sign:FindFirstChild("SurfaceGui")
                    if sg then
                        local tl = sg:FindFirstChild("TextLabel")
                        if tl and (tl.Text == n1 or tl.Text == n2) then
                            return b
                        end
                    end
                end
            end
        end
        return nil
    end
    local function waitForPlayerBooth(maxWait)
        local t0 = tick()
        while tick() - t0 < (maxWait or 10) do
            if knownBooth and knownBooth.Parent then
                return knownBooth
            end
            local found = findPlayerBoothExact()
            if found then return found end
            task.wait(0.5)
        end
        return nil
    end
    task.spawn(function()
        print("[AutoList] loop spawned")
        local backpack = LocalPlayer:WaitForChild("Backpack")
        while true do
            local booth = waitForPlayerBooth(10)
            if not booth then
                print("[AutoList] booth not found, retrying in 3s")
                task.wait(3)
            else
                local dyn = booth:FindFirstChild("DynamicInstances")
                local dynNames = {}
                local dynCount = 0
                if dyn then
                    for _, child in ipairs(dyn:GetChildren()) do
                        if child and child.Name then dynNames[tostring(child.Name)] = true end
                    end
                    dynCount = #dyn:GetChildren()
                end
                print("[AutoList] dynCount:", dynCount)
                if dynCount >= 50 then
                    print("[AutoList] DynamicInstances full (>=50). Stopping auto-list.")
                    break
                end
                local eligible = {}
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool and tool.GetAttribute and tool:GetAttribute("ItemType") ~= nil and tool:GetAttribute("d") ~= true then
                        local uuid = tool:GetAttribute("PET_UUID")
                        if uuid and not dynNames[tostring(uuid)] then
                            local pt = getPetData(uuid)
                            if pt and table.find(getgenv().petToList, pt) then
                                table.insert(eligible, { uuid = tostring(uuid), petType = pt })
                            end
                        end
                    end
                end
                print("[AutoList] eligible:", #eligible)
                if #eligible == 0 then
                    print("[AutoList] none eligible, stopping")
                    break
                end
                local anyListed = false
                for _, pet in ipairs(eligible) do
                    local boothNow = waitForPlayerBooth(3)
                    if not boothNow then
                        print("[AutoList] booth disappeared during listing, aborting pass")
                        break
                    end
                    local dynNow = boothNow:FindFirstChild("DynamicInstances")
                    if dynNow and #dynNow:GetChildren() >= 50 then
                        print("[AutoList] DynamicInstances reached 50 during listing, stopping")
                        break
                    end
                    print("[AutoList] listing:", pet.uuid, pet.petType)
                    local args = {"Pet", pet.uuid, getgenv().priceForPetList}
                    local ok = pcall(function() createRem:InvokeServer(unpack(args)) end)
                    print("[AutoList] result:", ok)
                    if ok then anyListed = true end
                    task.wait(5)
                end
                if not anyListed then
                    print("[AutoList] nothing listed this pass, stop")
                    break
                end
                task.wait(2)
            end
        end
        print("[AutoList] loop ended")
    end)
end



local function sanitizeField(str)
    if not str then return "Unknown" end
    str = tostring(str)
    if #str > 100 then str = str:sub(1,97).."..." end
    return str
end

local function processSaleEntry(entry)
    if not entry then return end
    entry:SetAttribute("Old", true)
    local spacer = entry:FindFirstChild("Spacer") or entry:FindFirstChildWhichIsA("Frame")
    if not spacer then return end
    local price, buyer, item, token = nil, nil, nil, nil
    local p = spacer:FindFirstChild("Price")
    if p and p:FindFirstChild("Amount") then price = p.Amount.Text end
    local t = spacer:FindFirstChild("Title")
    if t and t:FindFirstChild("PlrName") then buyer = t.PlrName.Text end
    local nm = spacer:FindFirstChild("ItemName")
    if nm and nm:IsA("TextLabel") then item = nm.Text end
    local tk = LocalPlayer.PlayerGui:FindFirstChild("TradeTokenCurrency_UI")
    if tk and tk:FindFirstChild("TradeTokens") and tk.TradeTokens:FindFirstChild("TextLabel1") then token = tk.TradeTokens.TextLabel1.Text end
    price = sanitizeField(price)
    buyer = sanitizeField(buyer)
    item = sanitizeField(item)
    token = sanitizeField(token)
    local tnow = getTime()
    local buyerId = getUserIdFromName(buyer)
    local thumb = fetchThumbnail(buyerId)
    local embed = {
        title = "🎉 Item Successfully Sold!",
        color = 5814783,
        fields = {
            { name = "👤 Buyer Name", value = buyer, inline = true },
            { name = "📦 Item", value = item, inline = true },
            { name = "💰 Item Price", value = price, inline = true },
            { name = "🪙 Tokens Now", value = token, inline = true },
            { name = "⏳ Date & Time", value = tnow, inline = true }
        },
        footer = { text = "Made ❤️ by Jay Hub | "..os.date("%I:%M %p") }
    }
    if thumb then embed.thumbnail = { url = thumb } end
    sendWebhook({ embeds = { embed } })
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = buyer.." bought "..item.." for "..price.."!", Duration = 5 })
end

local function setupHistoryWatcher()
    local gui = LocalPlayer.PlayerGui:WaitForChild("TradeBoothHistory"):WaitForChild("Frame"):WaitForChild("ScrollingFrame")
    for _, c in ipairs(gui:GetChildren()) do
        c:SetAttribute("Old", true)
    end
    gui.ChildAdded:Connect(function() task.wait(0.05) end)
    local acc = 0
    local throttle = 0.18
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        acc += dt
        if acc < throttle then return end
        acc = 0
        for _, child in ipairs(gui:GetChildren()) do
            local old = child:GetAttribute("Old")
            if not old then
                child:SetAttribute("Old", true)
                task.spawn(function() pcall(function() processSaleEntry(child) end) end)
            end
        end
    end)
    return conn
end

local chatRunning = false

local function startChatLoop()
    if chatRunning then return end
    chatRunning = true
    task.spawn(function()
        local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if not ch then chatRunning = false return end
        local elapsed = 0
        local total = TOTAL_MINUTES_AT_BOOTH * 60
        while chatRunning and elapsed < total do
            pcall(function() ch:SendAsync("Selling mimic, 40 token each!") end)
            local waited = 0
            while waited < MESSAGE_INTERVAL and chatRunning and elapsed < total do
                task.wait(1)
                waited += 1
                elapsed += 1
            end
        end
        chatRunning = false
    end)
end

local function stopChatLoop()
    chatRunning = false
end

task.spawn(function()
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Searching for an unclaimed booth...", Duration = 4 })
    local booth = findUnclaimedBooth()
    if not booth then
        Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "No unclaimed booths found.", Duration = 4 })
        return
    end
    task.wait(1)
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Running Equip skin and attempting to claim a booth", Duration = 4 })
    runEquipBoothSkin()
    local ok = claimBooth(booth)
    if not ok then
        Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Claim failed.", Duration = 6 })
        return
    end
    task.wait(1)
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Claimed booth. Moving to booth...", Duration = 4 })
    local cf = boothCFrameFromModel(booth)
    if not cf then
        Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Cannot determine booth position.", Duration = 6 })
        return
    end
    task.wait(1)
    local moved = moveToCFrame(cf)
    if not moved then
        Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Failed to move.", Duration = 6 })
        return
    end
    task.wait(1)
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Arrived at booth. Starting to lako", Duration = 4 })
    startChatLoop()
    local watcher = setupHistoryWatcher()
    pcall(function() autoListItemsIfNeeded(booth) end)
    local total = TOTAL_MINUTES_AT_BOOTH * 60
    local waited = 0
    while waited < total do
        task.wait(1)
        waited += 1
        if not LocalPlayer.Parent then break end
    end
    stopChatLoop()
    if watcher then pcall(function() watcher:Disconnect() end) end
    Fluent:Notify({ Title = "Jay Hub - Auto Bot", Content = "Time's up. Server hopping...", Duration = 4 })
    task.wait(1)
    serverHop()
end)
