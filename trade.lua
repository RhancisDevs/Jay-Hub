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

local Event = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetGiftingService")

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

local function getNotificationLabel()
    local topNotif = PlayerGui:WaitForChild("Top_Notification")
    local frame = topNotif:WaitForChild("Frame")
    local mobileUI = frame:WaitForChild("Notification_UI_Mobile")
    local label = mobileUI:WaitForChild("TextLabel")
    return label
end

local function waitForTradeComplete(notifLabel, timeout)
    timeout = timeout or 15
    local done = false
    local conn

    conn = notifLabel:GetPropertyChangedSignal("Text"):Connect(function()
        if notifLabel.Text == "Trade complete!" then
            done = true
        end
    end)

    local start = tick()
    while not done and tick() - start < timeout do
        task.wait(0.1)
        if notifLabel.Text == "Trade complete!" then
            done = true
        end
    end

    if conn then
        conn:Disconnect()
    end

    return done
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
        return false
    end

    if not tool:GetAttribute("ItemType") then
        return false
    end

    local name = tool.Name
    local base = name:match("^(.-) %[%d") or ""
    local kg = tonumber(name:match("%[(%d+%.?%d*) KG%]")) or 0
    local age = tonumber(name:match("%[Age (%d+)%]")) or 0

    if not nameInPetList(base) then
        return false
    end

    local kgMatch = (getgenv().KG == 0) or (kg == getgenv().KG)
    local ageMatch = (getgenv().Age == 0) or (age == getgenv().Age)

    return kgMatch and ageMatch
end

local function buildTradePets()
    table.clear(tradePets)
    for _, tool in ipairs(Backpack:GetChildren()) do
        if matchesCriteria(tool) then
            table.insert(tradePets, tool)
        end
    end
end

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

        local notifLabel = getNotificationLabel()
        if not notifLabel then
            autoTrading = false
            return
        end

        local tool = tradePets[1]

        if tool and tool.Parent == Backpack then
            tool.Parent = Character
            task.wait(0.2)

            Event:FireServer("GivePet", target)
            task.wait(0.4)

            if tool.Parent == Character then
                tool.Parent = Backpack
            end

            local completed = waitForTradeComplete(notifLabel, 20)
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
    Default = 1
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
end)

local AutoToggle = main_tab:AddToggle("AutoTradeToggle", {
    Title = "Auto Trade",
    Default = false
})

AutoToggle:OnChanged(function(state)
    autoTrading = state
    if state then
        buildTradePets()
        if getgenv().Username ~= "" then
            task.spawn(autoTradeLoop)
        end
    end
end)
