local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

local BrainrotsConfig = require(
    ReplicatedStorage.Shared.Config.Brainrots
)

local webhookUrl = "https://discord.com/api/webhooks/1066298551539343390/E9cgDoZlKj6rdvbRBhVYlaNNC0ZcGHRkPc1u8GRNaNyg8ErykAZ2BCBrRFPQ0SI_yvNh"
local brainrotNameTarget = "Martino Gravitino"

local function timeNow()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local requestFunc =
    syn and syn.request or
    http_request or
    request or
    fluxus and fluxus.request

local oldItems = {}

for _, tool in pairs(backpack:GetChildren()) do
    if tool:IsA("Tool") then
        table.insert(oldItems, tool.Name)
    end
end

local function isOldItem(name)
    return table.find(oldItems, name) ~= nil
end

local function sendWebhook(brainrotName, level, mutation, sizeName)
    if not requestFunc then return end

    local data = {
        embeds = {{
            title = "🍀 Lucky Dupe Event",
            fields = {
                {
                    name = "🧠 Brainrot Name",
                    value = tostring(brainrotName),
                    inline = false
                },
                {
                    name = "⭐ Level",
                    value = tostring(level),
                    inline = true
                },
                {
                    name = "🧬 Mutation",
                    value = tostring(mutation),
                    inline = true
                },
                {
                    name = "📏 Size",
                    value = tostring(sizeName),
                    inline = false
                }
            },
            footer = {
                text = "Made with ❤️ by Jay Devs • " .. timeNow()
            }
        }}
    }

    requestFunc({
        Url = webhookUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(data)
    })
end

local function checkForNewTool()
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and not isOldItem(tool.Name) then
            table.insert(oldItems, tool.Name)

            local brainrotName = tool:GetAttribute("BrainrotName") or tool.Name
            local level = tool:GetAttribute("Level") or "Unknown"
            local mutation = tool:GetAttribute("Mutation") or "None"
            local scale = tool:GetAttribute("Scale") or 1

            local sizeName = BrainrotsConfig.GetSizeNameFromScale(scale)

            sendWebhook(brainrotName, level, mutation, sizeName)
        end
    end
end

local function equipTool()
    local char = player.Character
    if not char then return false end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped and equipped:GetAttribute("BrainrotName") == brainrotNameTarget then
        return true
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("BrainrotName") == brainrotNameTarget then
            humanoid:EquipTool(tool)
            return true
        end
    end

    return false
end

local notificationsFolder =
    player:WaitForChild("PlayerGui")
    :WaitForChild("NewNotifications")
    :WaitForChild("Items")

notificationsFolder.ChildAdded:Connect(function(child)
    task.wait(0.1)

    local label = child:FindFirstChildWhichIsA("TextLabel", true)
    if not label then return end

    local text = label.Text:lower()

    if text:find("duped") then
        checkForNewTool()
    elseif text:find("no brainrots") then
        equipTool()
    end
end)

local remote = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("Net")
    :WaitForChild("RF/SpawnMachine.Action")

local shop = workspace:WaitForChild("SpawnMachines")

local machines = { "ATM", "Blackhole", "Valentines", "Arcade" }

local lastTick = 0

local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function machineHasBrainrot(machine)
    local brainrots = machine:FindFirstChild("Brainrots", true)
    if not brainrots then return false end

    local empty = brainrots:FindFirstChild("Empty", true)
    if not empty then return false end

    return empty.Visible == false
end

local function getActiveMachine()
    for _, obj in ipairs(shop:GetChildren()) do
        for _, name in ipairs(machines) do
            if obj.Name == name then
                return obj
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if tick() - lastTick < 1 then return end
    lastTick = tick()

    local machine = getActiveMachine()
    if not machine then return end

    local hrp = getHRP()
    hrp.CFrame = machine:GetPivot() * CFrame.new(0, 3, 0)

    task.wait(0.25)

    if not machineHasBrainrot(machine) then
        local success = equipTool()

        if success then
            task.wait(0.15)
            remote:InvokeServer("Deposit", machine)
            task.wait(0.25)
        end
    end

    remote:InvokeServer("Combine", machine)
end)

print("READY TO GO")
