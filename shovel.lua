getgenv().Fruit = "Bone Blossom"
getgenv().Weight = 20
getgenv().IgnoreFavorite = true
getgenv().autoShovel = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local GetFarm = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GetFarm"))
local RemoveItemEvent = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Remove_Item")

local function removeFruits()
    local farm = GetFarm(LocalPlayer)
    if not farm then return end

    local plantsPhysical = farm:FindFirstChild("Important") and farm.Important:FindFirstChild("Plants_Physical")
    if not plantsPhysical then return end

    local fruitPlant = plantsPhysical:FindFirstChild(getgenv().Fruit)
    if not fruitPlant then return end

    local fruitsFolder = fruitPlant:FindFirstChild("Fruits")
    if not fruitsFolder then return end

    for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
        local base = fruitModel:FindFirstChild("Base") or fruitModel:FindFirstChild("PrimaryPart")
        local weightValue = fruitModel:FindFirstChild("Weight")
        local isFavorited = fruitModel:GetAttribute("Favorited")

        if weightValue then
            local tooHeavy = weightValue.Value > getgenv().Weight
            local isIgnoredFavorite = getgenv().IgnoreFavorite and isFavorited == true

            if not tooHeavy and not isIgnoredFavorite then
                RemoveItemEvent:FireServer(base)
                task.wait(0.05)
            end
        end
    end
end

while getgenv().autoShovel do
    removeFruits()
    task.wait(0.2)
end
