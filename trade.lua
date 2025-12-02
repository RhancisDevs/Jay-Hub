getgenv().Username = ""
getgenv().petName = {}
getgenv().KG = 0
getgenv().Age = 0
getgenv().petList = {"Mimic Octopus", "Peacock"}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
end)

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local Event = GameEvents:WaitForChild("PetGiftingService")
local FavoriteEvent = GameEvents:WaitForChild("Favorite_Item")
local GiftPet = GameEvents:WaitForChild("GiftPet")
local AcceptPetGift = GameEvents:WaitForChild("AcceptPetGift")

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. game:GetService("MarketplaceService"):GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    Icon = "132940723895184",
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
    Icon = "132940723895184",
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 320, 0, 24),
    Acrylic = true,
    Corner = 10,
    Transparency = 1,
    Draggable = true,
    Visible = true
})

local main_tab = Window:AddTab({ Title = "Main", Icon = "home" })
Window:SelectTab(1)

local function getPlayer(name)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == name:lower() then
            return plr
        end
    end
    return nil
end

local function waitForTradeComplete(timeout)
    timeout = timeout or 15
    local topNotif = PlayerGui:FindFirstChild("Top_Notification")
    if not topNotif then return false end
    local frame = topNotif:FindFirstChild("Frame")
    if not frame then return false end

    local done = false
    local conn
    local start = tick()

    conn = frame.ChildAdded:Connect(function(child)
        if done then return end
        local label
        if child.Name == "Notification_UI_Mobile" then
            label = child:FindFirstChild("TextLabel")
        else
            local mobile = child:FindFirstChild("Notification_UI_Mobile")
            if mobile then
                label = mobile:FindFirstChild("TextLabel")
            end
        end
        if label and label.Text == "Trade completed!" then
            done = true
        end
    end)

    while not done and tick() - start < timeout do
        task.wait(0.1)
    end

    if conn then
        conn:Disconnect()
    end

    return done
end

local function equipTool(tool)
    local char = Character or LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if tool.Parent ~= Backpack then
        tool.Parent = Backpack
        task.wait(0.05)
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:EquipTool(tool)
    else
        tool.Parent = char
    end
    task.wait(0.2)
end

local function unequipTool(tool)
    local char = Character or LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:UnequipTools()
        end
    end
    if tool and tool.Parent ~= Backpack then
        tool.Parent = Backpack
    end
end

local tradePets = {}

local function nameInPetList(base)
    for _, pname in ipairs(getgenv().petName) do
        if tostring(pname) == tostring(base) then
            return true
        end
    end
    return false
end

local function matchesCriteria(tool)
    if not tool:IsA("Tool") then
        return false, false
    end

    if not tool:GetAttribute("ItemType") then
        return false, false
    end

    local name = tool.Name
    local base = name:match("^(.-) %[%d") or ""
    local kg = tonumber(name:match("%[(%d+%.?%d*) KG%]")) or 0
    local age = tonumber(name:match("%[Age (%d+)%]")) or 0
    local isFavorite = tool:GetAttribute("d") == true

    if not nameInPetList(base) then
        return false, isFavorite
    end

    local kgMatch = (getgenv().KG == 0) or (kg == getgenv().KG)
    local ageMatch = (getgenv().Age == 0) or (age == getgenv().Age)

    return kgMatch and ageMatch, isFavorite
end

local function buildTradePets()
    table.clear(tradePets)
    for _, tool in ipairs(Backpack:GetChildren()) do
        local ok, isFavorite = matchesCriteria(tool)
        if ok then
            table.insert(tradePets, {
                tool = tool,
                favorite = isFavorite
            })
        end
    end
end

buildTradePets()

local autoTrading = false

local function autoTradeLoop()
    while autoTrading do
        local target = getPlayer(getgenv().Username)
        if not target then
            autoTrading = false
            return
        end

        if #tradePets == 0 then
            buildTradePets()
            if #tradePets == 0 then
                autoTrading = false
                return
            end
        end

        local entry = tradePets[1]
        local tool = entry and entry.tool
        local isFavorite = entry and entry.favorite

        if tool and tool.Parent then
            equipTool(tool)

            if isFavorite then
                FavoriteEvent:FireServer(tool)
                task.wait(0.3)
            end

            Event:FireServer("GivePet", target)
            task.wait(0.4)
            unequipTool(tool)

            local completed = waitForTradeComplete(20)

            table.remove(tradePets, 1)
        else
            table.remove(tradePets, 1)
        end

        task.wait(0.3)
    end
end

local function getPlayerNames()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    if #names == 0 then
        table.insert(names, "No Players Found")
    end
    return names
end

local PlayerDropdown = main_tab:AddDropdown("PlayerList", {
    Title = "Player List",
    Values = getPlayerNames(),
    Multi = false,
    Default = "Select Player"
})

PlayerDropdown:OnChanged(function(value)
    if value ~= "No Players Found" then
        getgenv().Username = value
    end
end)

main_tab:AddButton({
    Title = "Refresh Player",
    Callback = function()
        PlayerDropdown:SetValues(getPlayerNames())
    end
})

local PetsDropdown = main_tab:AddDropdown("PetsToTrade", {
    Title = "Pets To Trade",
    Values = getgenv().petList,
    Multi = true,
    Default = {}
})

PetsDropdown:OnChanged(function(value)
    local selected = {}
    for pet, state in next, value do
        if state then
            table.insert(selected, pet)
        end
    end
    getgenv().petName = selected
    buildTradePets()
end)

local KgInput = main_tab:AddInput("KGInput", {
    Title = "KG (0 = any)",
    Default = "0",
    Placeholder = "0",
    Numeric = true,
    Finished = false
})

KgInput:OnChanged(function(value)
    local num = tonumber(value)
    if num then
        getgenv().KG = num
    else
        getgenv().KG = 0
    end
    buildTradePets()
end)

local AgeInput = main_tab:AddInput("AgeInput", {
    Title = "Age (0 = any)",
    Default = "0",
    Placeholder = "0",
    Numeric = true,
    Finished = false
})

AgeInput:OnChanged(function(value)
    local num = tonumber(value)
    if num then
        getgenv().Age = num
    else
        getgenv().Age = 0
    end
    buildTradePets()
end)

local AutoToggle = main_tab:AddToggle("AutoTradeToggle", {
    Title = "Auto Trade",
    Default = false
})

AutoToggle:OnChanged(function(state)
    autoTrading = state
    if state then
        buildTradePets()
        if getgenv().Username ~= "Select Player" then
            task.spawn(autoTradeLoop)
        else
            autoTrading = false
            AutoToggle:SetValue(false)
        end
    end
end)

local autoAccept = false
local giftConn

local AutoAcceptToggle = main_tab:AddToggle("AutoAcceptToggle", {
    Title = "Auto Accept Trade",
    Default = false
})

AutoAcceptToggle:OnChanged(function(state)
    autoAccept = state
    if state then
        if giftConn then
            giftConn:Disconnect()
            giftConn = nil
        end
        giftConn = GiftPet.OnClientEvent:Connect(function(giftId)
            AcceptPetGift:FireServer(true, giftId)
        end)
    else
        if giftConn then
            giftConn:Disconnect()
            giftConn = nil
        end
    end
end)
