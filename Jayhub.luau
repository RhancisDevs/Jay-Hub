if getgenv().jaydevs then return end
getgenv().jaydevs = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character:WaitForChild("Humanoid")
local DataService = require(ReplicatedStorage.Modules.DataService)

getgenv().selected_pet_uuid = nil
getgenv().selected_mutation = nil
getgenv().pet_list = {}
getgenv().auto_mutate_running = false
getgenv().webhook_enabled = false
getgenv().webhook_cycle = false
getgenv().webhook_url = ""
getgenv().auto_switch_enabled = false
getgenv().age_team = 1
getgenv().golem_team = 2
local mutation_cycle = 0
getgenv().age_team_slot = 1
getgenv().nightmare_team_slot = 2
getgenv().hh_pet_type = nil
getgenv().nightmare_notifier = false
local running = false
local stopFlag = false

getgenv().all_mutations = {
    "Shiny", "Inverted", "Frozen", "Windy", "Mega", "Tiny", "Golden",
    "Ironskin", "Rainbow", "Shocked", "Radiant", "Ascended"
}

local PetsService = ReplicatedStorage.GameEvents.PetsService

local function switchTeam(slotNum)
    if not slotNum then return end
    if slotNum == 3 then
        slotNum = 2
    elseif slotNum == 2 then
        slotNum = 3
    end
    local args = {"SwapPetLoadout", slotNum}
    PetsService:FireServer(unpack(args))
    task.wait(1)
end

local function getPetData(petId)
    local data = DataService:GetData()
    if data and data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data then
        local petData = data.PetsData.PetInventory.Data[petId]
        if petData and petData.PetData and petData.PetData.Level then
            return petData
        end
    end
    return nil
end

local function sendWebhook(data)
    if not getgenv().webhook_enabled or getgenv().webhook_url == "" then return end
    request({
        Url = getgenv().webhook_url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end

local function find_headless_horseman_owned_petMover()
    local petsFolder = Workspace:WaitForChild("PetsPhysical")

    for _, petMover in ipairs(petsFolder:GetChildren()) do
        if petMover and petMover.GetAttribute then
            local owner = petMover:GetAttribute("OWNER")
            local uuid = petMover:GetAttribute("UUID")
            if owner == LocalPlayer.Name and uuid then
                local pd = getPetData(uuid)
                if pd.PetType then
                    local nameLower = string.lower(pd.PetType)
                    if string.find(nameLower, "headless horseman") then
                        return uuid, petMover
                    end
                end
            end
        end
        task.wait()
    end

    return nil, nil
end

local function is_passive_ready(uuid)
    if not uuid then return false end
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("GetPetCooldown")
    end)
    if not ok then return false end
    local cd = remote:InvokeServer(uuid)
    print(cd[1].Time)
    return cd[1].Time == 0
end

local function cleanse_selected_pet(selected_uuid)
    if not selected_uuid then return false end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local char = player.Character or player.CharacterAdded:Wait()

    local petsFolder = Workspace:WaitForChild("PetsPhysical")
    local petInstance = nil

    for _, mover in ipairs(petsFolder:GetChildren()) do
        if mover:IsA("BasePart") or mover:IsA("Model") then
            local petChild = mover:FindFirstChild(selected_uuid)
            if petChild then
                petInstance = petChild
                break
            end
        end
        task.wait()
    end

    if not petInstance then
        warn("[AutoNM] cleanse_selected_pet FAILED: No instance for UUID:", selected_uuid)
        return false
    end

    local shardTool = nil

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("u") == "Cleansing Pet Shard" then
            shardTool = tool
            break
        end
    end

    if not shardTool then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("u") == "Cleansing Pet Shard" then
                shardTool = tool
                break
            end
        end
    end

    if not shardTool then
        warn("[AutoNM] cleanse_selected_pet FAILED: Shard tool not found.")
        return false
    end

    local originalParent = shardTool.Parent
    shardTool.Parent = char
    task.wait(0.15)

    local shardRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")
    local ok, err = pcall(function()
        shardRemote:FireServer("ApplyShard", petInstance)
    end)

    shardTool.Parent = originalParent

    if not ok then
        warn("[AutoNM] cleanse_selected_pet FireServer error:", err)
        return false
    end

    print("[AutoNM] Successfully cleansed for UUID:", selected_uuid)
    return true
end

local function check_selected_pet_is_nightmare(selected_uuid)
    local pd = getPetData(selected_uuid)
    return pd.PetData.MutationType == "A"
end

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/discoart/FluentPlus/refs/heads/main/Beta.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Jay Hub | " .. game:GetService("MarketplaceService"):GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    Icon = "chevrons-left-right",
    TabWidth = 180,
    Size = UDim2.fromOffset(525, 380),
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
  Icon = "chevrons-left-right",
  Size = UDim2.fromOffset(44, 44),
  Position = UDim2.new(0, 320, 0, 24),
  Acrylic = true,
  Corner = 10,
  Transparency = 1,
  Draggable = true,
  Visible = true
})

local info_tab = Window:AddTab({ Title = "Info", Icon = "info" })
local main_tab = Window:AddTab({ Title = "Main", Icon = "home" })
local switch_tab = Window:AddTab({ Title = "Auto Switch", Icon = "refresh-cw" })
local webhook_tab = Window:AddTab({ Title = "Webhook", Icon = "bell" })
local settings_tab = Window:AddTab({ Title = "Settings", Icon = "settings" })
Window:SelectTab(1)

info_tab:AddParagraph({
    Title = "Change Logs",
    Content = "Version 3.0.5\nWhat's new?\n"
})

local pet_list_dropdown = main_tab:AddDropdown("PetListDropdown", {
    Title = "Pet List",
    Values = {},
    Multi = false,
    Default = "Select pet here"
})

main_tab:AddButton({
    Title = "Refresh Pet List",
    Callback = function()
        getgenv().pet_list = {}
        local scrolling_frame = LocalPlayer.PlayerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame

        for _, child in pairs(scrolling_frame:GetChildren()) do
            if child.ClassName == "Frame"
               and child.Name ~= "PetTemplate"
               and child:FindFirstChild("Main")
               and child.Main:FindFirstChild("PET_TYPE")
               and child.Main:FindFirstChild("PET_NAME")
               and child.Main:FindFirstChild("PET_AGE") then

                local pet_type = child.Main.PET_TYPE.Text
                local pet_name = child.Main.PET_NAME.Text
                local pet_age = child.Main.PET_AGE.Text
                local display = string.format("%s [%s, %s]", pet_type, pet_name, pet_age)

                table.insert(getgenv().pet_list, { uuid = child.Name, name = display })
            end
        end

        local display_names = {}
        for _, pet in ipairs(getgenv().pet_list) do
            table.insert(display_names, pet.name)
        end
        pet_list_dropdown:SetValues(display_names)
    end
})

pet_list_dropdown:OnChanged(function(selected)
    for _, pet in ipairs(getgenv().pet_list) do
        if pet.name == selected then
            getgenv().selected_pet_uuid = pet.uuid
        end
    end
end)

local mainTab = main_tab:AddSection("Auto Mutation")

local mutation_dropdown = mainTab:AddDropdown("MutationDropdown", {
    Title = "Select Mutation",
    Values = getgenv().all_mutations,
    Multi = false,
    Default = 1
})

mutation_dropdown:OnChanged(function(selected)
    getgenv().selected_mutation = selected
end)

local AutoMuts = mainTab:AddToggle("AutoMutateToggle", {
    Title = "Auto Mutate Pet",
    Default = false
})

AutoMuts:OnChanged(function(state)
    getgenv().auto_mutate_running = state
    if state then
        task.spawn(function()
            while getgenv().auto_mutate_running do
                if not getgenv().selected_pet_uuid or not getgenv().selected_mutation then
                    task.wait(1)
                    continue
                end

                local age_num = getPetData(getgenv().selected_pet_uuid)
                ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("StartMachine")
                if age_num.PetData.Level >= 50 then
                    mutation_cycle += 1

                    if getgenv().webhook_cycle then
                        sendWebhook({
                            embeds = {{
                                title = "🔁 Starting Mutation Cycle " .. mutation_cycle,
                                color = 0x3498DB,
                                footer = {
                                    text = "Made ❤️ by Jay Hub | " .. os.date("%I:%M %p")
                                }
                            }}
                        })
                    end

                    ReplicatedStorage.GameEvents.PetsService:FireServer("UnequipPet", getgenv().selected_pet_uuid)
                    task.wait(0.5)

                    local bp = LocalPlayer.Backpack
                    for _, tool in pairs(bp:GetChildren()) do
                        if tool:GetAttribute("PET_UUID") == getgenv().selected_pet_uuid then
                            Humanoid:EquipTool(tool)
                            break
                        end
                    end

                    task.wait(0.5)
                    ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("SubmitHeldPet")
                    task.wait(0.5)

                    if getgenv().auto_switch_enabled and getgenv().age_team ~= getgenv().golem_team then
                        switchTeam(getgenv().golem_team)
                    end

                    ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("StartMachine")
                    local timer_label = Workspace.NPCS.PetMutationMachine.Model:GetChildren()[10].BillboardPart.BillboardGui.TimerTextLabel
                    repeat task.wait(1) until timer_label.Text == "READY"

                    ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("ClaimMutatedPet")
                    task.wait(1)

                    if getgenv().auto_switch_enabled and getgenv().age_team ~= getgenv().golem_team then
                        switchTeam(getgenv().age_team)
                    end

                    task.wait(3)
                    bp = LocalPlayer.Backpack
                    for _, tool in pairs(bp:GetChildren()) do
                        if tool:GetAttribute("PET_UUID") == getgenv().selected_pet_uuid then
                            local first_word = tool.Name:match("^(%S+)")
                            if first_word == getgenv().selected_mutation then
                                sendWebhook({
                                    content = "@everyone PALDO",
                                    embeds = {{
                                        title = "SUCCESS!",
                                        description = "🎉 Got mutation: **" .. first_word .. "** in Cycle " .. mutation_cycle,
                                        color = 0x00FF00,
                                        footer = {
                                            text = "Made ❤️ by Jay Hub | " .. os.date("%I:%M %p")
                                        }
                                    }}
                                })
                                mutation_cycle = 0
                                getgenv().auto_mutate_running = false
                            else
                                if getgenv().webhook_cycle then
                                    sendWebhook({
                                        embeds = {{
                                            title = "🔁 Mutation Cycle " .. mutation_cycle,
                                            color = 0x3498DB,
                                            fields = {{
                                                name = "Mutation:",
                                                value = first_word
                                            }},
                                            footer = {
                                                text = "Made ❤️ by Jay Hub | " .. os.date("%I:%M %p")
                                            }
                                        }}
                                    })
                                end
                                ReplicatedStorage.GameEvents.PetsService:FireServer("EquipPet", getgenv().selected_pet_uuid, CFrame.new(42.797, 0, -79.888))
                            end
                            break
                        end
                    end
                end
                task.wait(1)
            end
        end)
    end
end)

local NMMTab = main_tab:AddSection("Auto Nightmare Pet")

local hhDropdown = NMMTab:AddDropdown("HHDropdown", {
    Title = "HH Pet Type",
    Multi = false,
    Values = {"Ghostly Headless Horseman", "Headless Horseman"},
    Default = 1
})

hhDropdown:OnChanged(function(selected)
    getgenv().hh_pet_type = selected
end)

local AutoNM = NMMTab:AddToggle("AutoNightmareToggle", {
    Title = "Auto Nightmare Pet",
    Enabled = false,
    Default = false
})

AutoNM:OnChanged(function(state)
    getgenv().auto_nightmare_running = state
    if state then
        task.spawn(function()
            mutation_cycle = 0

            while getgenv().auto_nightmare_running do
                local selected_uuid = getgenv().selected_pet_uuid
                if not selected_uuid then task.wait(1) continue end

                local pd = getPetData(selected_uuid)
                if not pd then task.wait(1) continue end

                local requiredAge = (getgenv().hh_pet_type == "Ghostly Headless Horseman") and 20 or 40

                if pd.PetData.Level < requiredAge then
                    switchTeam(getgenv().age_team_slot)
                    repeat
                        task.wait(2)
                        pd = getPetData(selected_uuid)
                    until not getgenv().auto_nightmare_running or pd.PetData.Level >= requiredAge
                end

                if not getgenv().auto_nightmare_running then break end

                switchTeam(getgenv().nightmare_team_slot)
                task.wait(5)

                local headless_uuid, petMover
                repeat
                    headless_uuid, petMover = find_headless_horseman_owned_petMover()
                    if not headless_uuid then
                        print("HH not found, retrying...")
                        task.wait(2)
                    end
                until headless_uuid

                local ready = false
                for i = 1, 5 do
                    if is_passive_ready(headless_uuid) then
                        ready = true
                        break
                    end
                    task.wait(0.5)
                end
                if not ready then task.wait(1) continue end

                mutation_cycle = mutation_cycle + 1
                task.wait(10)

                local muts = getPetData(selected_uuid)
                if muts.PetData.MutationType == "A" then
                    if getgenv().nightmare_notifier then
                        sendWebhook({
                            embeds = {{
                                title = "✅ Nightmare Success",
                                color = 0x2ecc71,
                                fields = {{
                                    name = "Mutation:",
                                    value = muts.PetType .. " has successfully mutated into Nightmare."
                                }},
                                footer = {
                                    text = "Made ❤️ by Jay Hub | " .. os.date("%I:%M %p")
                                }
                            }}
                        })
                    end
                    getgenv().auto_nightmare_running = false
                    break
                else
                    cleanse_selected_pet(selected_uuid)
                    cleanse_selected_pet(selected_uuid)
                    task.wait(1)
                    -- After failure, switch back to Age Team to level up again
                    if pd.PetData.Level < requiredAge then
                        switchTeam(getgenv().age_team_slot)
                    end

                    if getgenv().nightmare_notifier then
                        sendWebhook({
                            embeds = {{
                                title = "🔁 Mutation Cycle " .. mutation_cycle,
                                color = 0x3498DB,
                                fields = {{
                                    name = "Mutation:",
                                    value = muts.PetType .. " failed to get Nightmare. Repeating cycle..."
                                }},
                                footer = {
                                    text = "Made ❤️ by Jay Hub | " .. os.date("%I:%M %p")
                                }
                            }}
                        })
                    end
                    task.wait(3)
                end
            end
        end)
    end
end)

local mutsTab = switch_tab:AddSection("Auto Mutation Pet")

local age_team_dropdown = mutsTab:AddDropdown("AgeTeamDropdown", {
    Title = "Age Team",
    Values = {"1", "2", "3"},
    Multi = false,
    Default = "1"
})

age_team_dropdown:OnChanged(function(selected)
    getgenv().age_team = tonumber(selected)
    if getgenv().age_team == getgenv().golem_team then
        warn("Age Team and Golem Team cannot be the same.")
    end
end)

local golem_team_dropdown = mutsTab:AddDropdown("GolemTeamDropdown", {
    Title = "Golem Team",
    Values = {"1", "2", "3"},
    Multi = false,
    Default = "2"
})

golem_team_dropdown:OnChanged(function(selected)
    getgenv().golem_team = tonumber(selected)
    if getgenv().age_team == getgenv().golem_team then
        warn("Age Team and Golem Team cannot be the same.")
    end
end)

local auto_switch_toggle = mutsTab:AddToggle("AutoSwitchToggle", {
    Title = "Auto Switch Load",
    Default = false
})

auto_switch_toggle:OnChanged(function(state)
    getgenv().auto_switch_enabled = state
end)

local NMNTab = switch_tab:AddSection("Auto Nigthmare Pet")

local ageTeamDropdown = NMNTab:AddDropdown("AgeTeamDp", {
    Title = "Age Team",
    Multi = false,
    Values = {"1","2","3"},
    Default = "1"
})

ageTeamDropdown:OnChanged(function(selected)
    local num = tonumber(selected) or 1
    getgenv().age_team_slot = num
end)

local nightmareTeamDropdown = NMNTab:AddDropdown("NMTeamDP", {
    Title = "Nightmare Team",
    Multi = false,
    Values = {"1","2","3"},
    Default = "2"
})

nightmareTeamDropdown:OnChanged(function(selected)
    local num = tonumber(selected) or 2
    getgenv().nightmare_team_slot = num
end)

webhook_tab:AddInput("WebhookURLInput", {
    Title = "Webhook URL",
    Default = "",
    Placeholder = "Enter your Discord webhook URL",
    Callback = function(url)
        getgenv().webhook_url = url
    end
})

local mutsaTab = webhook_tab:AddSection("Auto Mutation Pet")

mutsaTab:AddToggle("WebhookToggle", {
    Title = "Mutation Notifier",
    Description = "To notify you if you got your desire mutation!",
    Default = false
}):OnChanged(function(state)
    getgenv().webhook_enabled = state
end)

mutsaTab:AddToggle("WebhookToggle", {
    Title = "Mutation Notifier Every Cycle",
    Description = "To notify you every cycle of mutation",
    Default = false
}):OnChanged(function(state)
    getgenv().webhook_cycle = state
end)

local NMTab = webhook_tab:AddSection("Auto Nigthmare Pet")

local notifyToggle = NMTab:AddToggle("NMToggle", {
    Title = "Nightmare Notifier",
    Description = "To notify you if your pet got nightmare mutation!",
    Default = false 
})

notifyToggle:OnChanged(function(state)
    getgenv().nightmare_notifier = state
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/Script-Game")
InterfaceManager:BuildInterfaceSection(settings_tab)
SaveManager:BuildConfigSection(settings_tab)

Fluent:Notify({
    Title = "Jay Hub - Free Scripts",
    Content = "Jay Hub has been loaded.",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()
