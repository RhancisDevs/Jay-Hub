getgenv().Jay = "Jaypogi"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local success, response = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/RhancisDevs/Allowed-User/refs/heads/main/allowed-user.json")
end)

if success then
    local allowedUsers = {}
    for name in string.gmatch(response, "[^\r\n]+") do
        allowedUsers[name] = true
    end

    if allowedUsers[LocalPlayer.Name] then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/RhancisDevs/Walastik/main/muts.lua"))()
    else
        LocalPlayer:Kick("Not allowed to use this script! Contact Eren Yeager for any issue.")
    end
else
    LocalPlayer:Kick("Failed to fetch whitelist. Try again later.")
end
