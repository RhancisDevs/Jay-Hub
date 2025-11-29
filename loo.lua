local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local favoriteEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Favorite_Item")

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. game:GetService("MarketplaceService"):GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    Icon = "132940723895184",
    TabWidth = 180,
    Size = UDim2.fromOffset(490, 360),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
    UserInfo = true,
    UserInfoTop = true,
    UserInfoTitle = game:GetService("Players").LocalPlayer.DisplayName,
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

main_tab:AddToggle("EggEnhanceToggle", {
    Title = "Egg Enhance",
    Default = getgenv().eggEnhance or false
}):OnChanged(function(state)
    getgenv().eggEnhance = state
    print("Egg Enhance:", state and "ON" or "OFF")
end)

local fruits = {}

local function updateFruits()
    fruits = {}
    for _, tool in ipairs(Backpack:GetChildren()) do
        if tool:GetAttribute("f") ~= nil and tool:GetAttribute("b") == "j" then
            table.insert(fruits, tool)
            if #fruits == getgenv().fruit then
                break
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
