local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local favoriteEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Favorite_Item")

getgenv().fruit = getgenv().fruit or 1
getgenv().eggEnhance = getgenv().eggEnhance or false
getgenv().fruitToFave = getgenv().fruitToFave or {}

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. MarketplaceService:GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    Icon = "code",
    TabWidth = 180,
    Size = UDim2.fromOffset(490, 360),
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
local settings_tab = Window:AddTab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

main_tab:AddInput("FruitAmountInput", {
    Title = "Fruit to favorite",
    Default = tostring(getgenv().fruit or 1),
    Placeholder = "Enter how many fruits to favorite",
    Numeric = true,
    Finished = true
}):OnChanged(function(value)
    local number = tonumber(value)
    if number then
        getgenv().fruit = number
        print("Set fruit amount to:", number)
    end
end)

main_tab:AddDropdown("FruitTypeDropdown", {
    Title = "Fruit Type",
    Description = "Used to select which fruits to favorite",
    Values = {
        "Bone Blossom",
        "Maple Apple",
        "Candy Blossom"
    },
    Multi = true,
    Default = getgenv().fruitToFave
}):OnChanged(function(selected)
    getgenv().fruitToFave = selected
    print("Fruit types to favorite updated:")
    if type(selected) == "table" then
        for _, v in ipairs(selected) do
            print(" -", v)
        end
    else
        print(" -", tostring(selected))
    end
end)

main_tab:AddToggle("EggEnhanceToggle", {
    Title = "Egg Enhance",
    Default = getgenv().eggEnhance or false
}):OnChanged(function(state)
    getgenv().eggEnhance = state
    print("Egg Enhance:", state and "ON" or "OFF")
end)

Fluent:Notify({Title = "Jay Hub - Auto Reconnect", Content = "Auto Reconnect Executed!", Duration = 6})

local fruits = {}

local function isSelectedFruitType(fValue)
    local selected = getgenv().fruitToFave or {}
    if type(selected) == "table" then
        for _, v in ipairs(selected) do
            if v == fValue then
                return true
            end
        end
    else
        if selected == fValue then
            return true
        end
    end
    return false
end

local function updateFruits()
    fruits = {}
    local maxCount = tonumber(getgenv().fruit) or 1
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local fValue = tool:GetAttribute("f")
            local bValue = tool:GetAttribute("b")
            if fValue ~= nil and bValue == "j" and isSelectedFruitType(fValue) then
                table.insert(fruits, tool)
                if #fruits >= maxCount then
                    break
                end
            end
        end
    end
end

updateFruits()

RunService.RenderStepped:Connect(function()
    if not getgenv().eggEnhance then
        return
    end
    updateFruits()
    for _, tool in ipairs(fruits) do
        if tool and tool.Parent == Backpack then
            favoriteEvent:FireServer(tool)
        end
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("JayHubScripts")
SaveManager:SetFolder("JayHubScripts/Script-Game")
InterfaceManager:BuildInterfaceSection(settings_tab)
SaveManager:BuildConfigSection(settings_tab)

Fluent:Notify({
    Title = "Jay Hub - Free Scripts",
    Content = "Jay Hub has been loaded.",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()
