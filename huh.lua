if game.PlaceId == 126884695634066 then
    game:GetService("ReplicatedStorage").GameEvents.TradeWorld.TravelToTradeWorld:FireServer()
else
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

getgenv().webhook_Url = ""
getgenv().boothSkin = "Default"
getgenv().petToList = { 
    "Mimic Octopus"
}
getgenv().priceForPetList =  40
getgenv().message = "Selling mimic, 40 token each!"
getgenv().autoChat = false
getgenv().autoThanks = false
getgenv().autoList = false

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local MESSAGE_INTERVAL = 30
local TOTAL_MINUTES_AT_BOOTH = 15
local MOVE_SPEED_ESTIMATE = 16
local MAX_PATH_RETRIES = 3
local MAX_PAGES = 10
local MAX_TELEPORT_RETRIES = 8

local visitedJobIds = {}
local teleportFails = 0
local placeId = game.PlaceId

local automationRunning = false
local automationWatcherConn = nil
local automationThread = nil

local function safeNotify(opts)
    if type(Fluent) == "table" and type(Fluent.Notify) == "function" then
        pcall(function() Fluent:Notify(opts) end)
    else
        pcall(function() print(opts.Title or "", opts.Content or "") end)
    end
end

local function sendRequest(params)
    local req = request or http_request or (syn and syn.request)
    if type(req) ~= "function" then
        return false, nil
    end
    local ok, res = pcall(function() return req(params) end)
    if not ok or not res then return false, nil end
    return true, (res.Body or res.body or res.response)
end

local function sendWebhook(data)
    if not getgenv().webhook_Url or getgenv().webhook_Url == "" then return false end
    local okEnc, payload = pcall(function() return HttpService:JSONEncode(data) end)
    if not okEnc then return false end
    for i = 1, 3 do
        local ok, _ = sendRequest({Url = getgenv().webhook_Url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
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
    if not getgenv().autoList then return end
    local createRem = nil
    local okRem = pcall(function()
        createRem = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TradeEvents"):WaitForChild("Booths"):WaitForChild("CreateListing")
    end)
    if not createRem then return end
    local DataServiceModule = nil
    pcall(function() DataServiceModule = require(ReplicatedStorage.Modules.DataService) end)
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
            if knownBooth and knownBooth.Parent then return knownBooth end
            local found = findPlayerBoothExact()
            if found then return found end
            task.wait(0.5)
        end
        return nil
    end
    task.spawn(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        while true do
            local booth = waitForPlayerBooth(10)
            if not booth then
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
                if dynCount >= 50 then break end
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
                if #eligible == 0 then break end
                local anyListed = false
                for _, pet in ipairs(eligible) do
                    local boothNow = waitForPlayerBooth(3)
                    if not boothNow then break end
                    local dynNow = boothNow:FindFirstChild("DynamicInstances")
                    if dynNow and #dynNow:GetChildren() >= 50 then break end
                    local args = {"Pet", pet.uuid, getgenv().priceForPetList}
                    local ok = false
                    pcall(function()
                        if typeof(createRem.InvokeServer) == "function" then
                            createRem:InvokeServer(unpack(args))
                        else
                            createRem:FireServer(unpack(args))
                        end
                        ok = true
                    end)
                    if ok then anyListed = true end
                    task.wait(5)
                end
                if not anyListed then break end
                task.wait(2)
            end
        end
    end)
end

local _cachedChatChannel = nil
local function getChatChannel()
    if _cachedChatChannel and _cachedChatChannel.Parent then return _cachedChatChannel end
    local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
    if ch then _cachedChatChannel = ch end
    return ch
end

local function sendChat(message)
    if not message or message == "" then return false end
    local ch = getChatChannel()
    if not ch then
        ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if ch then _cachedChatChannel = ch end
    end
    if not ch then return false end
    local ok = pcall(function() ch:SendAsync(tostring(message)) end)
    return ok
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
    sendWebhook({ 
                content = "@everyone",
                embeds = { embed } 
            })
    safeNotify({ Title = "Jay Hub - Auto Bot", Content = buyer.." bought "..item.." for "..price.."!", Duration = 5 })
    if getgenv().autoThanks then
        task.spawn(function()
            local thankMsg = ("Thank you for buying, %s!"):format(buyer or "Buyer")
            sendChat(thankMsg)
        end)
    end
end

local function setupHistoryWatcher()
    local gui = LocalPlayer.PlayerGui:WaitForChild("TradeBoothHistory"):WaitForChild("Frame"):WaitForChild("ScrollingFrame")
    for _, c in ipairs(gui:GetChildren()) do c:SetAttribute("Old", true) end
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
    if not getgenv().autoChat then return end
    chatRunning = true
    task.spawn(function()
        local elapsed = 0
        local total = TOTAL_MINUTES_AT_BOOTH * 60
        while chatRunning and elapsed < total do
            if getgenv().autoChat then
                local ok = sendChat(getgenv().message)
                if not ok then task.wait(1) end
            end
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

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. (pcall(function() return MarketplaceService:GetProductInfo(126884695634066).Name end) and MarketplaceService:GetProductInfo(126884695634066).Name or "Trade"),
    SubTitle = "by Jay Devs",
    Icon = "code",
    TabWidth = 180,
    Size = UDim2.fromOffset(525, 380),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    UserInfo = true,
    UserInfoTop = true,
    UserInfoTitle = LocalPlayer.DisplayName,
    UserInfoSubtitle = "Welcome to Jay Hub!",
    UserInfoSubtitleColor = Color3.fromRGB(71, 123, 255)
})

local Minimizer = Fluent:CreateMinimizer({
  Icon = "code",
  Size = UDim2.fromOffset(44, 44),
  Position = UDim2.new(0, 320, 0, 24),
  Acrylic = true,
  Corner = 10,
  Transparency = 1,
  Draggable = true,
  Visible = true
})

local main_tab = Window:AddTab({ Title = "Main", Icon = "home" })
local server_tab = Window:AddTab({ Title = "Server", Icon = "server" })
local webhook_tab = Window:AddTab({ Title = "Webhook", Icon = "bell" })
local settings_tab = Window:AddTab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

local petsOptions = {
    "Mimic Octopus", 
    "Capybara", 
    "Peacock", 
    "Diamond Panther", 
    "Ruby Squid", 
    "Brontosaurus", 
    "Seal", 
    "Headless Horseman"
}
local skinOptions = {
        "Default",
        "Fairy",
        "Volcano",
        "Cherry"
    }

local ddPets = main_tab:AddDropdown("PetsToList", {
    Title = "Pets To List",
    Description = "Select one or more pets to auto-list.",
    Values = petsOptions,
    Default = getgenv().petToList or {},
    Multi = true
})

ddPets:OnChanged(function(selection)
    if type(selection) == "table" then
        local arr = {}
        for val, state in pairs(selection) do
            if state then table.insert(arr, tostring(val)) end
        end
        getgenv().petToList = arr
    else
        getgenv().petToList = { tostring(selection) }
    end
end)

local ddSkin = main_tab:AddDropdown("BoothSkin", {
    Title = "Booth Skin",
    Description = "Select booth skin",
    Values = skinOptions,
    Default = getgenv().boothSkin
})

ddSkin:OnChanged(function(val)
    getgenv().boothSkin = tostring(val)
end)

local inpMessage = main_tab:AddInput("ChatMessage", {
    Title = "Message",
    Description = "Chat spam message",
    Default = "",
    Placeholder = "Selling mimic, 40 token each!"
})

inpMessage:OnChanged(function(val)
    getgenv().message = tostring(val)
end)

local inpPrice = main_tab:AddInput("PriceForPet", {
    Title = "Price for Pet",
    Description = "Price to set for auto listing",
    Default = "",
    Placeholder = "40"
})

inpPrice:OnChanged(function(val)
    local n = tonumber(val)
    if n then getgenv().priceForPetList = n end
end)

local toggleAutoChat = main_tab:AddToggle("AutoChat", {
    Title = "Auto Chat",
    Description = "Enable/disable chat spam",
    Default = getgenv().autoChat
})

toggleAutoChat:OnChanged(function(state)
    getgenv().autoChat = state
end)

local toggleAutoThanks = main_tab:AddToggle("AutoThanks", {
    Title = "Auto Thank You",
    Description = "Send thank you after sale",
    Default = getgenv().autoThanks
})

toggleAutoThanks:OnChanged(function(state)
    getgenv().autoThanks = state
end)

local toggleAutoList = main_tab:AddToggle("AutoList", {
    Title = "Auto List",
    Description = "Enable/disable auto listing",
    Default = getgenv().autoList
})

toggleAutoList:OnChanged(function(state)
    getgenv().autoList = state
end)

local inpWebhook = webhook_tab:AddInput("WebhookURL", {
    Title = "Webhook URL",
    Description = "Discord webhook url",
    Default = getgenv().webhook_Url,
    Placeholder = "https://discord.com/api/..."
})

inpWebhook:OnChanged(function(val)
    getgenv().webhook_Url = tostring(val)
end)

local inpMinutes = server_tab:AddInput("MinutesBeforeHop", {
    Title = "Minutes Before Hop",
    Description = "How many minutes to\nstay before server hop",
    Default = tostring(TOTAL_MINUTES_AT_BOOTH),
    Placeholder = "15"
})

inpMinutes:OnChanged(function(val)
    local n = tonumber(val)
    if n and n > 0 then TOTAL_MINUTES_AT_BOOTH = n end
end)

server_tab:AddButton({
    Title = "Server Hop",
    Description = "Teleport to other server",
    Callback = function()
        serverHop()
    end
})

local toggle_start = main_tab:AddToggle("AutoLako", {
    Title = "Auto Lako",
    Description = "Start / Stop Auto Lako",
    Default = false
})

toggle_start:OnChanged(function(active)
    if active then
        if automationRunning then return end
        automationRunning = true
        automationThread = task.spawn(function()
            safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Searching for an unclaimed booth...", Duration = 4 })
            if not automationRunning then return end
            local booth = findUnclaimedBooth()
            if not booth then
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "No unclaimed booths found.", Duration = 4 })
                automationRunning = false
                toggle_start:Set(false)
                return
            end
            task.wait(1)
            if not automationRunning then return end
            safeNotify({ Title = "Jay Hub - Auto Bot", Content = "attempting to claim a booth", Duration = 4 })
            runEquipBoothSkin()
            if not automationRunning then return end
            local ok = claimBooth(booth)
            if not ok then
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Claim failed.", Duration = 6 })
                automationRunning = false
                toggle_start:Set(false)
                return
            end
            task.wait(1)
            if not automationRunning then return end
            safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Claimed booth. Moving to booth...", Duration = 4 })
            local cf = boothCFrameFromModel(booth)
            if not cf then
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Cannot determine booth position.", Duration = 6 })
                automationRunning = false
                toggle_start:Set(false)
                return
            end
            task.wait(1)
            if not automationRunning then return end
            local moved = moveToCFrame(cf)
            if not moved then
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Failed to move.", Duration = 6 })
                automationRunning = false
                toggle_start:Set(false)
                return
            end
            task.wait(1)
            if not automationRunning then return end
            safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Arrived at booth. Starting automation", Duration = 4 })
            if getgenv().autoChat then
                startChatLoop()
            end
            automationWatcherConn = setupHistoryWatcher()
            if getgenv().autoList and automationRunning then
                pcall(function() autoListItemsIfNeeded(booth) end)
            end
            local total = TOTAL_MINUTES_AT_BOOTH * 60
            local waited = 0
            while automationRunning and waited < total do
                task.wait(1)
                waited += 1
                if not LocalPlayer.Parent then break end
            end
            stopChatLoop()
            if automationWatcherConn then
                pcall(function() automationWatcherConn:Disconnect() end)
                automationWatcherConn = nil
            end
            if automationRunning then
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Time's up. Server hopping...", Duration = 4 })
                task.wait(1)
                serverHop()
            else
                safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Automation stopped", Duration = 4 })
            end
            automationRunning = false
            toggle_start:Set(false)
        end)
    else
        automationRunning = false
        stopChatLoop()
        if automationWatcherConn then
            pcall(function() automationWatcherConn:Disconnect() end)
            automationWatcherConn = nil
        end
        safeNotify({ Title = "Jay Hub - Auto Bot", Content = "Automation stopped by user", Duration = 4 })
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("JayHub")
SaveManager:SetFolder("JayHub/Script-Game")
InterfaceManager:BuildInterfaceSection(settings_tab)
SaveManager:BuildConfigSection(settings_tab)

Fluent:Notify({
    Title = "Jay Hub - Free Scripts",
    Content = "Jay Hub has been loaded.",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()

task.wait(5)
game:GetService("ReplicatedStorage").GameEvents.Finish_Loading:FireServer()
end
