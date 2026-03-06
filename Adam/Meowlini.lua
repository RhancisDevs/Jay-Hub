local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

local BrainrotsConfig = require(
    ReplicatedStorage.Shared.Config.Brainrots
)

local webhookUrl = "https://discord.com/api/webhooks/1381214845776564265/EutjzKA0Ud0v495QPHwnOs4aFaPA_mB62J7bBxLVuP90ZXxSJfpqMt_sjDwyeialqV11"
local brainrotNameTarget = "Draculini Meowlini"

local requestFunc =
    syn and syn.request or
    http_request or
    request or
    fluxus and fluxus.request

local oldItems = {}

for _,tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") then
        oldItems[tool.Name] = true
    end
end

local function timeNow()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function sendWebhook(brainrotName, level, mutation, sizeName)
    if not requestFunc then
        return
    end

    local data = {
        embeds = {{
            title = "🍀 Lucky Dupe",
            fields = {
                {name="👨 Player",value=player.Name,inline=false},
                {name="🧠 Brainrot Name",value=tostring(brainrotName),inline=false},
                {name="⭐ Level",value=tostring(level),inline=true},
                {name="🧬 Mutation",value=tostring(mutation),inline=true},
                {name="📏 Size",value=tostring(sizeName),inline=false}
            },
            footer = {
                text = "Made with ❤️ by Jay Devs • "..timeNow()
            }
        }}
    }

    pcall(function()
        requestFunc({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function checkForNewTool()
    for _,tool in ipairs(backpack:GetChildren()) do
        if not tool:IsA("Tool") then
            continue
        end

        if oldItems[tool.Name] then
            continue
        end

        local brainrotName = tool:GetAttribute("BrainrotName")

        if brainrotName ~= brainrotNameTarget then
            continue
        end

        oldItems[tool.Name] = true

        local level = tool:GetAttribute("Level") or "Unknown"
        local mutation = tool:GetAttribute("Mutation") or "None"

        local scale = tool:GetAttribute("Scale")
        local sizeName = scale and BrainrotsConfig.GetSizeNameFromScale(scale) or "No Size"

        sendWebhook(brainrotName, level, mutation, sizeName)
    end
end

local function equipTool()
    local char = player.Character or player.CharacterAdded:Wait()

    local humanoid = char:WaitForChild("Humanoid", 2)
    if not humanoid then
        return false
    end

    local bestTool = nil
    local highestScale = -math.huge

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if tool:GetAttribute("BrainrotName") == brainrotNameTarget then
                local scale = tool:GetAttribute("Scale")

                if scale ~= nil then
                    if scale > highestScale then
                        highestScale = scale
                        bestTool = tool
                    end
                end
            end
        end
    end

    if not bestTool then
        warn("No tool found with BrainrotName =", brainrotNameTarget, "and valid Scale")
        return false
    end

    humanoid:EquipTool(bestTool)
    return true
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

    if text:find("dupe") then
        Fluent:Notify({
          Title = "Lucky Dupe",
          Content = "Brainrot Dupe Successfully!",
          Duration = 6
        })
        checkForNewTool()
    elseif text:find("no brainrots") then
        equipTool()
    end
end)

local remote = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Networking"):WaitForChild("RF/SpawnMachineAction")

local shop = workspace.GameObjects.PlaceSpecific.root.SpawnMachines

local machines = {
    ATM = true,
    Blackhole = true,
    Valentines = true,
    Arcade = true,
    Doom = true,
    FireAndIce = true
}

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
    for _,obj in ipairs(shop:GetChildren()) do
        if machines[obj.Name] then
            return obj
        end
    end
end

player.CharacterAdded:Connect(function()
    task.wait(1)

    backpack = player:WaitForChild("Backpack")

    local machine = getActiveMachine()
    if not machine then return end

    if not machineHasBrainrot(machine) then
        equipTool()
    end
end)

task.spawn(function()
    while true do
        local machine = getActiveMachine()

        if machine then
            local hrp = getHRP()
            local targetCFrame = machine:GetPivot() * CFrame.new(0,3,0)

            if (hrp.Position - targetCFrame.Position).Magnitude > 5 then
                hrp.CFrame = targetCFrame
            end

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
        end

        task.wait(1)
    end
end)

Fluent:Notify({
    Title = "Jay Auto Farm",
    Content = "Autofarm started successfully",
    Duration = 15
})

local function Addcantsleep()
    if (getconnections or get_signal_cons) then
        for i, v in pairs((getconnections or get_signal_cons)(player.Idled)) do
            if v["Disable"] then
                v["Disable"](v)
            elseif v["Disconnect"] then
                v["Disconnect"](v)
            end
        end
    end
end

pcall(function()
    Addcantsleep()
end)
