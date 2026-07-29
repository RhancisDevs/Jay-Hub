if not game:IsLoaded() then game.Loaded:Wait() end
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local PlayerState = require(ReplicatedStorage.ClientModules.PlayerStateClient)

local Replica = PlayerState:GetLocalReplica()

local SETTINGS = getgenv().settings

local Selling = false

local function GetMoney()
    return (Replica and Replica.Data and Replica.Data.Sheckles) or 0
end

local function ClaimAllGifts()
    local ok, mailbox = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)

    if not ok or type(mailbox) ~= "table" then
        return 0
    end

    local claimed = 0

    for giftId in pairs(mailbox) do
        local success = pcall(function()
            return Networking.Mailbox.Claim:Fire(giftId)
        end)

        if success then
            claimed += 1
        end

        task.wait(0.5)
    end

    if claimed > 0 then
        print(string.format("[Mail] Claimed %d gift(s).", claimed))
    end

    return claimed
end

local function SellEverything()
    if Selling then
        return
    end

    Selling = true

    print(string.format(
        "[Sell] Selling inventory (Money: %s)...",
        GetMoney()
    ))

    local ok, result = pcall(function()
        return Networking.NPCS.UseDailyDealAll:Fire()
    end)

    if ok and result then
        if result.Success then
            print(string.format(
                "[Sell] Sold %d item(s) for %s.",
                result.SoldCount,
                result.SellPrice
            ))
        elseif result.Reason == "NotAvailable" then
            print("[Sell] Daily deal expired.")
        else
            print("[Sell] Sell failed.")
        end
    else
        warn("[Sell] Remote failed.")
    end

    Selling = false
end

task.spawn(function()
    while true do
        if SETTINGS.AutoAcceptMail then
            ClaimAllGifts()
        end

        task.wait(SETTINGS.MailCheckDelay)
    end
end)

if Replica then
    Replica:OnChange(function(_, path)
        if not SETTINGS.AutoSell then
            return
        end

        if path[1] ~= "Sheckles" then
            return
        end

        local money = Replica.Data.Sheckles

        print("[Money]", money)

        if money >= SETTINGS.SellAt then
            SellEverything()
        end
    end)

    task.defer(function()
        if SETTINGS.AutoSell and GetMoney() >= SETTINGS.SellAt then
            SellEverything()
        end
    end)
end
