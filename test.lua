local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character:WaitForChild("Humanoid")

if getgenv().jaydevs then return end
getgenv().jaydevs = true

getgenv().selected_pet_uuid = nil
getgenv().selected_mutation = nil
getgenv().pet_list = {}
getgenv().auto_mutate_running = false
getgenv().webhook_enabled = false
getgenv().webhook_url = ""
getgenv().auto_switch_enabled = false
getgenv().age_team = 1
getgenv().golem_team = 2

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

local function sendWebhook(firstWord)
    if not getgenv().webhook_enabled or getgenv().webhook_url == "" then return end
    local payload = {
        embeds = {{
            title = "🎉 You got mutation you want!",
            color = 0x00FF00,
            fields = {{
                name = "Mutation:",
                value = firstWord
            }},
            footer = {
                text = "Made with ❤️ by Jay Hub | " .. os.date("%I:%M %p")
            }
        }}
    }
    request({
        Url = getgenv().webhook_url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    })
end

local jay = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = jay:CreateWindow({
    Title = "Jay Hub | " .. game:GetService("MarketplaceService"):GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    TabWidth = 150,
    Size = UDim2.fromOffset(480, 350),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.Insert
})

do
    local ClickButton = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local ImageLabel = Instance.new("ImageLabel")
    local TextButton = Instance.new("TextButton")
    local UICorner = Instance.new("UICorner")
    local UICorner_2 = Instance.new("UICorner")

    ClickButton.Name = "ClickButton"
    ClickButton.Parent = game.CoreGui
    ClickButton.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ClickButton
    MainFrame.AnchorPoint = Vector2.new(1, 0)
    MainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(1, -60, 0, 10)
    MainFrame.Size = UDim2.new(0, 45, 0, 45)
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = MainFrame

    UICorner_2.CornerRadius = UDim.new(0, 10)
    UICorner_2.Parent = ImageLabel

    ImageLabel.Parent = MainFrame
    ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel.BackgroundColor3 = Color3.new(0, 0, 0)
    ImageLabel.BorderSizePixel = 0
    ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel.Size = UDim2.new(0, 45, 0, 45)
    ImageLabel.Image = "rbxassetid://132940723895184"

    TextButton.Parent = MainFrame
    TextButton.BackgroundTransparency = 1
    TextButton.Size = UDim2.new(1, 0, 1, 0)
    TextButton.Text = ""
    TextButton.MouseButton1Click:Connect(function()
        game:GetService("VirtualInputManager"):SendKeyEvent(true, "Insert", false, game)
        game:GetService("VirtualInputManager"):SendKeyEvent(false, "Insert", false, game)
    end)
end

local info_tab = Window:AddTab({ Title = "Info", Icon = "info" })
local main_tab = Window:AddTab({ Title = "Main", Icon = "home" })
local switch_tab = Window:AddTab({ Title = "Auto Switch", Icon = "refresh-cw" })
local webhook_tab = Window:AddTab({ Title = "Webhook", Icon = "bell" })
Window:SelectTab(1)

info_tab:AddParagraph({
    Title = "Welcome",
    Content = "Welcome to Jay Hub!\nBasic Need of a Scripter!"
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

local mutation_dropdown = main_tab:AddDropdown("MutationDropdown", {
    Title = "Select Mutation",
    Values = getgenv().all_mutations,
    Multi = false,
    Default = 1
})

mutation_dropdown:OnChanged(function(selected)
    getgenv().selected_mutation = selected
end)

local age_team_dropdown = switch_tab:AddDropdown("AgeTeamDropdown", {
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

local golem_team_dropdown = switch_tab:AddDropdown("GolemTeamDropdown", {
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

local auto_switch_toggle = switch_tab:AddToggle("AutoSwitchToggle", {
    Title = "Auto Switch Load",
    Default = false
})

auto_switch_toggle:OnChanged(function(state)
    getgenv().auto_switch_enabled = state
end)

local auto_toggle = main_tab:AddToggle("AutoMutateToggle", {
    Title = "Auto Mutate Pet",
    Default = false
})

webhook_tab:AddInput("WebhookURLInput", {
    Title = "Webhook URL",
    Default = "",
    Placeholder = "Enter your Discord webhook URL",
    Callback = function(url)
        getgenv().webhook_url = url
    end
})

webhook_tab:AddToggle("WebhookToggle", {
    Title = "Webhook Mutation",
    Description = "To notify you if you got your desire mutation!",
    Default = false
}):OnChanged(function(state)
    getgenv().webhook_enabled = state
end)

auto_toggle:OnChanged(function(state)
    getgenv().auto_mutate_running = state
    if state then
        task.spawn(function()
            while getgenv().auto_mutate_running do
                if not getgenv().selected_pet_uuid or not getgenv().selected_mutation then
                    task.wait(1)
                    continue
                end

                local pet_frame = LocalPlayer.PlayerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame:FindFirstChild(getgenv().selected_pet_uuid)
                if pet_frame and pet_frame.Main:FindFirstChild("PET_AGE") then
                    local age_str = pet_frame.Main.PET_AGE.Text
                    local age_num = tonumber(age_str:match("Age:%s*(%d+)"))

                    if age_num and age_num >= 50 then
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
                                    sendWebhook(first_word)
                                    getgenv().auto_mutate_running = false
                                else
                                    ReplicatedStorage.GameEvents.PetsService:FireServer("EquipPet", getgenv().selected_pet_uuid, CFrame.new(42.797, 0, -79.888))
                                end
                                break
                            end
                        end
                    end
                end

                task.wait(1)
            end
        end)
    end
end)
