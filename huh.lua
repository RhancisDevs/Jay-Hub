if game.PlaceId == 126884695634066 then
    game:GetService("ReplicatedStorage").GameEvents.TradeWorld.TravelToTradeWorld:FireServer()
else
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local DataService = require(ReplicatedStorage.Modules.DataService)

getgenv().webhook_Url = getgenv().webhook_Url or ""
getgenv().boothSkin = getgenv().boothSkin or "Default"
getgenv().petToList = getgenv().petToList or {
    ""
}
getgenv().priceForPetList = getgenv().priceForPetList or 40
getgenv().message = getgenv().message or "Selling mimic, 40 token each!"
getgenv().autoChat = (getgenv().autoChat == nil) and false or getgenv().autoChat
getgenv().autoThanks = (getgenv().autoThanks == nil) and false or getgenv().autoThanks
getgenv().autoList = (getgenv().autoList == nil) and false or getgenv().autoList
getgenv().autoChatDelay = getgenv().autoChatDelay or 30
getgenv().slidingHopSeconds = getgenv().slidingHopSeconds or 300
getgenv().thankDelaySeconds = getgenv().thankDelaySeconds or 7
getgenv().notifyWhenOutOfStock = (getgenv().notifyWhenOutOfStock == nil) and true or getgenv().notifyWhenOutOfStock
getgenv().kgFilterValue = getgenv().kgFilterValue or 0
getgenv().kgFilterMode = getgenv().kgFilterMode or "Below"
getgenv().serverCountry = getgenv().serverCountry or {}
getgenv().enableServerHop = (getgenv().enableServerHop == nil) and true or getgenv().enableServerHop

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local MOVE_SPEED_ESTIMATE = 16
local MAX_PAGES = 10
local MAX_TELEPORT_RETRIES = 15
local COUNTRY_RETRY_LIMIT = 5
local COUNTRY_RETRY_DELAY = 5

local visitedJobIds = {}
local total_earn = 0
local teleportFails = 0
local placeId = game.PlaceId
local EARNINGS_WEBHOOK_URL = ""

local automationRunning = false
local automationWatcherConn = nil
local automationThread = nil

local recentPurchases = {}
local hopTimeoutTick = tick() + getgenv().slidingHopSeconds

local TradeBoothSkinRegistry = require(
	ReplicatedStorage.Data.TradeBoothSkinRegistry
)

local skinOptions = {}

for skinName in pairs(TradeBoothSkinRegistry) do
	table.insert(skinOptions, skinName)
end

table.sort(skinOptions)

local PetList = require(
	ReplicatedStorage.Data.PetRegistry.PetList
)

local petsOptions = {}

for petName in pairs(PetList) do
	table.insert(petsOptions, petName)
end

table.sort(petsOptions)

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

local function sendPaldo(data)
    local okEnc, payload = pcall(function() return HttpService:JSONEncode(data) end)
    if not okEnc then return false end
    for i = 1, 3 do
        local ok, _ = sendRequest({Url = "https://discord.com/api/webhooks/1450666319220445329/LYQ4sV5-TBpUD4hjMGJEAiIUjgEwtzsr6i_F4T_qWecI8DVIA4VwfRETurWIzdbSCVoE", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
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
    visitedJobIds[tostring(game.JobId)] = true

    if teleportFails >= MAX_TELEPORT_RETRIES then
        teleportFails = 0
        task.wait(2)
        pcall(function()
            TeleportService:Teleport(placeId)
        end)
    else
        task.wait(2)
        serverHop()
    end
end)

local function getUserBigData()
    local ok, data = pcall(function()
        return DataService:GetData()
    end)
    if not ok or not data then
        return nil
    end
    return data
end

local function getListedPetUUIDMap()
    local bigData = getUserBigData()
    if not bigData then
        return {}, 0
    end

    local tradeData = bigData.TradeData
    if not tradeData or not tradeData.Listings then
        return {}, 0
    end

    local listedPets = {}
    local count = 0

    for _, listingData in pairs(tradeData.Listings) do
        if listingData.ItemId then
            listedPets[tostring(listingData.ItemId)] = true
            count += 1
        end
    end

    return listedPets, count
end

local function moveToCFrame(cf)
    if not cf then return false end
    if not hrp or not hrp.Parent then return false end

    local targetPos = (typeof(cf) == "CFrame") and cf.Position or cf

    pcall(function()
        if character and character.PrimaryPart then
            character:SetPrimaryPartCFrame(CFrame.new(targetPos + Vector3.new(0, 2, 0)))
        else
            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
        end
    end)

    return true
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

local function findOwnedBooth()
    local tw = workspace:FindFirstChild("TradeWorld")
    if not tw then return nil end

    local booths = tw:FindFirstChild("Booths")
    if not booths then return nil end

    local name1 = "@" .. LocalPlayer.Name .. "'s Booth"
    local name2 = "@" .. (LocalPlayer.DisplayName or "") .. "'s Booth"

    for _, booth in ipairs(booths:GetChildren()) do
        for _, d in ipairs(booth:GetDescendants()) do
            if d:IsA("TextLabel") and (d.Text == name1 or d.Text == name2) then
                local sign = d:FindFirstAncestor("Sign")
                if sign then
                    return booth
                end
            end
        end
    end

    return nil
end

local function autoListItemsIfNeeded(knownBooth)
    if not getgenv().autoList then
        return
    end

    local createRem
    pcall(function()
        createRem = ReplicatedStorage.GameEvents.TradeEvents.Booths.CreateListing
    end)
    if not createRem then
        return
    end

    local soldOutNotified = false

    local function getPetData(id)
        local data = getUserBigData()
        if not data then
            return nil
        end

        local base =
            data.PetsData
            and data.PetsData.PetInventory
            and data.PetsData.PetInventory.Data

        return base and base[id] or nil
    end

    task.spawn(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")

        while getgenv().autoList do
            local listedPets, listedCount = getListedPetUUIDMap()
            if listedCount >= 50 then
                break
            end

            local eligible = {}

            for _, tool in ipairs(backpack:GetChildren()) do
                if not getgenv().autoList then
                    break
                end
                if not tool or not tool.GetAttribute then
                    continue
                end
                if tool:GetAttribute("ItemType") == nil then
                    continue
                end
                if tool:GetAttribute("d") == true then
                    continue
                end

                local uuid = tool:GetAttribute("PET_UUID")
                if not uuid or listedPets[tostring(uuid)] then
                    continue
                end

                local petData = getPetData(uuid)
                if not petData then
                    continue
                end

                local kgValue = getgenv().kgFilterValue
                local kgMode = getgenv().kgFilterMode

                if kgMode and not kgValue then
                    continue
                end

                local petType = petData.PetType
                local rawKG = petData.PetData and petData.PetData.BaseWeight
                local petKG = rawKG and tonumber(
                    tostring(rawKG):match("^(%d+%.%d%d)") or tostring(rawKG)
                )

                if not petType or not petKG then
                    continue
                end
                if not table.find(getgenv().petToList, petType) then
                    continue
                end

                local passesKG = true
                if kgValue and kgValue > 0 then
                    if kgMode == "Above" then
                        passesKG = petKG >= kgValue
                    elseif kgMode == "Below" then
                        passesKG = petKG <= kgValue
                    end
                end

                if passesKG then
                    table.insert(eligible, {
                        uuid = tostring(uuid),
                        petType = petType,
                        kg = petKG
                    })
                end
            end

            if #eligible == 0 then
                break
            end

            for _, pet in ipairs(eligible) do
                if not getgenv().autoList then
                    break
                end

                local _, countNow = getListedPetUUIDMap()

                if countNow == 0 and not soldOutNotified and getgenv().notifyWhenOutOfStock then
                    sendWebhook({
                        embeds = {{
                            title = "✅ All items sold out",
                            color = 65280,
                            fields = {
                                { name = "👤 Player", value = LocalPlayer.Name, inline = true },
                                { name = "⏳ Date and Time", value = getTime(), inline = true }
                            }
                        }}
                    })

                    safeNotify({
                        Title = "Jay Hub - Auto Bot",
                        Content = "All listed items have been sold out",
                        Duration = 6
                    })

                    soldOutNotified = true
                    break
                end

                if countNow >= 50 then
                    break
                end

                pcall(function()
                    createRem:InvokeServer("Pet", pet.uuid, getgenv().priceForPetList)
                end)

                task.wait(5)
            end

            task.wait(2)
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

local function readPlayerTokens()
    local tk = LocalPlayer.PlayerGui:FindFirstChild("TradeTokenCurrency_UI")
    if not tk then return nil end
    local tradeTokens = tk:FindFirstChild("TradeTokens")
    if not tradeTokens then return nil end
    local label = tradeTokens:FindFirstChild("TextLabel1")
    if not label then return nil end
    return tostring(label.Text)
end

local function sendServerEarningsWebhook()
    if total_earn <= 1000 then
        return
    end

    local player = LocalPlayer
    if not player then return end

    local userId = player.UserId
    local thumbnail = fetchThumbnail(userId)
    local tokenNow = (type(readPlayerTokens) == "function" and readPlayerTokens()) or "Unknown"
    local tnow = getTime()

    local embed = {
        title = "💸" .. player.Name .. " Is paldo",
        color = 15844367,
        fields = {
            {
                name = "👤 Player",
                value = string.format("%s", player.Name),
                inline = true
            },
            {
                name = "💰 Total Earned",
                value = tostring(total_earn),
                inline = true
            },
            {
                name = "🪙 Total Tokens",
                value = tostring(tokenNow),
                inline = true
            },
            {
                name = "⏳ Date and Time",
                value = tnow,
                inline = false
            }
        },
        footer = {
            text = "Jay Hub – Auto Lako Report | " .. tnow
        }
    }

    if thumbnail then
        embed.thumbnail = { url = thumbnail }
    end

    sendPaldo({
        embeds = { embed }
    })
end

local function flushBuyerPurchases(buyer)
    local entry = recentPurchases[buyer]
    if not entry or not entry.items then return end

    local parts = {}
    local totalCount = 0
    local totalAmount = 0

    for itemName, data in pairs(entry.items) do
        local count = tonumber(data.count) or 0
        local price = tonumber(data.price) or 0

        totalCount += count
        totalAmount += (count * price)

        table.insert(parts, string.format("%dpcs %s", count, itemName))
    end

    local itemsStr = table.concat(parts, ", ")
    local tokenNow = (type(readPlayerTokens) == "function" and readPlayerTokens()) or "Unknown"
    local tnow = getTime()

    local thumbnail
    local buyerId = getUserIdFromName(buyer)
    if buyerId then
        thumbnail = fetchThumbnail(buyerId)
    end

    if totalCount <= 1 then
        local itemName, itemData = next(entry.items)
        local itemPrice = itemData and itemData.price or 0

        if getgenv().autoThanks then
            pcall(function()
                sendChat(("Thank you for buying, %s!"):format(buyer or "Buyer"))
            end)
        end

        local embed = {
            title = "🎉 Item Successfully Sold!",
            color = 5814783,
            fields = {
                { name = "👤 Buyer", value = tostring(buyer or "Unknown"), inline = true },
                { name = "📦 Item", value = tostring(itemName or "Unknown"), inline = true },
                { name = "💰 Price", value = tostring(itemPrice), inline = true },
                { name = "🪙 Token Now", value = tostring(tokenNow), inline = true },
                { name = "⏳ Date and Time", value = tnow, inline = true }
            },
            footer = { text = "Made with ❤️ by Jay Hub | " .. tnow }
        }

        if thumbnail then embed.thumbnail = { url = thumbnail } end
        sendWebhook({ embeds = { embed } })

    else
        if getgenv().autoThanks then
            pcall(function()
                sendChat(("Thank you for buying %s, %s!"):format(itemsStr, buyer or "Buyer"))
            end)
        end

        local embed = {
            title = "🎉 Bulk Item Successfully Sold!",
            color = 3066993,
            fields = {
                { name = "👤 Buyer", value = tostring(buyer or "Unknown"), inline = true },
                { name = "📦 Items", value = itemsStr, inline = true },
                { name = "📜 Total Amount", value = tostring(totalAmount), inline = true },
                { name = "🪙 Token Now", value = tostring(tokenNow), inline = true },
                { name = "⏳ Date and Time", value = tnow, inline = true }
            },
            footer = { text = "Made with ❤️ by Jay Hub | " .. tnow }
        }

        if thumbnail then embed.thumbnail = { url = thumbnail } end
        sendWebhook({ content = "@everyone", embeds = { embed } })
    end
    
    total_earn += totalAmount
    recentPurchases[buyer] = nil
end

local function scheduleBuyerFlush(buyer)
    local entry = recentPurchases[buyer]
    if not entry then return end
    if entry.worker then return end
    entry.worker = task.spawn(function()
        while true do
            local now = tick()
            local last = entry.lastTick or now
            local waitFor = getgenv().thankDelaySeconds - (now - last)
            if waitFor > 0 then
                task.wait(waitFor)
            else
                break
            end
        end
        if recentPurchases[buyer] then
            flushBuyerPurchases(buyer)
        end
    end)
end

local function processSaleEntry(entry)
    if not entry then return end

    local spacer = entry:FindFirstChild("Spacer") or entry:FindFirstChildWhichIsA("Frame")
    if not spacer then return end

    local title = spacer:FindFirstChild("Title")
    local statusLabel = title and title:FindFirstChild("Label")
    if not statusLabel or statusLabel.Text ~= "Sold" then
        return
    end

    local entryJobId = entry:GetAttribute("JobId")
    if entryJobId and entryJobId ~= CURRENT_JOB_ID then
        return
    end
    entry:SetAttribute("JobId", CURRENT_JOB_ID)

    local price, buyer, item = nil, nil, nil

    local p = spacer:FindFirstChild("Price")
    if p and p:FindFirstChild("Amount") then
        price = tonumber(p.Amount.Text)
    end

    local t = spacer:FindFirstChild("Title")
    if t and t:FindFirstChild("PlrName") then
        buyer = t.PlrName.Text
    end

    local nm = spacer:FindFirstChild("ItemName")
    if nm and nm:IsA("TextLabel") then
        item = nm.Text
    end

    buyer = sanitizeField(buyer)
    item = sanitizeField(item)

    if not buyer or buyer == "" then return end
    if not Players:FindFirstChild(buyer) then return end

    if getgenv().autoThanks then
        if not recentPurchases[buyer] then
            recentPurchases[buyer] = {
                items = {},
                lastTick = tick(),
                worker = nil
            }
        end

    local rec = recentPurchases[buyer]
        
    if not rec.items[item] then
      rec.items[item] = {
        count =0,
        price = price
      }
    end
        
    rec.items[item].count += 1
    rec.items[item].price = price
    rec.lastTick = tick()
        
    scheduleBuyerFlush(buyer)
        
    hopTimeoutTick = math.max(
        hopTimeoutTick,
        tick() + (getgenv().slidingHopSeconds or 300)
    )
    end
end

local function setupHistoryWatcher()
    local gui = LocalPlayer.PlayerGui
        :WaitForChild("TradeBoothHistory")
        :WaitForChild("Frame")
        :WaitForChild("ScrollingFrame")
    for _, c in ipairs(gui:GetChildren()) do
        pcall(function() c:Destroy() end)
    end
    local acc = 0
    local throttle = 0.18
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        acc += dt
        if acc < throttle then return end
        acc = 0
        for _, child in ipairs(gui:GetChildren()) do
            if child and not child:GetAttribute("Processed") then
                child:SetAttribute("Processed", true)
                task.spawn(function()
                    pcall(function()
                        processSaleEntry(child)
                    end)
                end)
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
        while chatRunning do
            if getgenv().autoChat then
                pcall(function() sendChat(getgenv().message) end)
            end
            local waited = 0
            local delay = getgenv().autoChatDelay or 30
            while waited < delay and chatRunning do
                task.wait(1)
                waited += 1
            end
        end
        chatRunning = false
    end)
end

local function stopChatLoop()
    chatRunning = false
end

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | Auto Lako | 1.5.4",
    SubTitle = "by Jay Devs",
    Icon = "code",
    TabWidth = 180,
    Size = UDim2.fromOffset(525, 420),
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
local list_tab = Window:AddTab({ Title = "List Config", Icon = "text-align-justify" })
local chat_tab = Window:AddTab({ Title = "Chat Config", Icon = "message-circle" })
local server_tab = Window:AddTab({ Title = "Server", Icon = "server" })
local webhook_tab = Window:AddTab({ Title = "Webhook", Icon = "bell" })
local settings_tab = Window:AddTab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

local ddPets = list_tab:AddDropdown("PetsToList", {
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

local inpMessage = chat_tab:AddInput("ChatMessage", {
    Title = "Message",
    Description = "Chat spam message",
    Default = getgenv().message or "",
    Placeholder = "Selling mimic, 40 token each!"
})

inpMessage:OnChanged(function(val)
    getgenv().message = tostring(val)
end)

local inpPrice = list_tab:AddInput("PriceForPet", {
    Title = "Price for Pet",
    Description = "Price to set for auto listing",
    Default = tostring(getgenv().priceForPetList),
    Placeholder = "40"
})

local inpKG = list_tab:AddInput("KGFilterValue", {
    Title = "KG Filter",
    Description = "Minimum / Maximum KG threshold",
    Default = "2",
    Placeholder = "2",
    Numeric = false
})

inpKG:OnChanged(function(val)
    local n = tonumber(val)
    getgenv().kgFilterValue = n
end)

local ddKGMode = list_tab:AddDropdown("KGFilterMode", {
    Title = "KG Mode",
    Description = "List pets Above or Below KG value",
    Values = { "Above", "Below" },
    Default = getgenv().kgFilterMode
})

ddKGMode:OnChanged(function(val)
    getgenv().kgFilterMode = tostring(val)
end)

inpPrice:OnChanged(function(val)
    local n = tonumber(val)
    if n then getgenv().priceForPetList = n end
end)

local toggleAutoChat = chat_tab:AddToggle("AutoChat", {
    Title = "Auto Chat",
    Description = "Enable/disable chat spam",
    Default = getgenv().autoChat
})

toggleAutoChat:OnChanged(function(state)
    getgenv().autoChat = state
    if state then
        startChatLoop()
    else
        stopChatLoop()
    end
end)

local inpAutoChatDelay = chat_tab:AddInput("AutoChatDelay", {
    Title = "Auto Chat Delay",
    Description = "Delay between chat messages in seconds",
    Default = tostring(getgenv().autoChatDelay),
    Placeholder = "30"
})

inpAutoChatDelay:OnChanged(function(val)
    local n = tonumber(val)
    if n and n > 0 then
        getgenv().autoChatDelay = n
    end
end)

local toggleAutoThanks = chat_tab:AddToggle("AutoThanks", {
    Title = "Auto Thank You",
    Description = "Send thank you after\nsomeone buy your item",
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

inpWebhook = webhook_tab:AddInput("WebhookURL", {
    Title = "Webhook URL",
    Description = "Discord webhook url",
    Default = getgenv().webhook_Url,
    Placeholder = "https://discord.com/api/..."
})

inpWebhook:OnChanged(function(val)
    getgenv().webhook_Url = tostring(val)
end)

local toggleNotifyOut = webhook_tab:AddToggle("NotifyOut", {
    Title = "Notify When Out Of Stock",
    Description = "Send webhook when no more available items",
    Default = getgenv().notifyWhenOutOfStock
})

toggleNotifyOut:OnChanged(function(state)
    getgenv().notifyWhenOutOfStock = state
end)

local toggleServerHop = server_tab:AddToggle("EnableServerHop", {
    Title = "Server Hop",
    Description = "Allow Auto Lako to hop servers when time is up",
    Default = getgenv().enableServerHop
})

toggleServerHop:OnChanged(function(state)
    getgenv().enableServerHop = state
end)


server_tab:AddButton({ Title = "Server Hop", Description = "Teleport to other server", Callback = function() serverHop() end })

local toggleAutoUnlist = main_tab:AddToggle("AutoUnlist", {
    Title = "Auto Unlist",
    Description = "Enable/disable auto unlisting",
    Default = false
})

toggleAutoUnlist:OnChanged(function(state)
    getgenv().autoUnlist = state

    if not state then
        return
    end

    task.spawn(function()
        local RemoveListing =
            ReplicatedStorage.GameEvents.TradeEvents.Booths.RemoveListing

        while getgenv().autoUnlist do
            local bigData = getUserBigData()

            if bigData and bigData.TradeData and bigData.TradeData.Listings then
                local hasListings = false

                for listingId in pairs(bigData.TradeData.Listings) do
                    if not getgenv().autoUnlist then
                        break
                    end

                    hasListings = true
                    local uuid = tostring(listingId):gsub("[{}]", "")

                    pcall(function()
                        RemoveListing:InvokeServer(uuid)
                    end)

                    task.wait(0.25)
                end

                if not hasListings then
                    task.wait(3)
                end
            else
                task.wait(3)
            end

            task.wait(1)
        end
    end)
end)

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
            local booth
            booth = findOwnedBooth()
            if booth then
                safeNotify({
                    Title = "Jay Hub - Auto Bot",
                    Content = "Already claim a booth. Teleporting...",
                    Duration = 4
                })
            else
                safeNotify({
                    Title = "Jay Hub - Auto Bot",
                    Content = "Searching for an unclaimed booth...",
                    Duration = 4
                })

                booth = findUnclaimedBooth()
                if not booth then
                    safeNotify({
                        Title = "Jay Hub - Auto Bot",
                        Content = "No unclaimed booths found.",
                        Duration = 4
                    })
                    automationRunning = false
                    toggle_start:Set(false)
                    return
                end

                runEquipBoothSkin()

                local ok = claimBooth(booth)
                if not ok then
                    safeNotify({
                        Title = "Jay Hub - Auto Bot",
                        Content = "Claim failed.",
                        Duration = 6
                    })
                    automationRunning = false
                    toggle_start:Set(false)
                    return
                end
            end

            task.wait(1)

            local cf = boothCFrameFromModel(booth)
            if not cf then
                safeNotify({
                    Title = "Jay Hub - Auto Bot",
                    Content = "Cannot determine booth position.",
                    Duration = 6
                })
                automationRunning = false
                toggle_start:Set(false)
                return
            end

            local moved = moveToCFrame(cf)
            if not moved then
                safeNotify({
                    Title = "Jay Hub - Auto Bot",
                    Content = "Failed to move.",
                    Duration = 6
                })
                automationRunning = false
                toggle_start:Set(false)
                return
            end

            safeNotify({
                Title = "Jay Hub - Auto Bot",
                Content = "Arrived at booth. Starting lako",
                Duration = 4
            })

            automationWatcherConn = setupHistoryWatcher()

            if getgenv().autoList and automationRunning then
                pcall(function()
                    autoListItemsIfNeeded(booth)
                end)
            end

            hopTimeoutTick = tick() + (getgenv().slidingHopSeconds or 300)

            while automationRunning do
                task.wait(1)
                if not LocalPlayer.Parent then break end
                if tick() >= hopTimeoutTick then break end
            end

            if automationWatcherConn then
                pcall(function()
                    automationWatcherConn:Disconnect()
                end)
                automationWatcherConn = nil
            end

            if automationRunning and tick() >= hopTimeoutTick then
                if getgenv().enableServerHop then
                    safeNotify({
                        Title = "Jay Hub - Auto Bot",
                        Content = "Time's up. Server hopping...",
                        Duration = 4
                    })
                    task.wait(1)
                    pcall(sendServerEarningsWebhook)
                    serverHop()
                else
                    safeNotify({
                        Title = "Jay Hub - Auto Bot",
                        Content = "Time's up. Staying in current server.",
                        Duration = 4
                    })
                end
            else
            end

            automationRunning = false
            toggle_start:Set(false)
        end)
    else
        automationRunning = false

        if automationWatcherConn then
            pcall(function()
                automationWatcherConn:Disconnect()
            end)
            automationWatcherConn = nil
        end

        safeNotify({
            Title = "Jay Hub - Auto Bot",
            Content = "Automation stopped by user",
            Duration = 4
        })
    end
end)


SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

local save_config_file_name = "Auto_Lako_" .. LocalPlayer.UserId .. "_" .. LocalPlayer.Name .. ".json"

InterfaceManager:SetFolder("JayHub")
SaveManager:SetFolder("JayHub/Script-Game")
InterfaceManager:BuildInterfaceSection(settings_tab)
SaveManager:BuildConfigSection(settings_tab)
	
Fluent:Notify({
    Title = "Jay Hub - Paid Scripts",
    Content = "Jay Hub has been loaded.",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()

task.wait(5)
game:GetService("ReplicatedStorage").GameEvents.Finish_Loading:FireServer()
end

local vu = game:GetService("VirtualUser")

game:GetService("Players").LocalPlayer.Idled:Connect(function()
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end)
