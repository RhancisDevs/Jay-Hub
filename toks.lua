local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local TradePurchase = GameEvents:WaitForChild("TradeEvents"):WaitForChild("TradeTokens"):WaitForChild("Purchase")

local request = request or http_request or syn and syn.request

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. MarketplaceService:GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    Icon = "code",
    TabWidth = 180,
    Size = UDim2.fromOffset(525, 380),
    Acrylic = true,
    Theme = "AMOLED",
    MinimizeKey = Enum.KeyCode.LeftControl,
    UserInfo = true,
    UserInfoTop = true,
    UserInfoTitle = Players.LocalPlayer.DisplayName,
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
Window:SelectTab(1)

local storeItems = {}
local selectedProductId = nil
local ItemDropdown

local function fetchItems()
    if not request then
        return {}
    end

    local ok, res = pcall(function()
        return request({
            Url = "https://jayhubgagproducts.onrender.com/gag",
            Method = "GET"
        })
    end)

    if not ok or not res or res.StatusCode ~= 200 then
        return {}
    end

    local data = HttpService:JSONDecode(res.Body)
    storeItems = {}
    local names = {}

    for _, wrapper in ipairs(data) do
        local item = wrapper.Product
        if item and item.Id and item.Name then
            storeItems[item.Name] = item
            table.insert(names, item.Name)
        end
    end

    return names
end

local itemsFetched = fetchItems()
if #itemsFetched == 0 then
    itemsFetched = {"No Items"}
end

ItemDropdown = main_tab:AddDropdown("ItemList", {
    Title = "Item List",
    Values = itemsFetched,
    Multi = false,
    Default = 1
})

ItemDropdown:OnChanged(function(value)
    local item = storeItems[value]
    if item then
        selectedProductId = item.Id
        Fluent:Notify({
            Title = "Jay Hub",
            Content = "You Select " .. item.Name .. " with " .. tostring(item.Price),
            Duration = 3
        })
    else
        selectedProductId = nil
    end
end)

main_tab:AddButton({
    Title = "Purchase Item",
    Callback = function()
        if selectedProductId then
            TradePurchase:InvokeServer(selectedProductId)
        else
            Fluent:Notify({
                Title = "Jay Hub",
                Content = "No item selected",
                Duration = 3
            })
        end
    end
})
