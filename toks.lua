local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
local TradePurchase = GameEvents
    :WaitForChild("TradeEvents")
    :WaitForChild("TradeTokens")
    :WaitForChild("Purchase")

local Fluent = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"
))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. MarketplaceService:GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    TabWidth = 180,
    Size = UDim2.fromOffset(525, 380),
    Theme = "AMOLED"
})

local main_tab = Window:AddTab({ Title = "Main", Icon = "home" })
Window:SelectTab(1)

local DeveloperProductIds = {
    1234567890,
    2345678901,
    3456789012
}

local storeItems = {}
local dropdownValues = {}
local selectedProductId = nil

for _, productId in ipairs(DeveloperProductIds) do
    local success, info = pcall(function()
        return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
    end)

    if success and info then
        storeItems[info.Name] = {
            Id = productId,
            Name = info.Name,
            Price = info.PriceInRobux
        }
        table.insert(dropdownValues, info.Name)
    end
end

if #dropdownValues == 0 then
    dropdownValues = { "No Items" }
end

local ItemDropdown = main_tab:AddDropdown("ItemList", {
    Title = "Item List",
    Values = dropdownValues,
    Multi = false,
    Default = 1
})

ItemDropdown:OnChanged(function(selectedName)
    local item = storeItems[selectedName]
    if item then
        selectedProductId = item.Id
        Fluent:Notify({
            Title = "Jay Hub",
            Content = item.Name .. " | Price: " .. tostring(item.Price),
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
