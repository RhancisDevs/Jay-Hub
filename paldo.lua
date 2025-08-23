if getgenv().jaydevs then
    return
end
getgenv().jaydevs = true

local jay = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", true))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Humanoid = LocalPlayer.Character:WaitForChild("Humanoid")

getgenv().selected_pet_uuid = nil
getgenv().selected_mutation = nil
getgenv().pet_list = {}
getgenv().auto_mutate_running = false
getgenv().webhook_enabled = false
getgenv().webhook_url = ""

getgenv().all_mutations = {
    "Shiny", "Inverted", "Frozen", "Windy", "Mega", "Tiny", "Golden",
    "Ironskin", "Rainbow", "Shocked", "Radiant", "Ascended"
}

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
                text = "Made with ❤️ by Jay Devs | Today at " .. os.date("%I:%M %p")
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

local Window = jay:CreateWindow({
    Title = "Jay Hub | " .. game:GetService("MarketplaceService"):GetProductInfo(126884695634066).Name,
    SubTitle = "by Jay Devs",
    TabWidth = 150,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.Insert
})

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
TextButton.BackgroundColor3 = Color3.new(1, 1, 1)
TextButton.BackgroundTransparency = 1
TextButton.BorderSizePixel = 0
TextButton.Position = UDim2.new(0, 0, 0, 0)
TextButton.Size = UDim2.new(0, 45, 0, 45)
TextButton.AutoButtonColor = false
TextButton.Font = Enum.Font.SourceSans
TextButton.Text = ""
TextButton.TextColor3 = Color3.new(1, 1, 1)
TextButton.TextSize = 20

TextButton.MouseButton1Click:Connect(function()
    game:GetService("VirtualInputManager"):SendKeyEvent(true, "Insert", false, game)
    game:GetService("VirtualInputManager"):SendKeyEvent(false, "Insert", false, game)
end)

local info_tab = Window:AddTab({ Title = "Info", Icon = "info" })
local main_tab = Window:AddTab({ Title = "EXP Farm", Icon = "home" })
local pet_tab  = Window:AddTab({ Title = "Pet Mutation", Icon = "activity" })
local webhook_tab = Window:AddTab({ Title = "Webhook", Icon = "link" })
Window:SelectTab(1)

info_tab:AddParagraph({
    Title = "Welcome",
    Content = "Welcome to Jay Hub! \nBasic Need of a Scripter!"
})

getgenv().mimic_id = nil
getgenv().dilo_id = nil
getgenv().target_id = nil
getgenv().auto_exp = false

local function get_pet_uuid()
    local tool = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then
        return tool:GetAttribute("PET_UUID")
    end
    return nil
end

main_tab:AddButton({
    Title = "Get Mimic ID",
    Description = "Hold the Mimic.",
    Callback = function()
        local uuid = get_pet_uuid()
        if uuid then
            getgenv().mimic_id = uuid
            print("Mimic UUID saved:", uuid)
        else
            warn("No Mimic PET_UUID found.")
        end
    end
})

main_tab:AddButton({
    Title = "Get Dilo ID",
    Description = "Hold the Dilo.",
    Callback = function()
        local uuid = get_pet_uuid()
        if uuid then
            getgenv().dilo_id = uuid
            print("Dilo UUID saved:", uuid)
        else
            warn("No Dilo PET_UUID found.")
        end
    end
})

main_tab:AddButton({
    Title = "Get Target Pet ID",
    Description = "Hold the Target Pet.",
    Callback = function()
        local uuid = get_pet_uuid()
        if uuid then
            getgenv().target_id = uuid
            print("Target Pet UUID saved:", uuid)
        else
            warn("No Target Pet PET_UUID found.")
        end
    end
})

main_tab:AddToggle("autoExpFarm", {
    Title = "Auto EXP Farm",
    Default = false,
    Callback = function(state)
        getgenv().auto_exp = state

        if not state then return end

        spawn(function()
            while getgenv().auto_exp do
                local mimic = getgenv().mimic_id
                local dilo = getgenv().dilo_id
                local target = getgenv().target_id

                if not (mimic and dilo and target) then
                    warn("Missing one or more UUIDs.")
                    break
                end

                game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", mimic, CFrame.new(42.7972, 0, -79.8887))

                game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", dilo, CFrame.new(42.7972, 0, -79.8887))

                wait(1)

                while getgenv().auto_exp do
                    local cd_data = game:GetService("ReplicatedStorage").GameEvents.GetPetCooldown:InvokeServer(mimic)
                    local mimic_cd = cd_data[1].Time

                    if mimic_cd == 0 then
                        wait(1.5)

                        game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet", dilo)

                        game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", target, CFrame.new(42.7972, 0, -79.8887))

                        repeat
                            wait(0.5)
                            local cd_check = game:GetService("ReplicatedStorage").GameEvents.GetPetCooldown:InvokeServer(mimic)
                            mimic_cd = cd_check[1].Time
                        until mimic_cd == 15 or not getgenv().auto_exp

                        game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("UnequipPet", target)

                        game:GetService("ReplicatedStorage").GameEvents.PetsService:FireServer("EquipPet", dilo, CFrame.new(42.7972, 0, -79.8887))
                    end

                    wait(0.5)
                end
            end
        end)
    end
})

local pet_list_dropdown = pet_tab:AddDropdown("PetListDropdown", {
    Title = "Pet List",
    Values = {},
    Multi = false,
    Default = "Select pet here"
})

pet_tab:AddButton({
    Title = "Refresh Pet List",
    Callback = function()
        getgenv().pet_list = {}
        local scrolling_frame = LocalPlayer.PlayerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame
        for _, child in pairs(scrolling_frame:GetChildren()) do
            if child.ClassName == "Frame" 
               and child.Name ~= "PetTemplate"
               and child:FindFirstChild("Main") 
               and child.Main:FindFirstChild("PET_TYPE") then
                local pet_name = child.Main.PET_TYPE.Text
                table.insert(getgenv().pet_list, { uuid = child.Name, name = pet_name })
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

local mutation_dropdown = pet_tab:AddDropdown("MutationDropdown", {
    Title = "Select Mutation",
    Values = getgenv().all_mutations,
    Multi = false,
    Default = 1
})

mutation_dropdown:OnChanged(function(selected)
    getgenv().selected_mutation = selected
end)

local auto_toggle = pet_tab:AddToggle("AutoMutateToggle", {
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
    Title = "On/Off Webhook Mutation",
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
                        ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("StartMachine")
                        local timer_label = Workspace.NPCS.PetMutationMachine.Model:GetChildren()[10].BillboardPart.BillboardGui.TimerTextLabel
                        repeat task.wait(1) until timer_label.Text == "READY"
                        ReplicatedStorage.GameEvents.PetMutationMachineService_RE:FireServer("ClaimMutatedPet")
                        task.wait(3)
                        bp = LocalPlayer.Backpack
                        for _, tool in pairs(bp:GetChildren()) do
                            if tool:GetAttribute("PET_UUID") == getgenv().selected_pet_uuid then
                                local first_word = tool.Name:match("^(%S+)")
                                if first_word ~= getgenv().selected_mutation then
                                    ReplicatedStorage.GameEvents.PetsService:FireServer("EquipPet", getgenv().selected_pet_uuid, CFrame.new(42.797, 0, -79.888))
                                    task.wait(1)
                                    continue
                                else
                                    sendWebhook(first_word)
                                    getgenv().auto_mutate_running = false
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
