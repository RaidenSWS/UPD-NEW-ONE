-- // RIDER WORLD SCRIPT // --
-- // FINAL VERSION: DAGUBA IDLE FIX + MINER GOON CRAFTING // --

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // 1. SAFE WINDOW CONFIGURATION // --
local Window = Fluent:CreateWindow({
    Title = "เสี่ยปาล์มขอเงินฟรี",
    SubTitle = "I LOVE REGINLIEF",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "MAIN", Icon = "sword" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- // 2. CUSTOM WINTER TOGGLE BUTTON // --
local function CreateToggleButton(window)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FluentToggleUI"
    local success, _ = pcall(function() ScreenGui.Parent = game.CoreGui end)
    if not success then ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
    
    local Button = Instance.new("ImageButton")
    Button.Name = "WinterToggle"
    Button.Size = UDim2.fromOffset(50, 50)
    Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Button.Image = "rbxassetid://6421296794"
    Button.Position = UDim2.new(0.8, 0, 0.1, 0)
    Button.ZIndex = 100
    Button.Draggable = true
    Button.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = Button

    Button.MouseButton1Click:Connect(function() window:Minimize() end)
end
CreateToggleButton(Window)

-- // SERVICES // --
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
local LIVES_FOLDER = Workspace:WaitForChild("Lives")
local DIALOGUE_EVENT = ReplicatedStorage.Remote.Event.Dialogue
local CRAFTING_EVENT = ReplicatedStorage.Remote.Event.CraftingRemote
local CLIENT_NOTIFIER = ReplicatedStorage.Remote.Event.ClientNotifier
local RIDER_TRIAL_EVENT = ReplicatedStorage.Remote.Event.RiderTrial

-- // CONFIGURATION // --
_G.AutoFarm = false
_G.AutoQuest = true     
_G.AutoM1 = true
_G.AutoM2 = true 
_G.AttackPriority = "M1 First" 
_G.TweenSpeed = 60
_G.AttackDist = 4
local HEIGHT_OFFSET = 0
local ATTACK_SPEED = 0.25

-- // VARIABLES // --
_G.IsTransforming = false 
_G.QuestingMode = false
local IsEnteringDungeon = false

-- QUEST & CRAFTING STATE
local CurrentState = "FARMING" 
local QuestCount = 0
local MaxQuests = 5
local OutOfMaterials = false
local WarpedToMine = false

local AGITO_SAFE_CRAME = CFrame.new(-3516.10425, -1.97061276, -3156.91821, -0.579402685, -7.18338145e-09, 0.815041423, -1.60398237e-08, 1, -2.58899147e-09, -0.815041423, -1.45731889e-08, -0.579402685)
local AGITO_RETREAT_SPEED = 20 
local DAGUBA_BOSSES = {"Mighty Rider Lv.90", "Daguba Lv.90", "Empowered Daguba Lv.90"}

_G.AutoSkill = false
_G.AutoForm = false
_G.SkillDelay = 0.5
_G.FormName = "Survive Bat"
_G.SelectedKeys = { ["E"] = false, ["R"] = false, ["C"] = false, ["V"] = false }

-- // HELPER FUNCTIONS // --

local function GetRootPart()
    local Character = LocalPlayer.Character
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart")
end

local function TweenTo(TargetCFrame, CustomSpeed)
    local RootPart = GetRootPart()
    if not RootPart then return end
    
    while _G.IsTransforming and _G.AutoFarm do task.wait(0.5) end
    if not _G.AutoFarm then return end
    
    local SpeedToUse = CustomSpeed or _G.TweenSpeed
    local Distance = (TargetCFrame.Position - RootPart.Position).Magnitude
    local Time = Distance / SpeedToUse 
    
    local Info = TweenInfo.new(Time, Enum.EasingStyle.Linear)
    local Tween = TweenService:Create(RootPart, Info, {CFrame = TargetCFrame})
    Tween:Play()
    
    local Connection
    Connection = RunService.Stepped:Connect(function()
        if not _G.AutoFarm then Tween:Cancel(); Connection:Disconnect() end
        if not _G.IsTransforming then 
             pcall(function() RootPart.Velocity = Vector3.zero end)
        else Tween:Cancel() end
    end)
    
    repeat task.wait() until Tween.PlaybackState == Enum.PlaybackState.Completed or not _G.AutoFarm or _G.IsTransforming
    if Connection then Connection:Disconnect() end
end

local function FireAttack()
    if _G.IsTransforming or not _G.AutoFarm then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then Event:FireServer({CombatAction = true, LightAttack = true}) end
end

local function FireHeavyAttack()
    if _G.IsTransforming or not _G.AutoFarm then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then Event:FireServer({CombatAction = true, AttackType = "Down", HeavyAttack = true}) end
end

local function FireSkill(key)
    if _G.IsTransforming or not _G.AutoFarm then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then
        local args = { ["Skill"] = true, ["Key"] = key }
        if key == "X" then args["FormHenshin"] = _G.FormName end
        Event:FireServer(args)
    end
end

local function DoCombat()
    if _G.IsTransforming or not _G.AutoFarm then return end
    if _G.AutoSkill then
        for _, key in ipairs({"E", "R", "C", "V"}) do
            if _G.SelectedKeys[key] then FireSkill(key) end
        end
    end
    if _G.AttackPriority == "M1 First" then
        if _G.AutoM1 then FireAttack() end
        if _G.AutoM2 then 
            if _G.AutoM1 then task.wait(0.15) end 
            FireHeavyAttack() 
        end
    else 
        if _G.AutoM2 then FireHeavyAttack() end
        if _G.AutoM1 then 
            if _G.AutoM2 then task.wait(0.1) end
            FireAttack() 
        end
    end
end

-- Noclip
task.spawn(function()
    while task.wait(1) do
        local Character = LocalPlayer.Character
        if _G.AutoFarm and Character then
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- Auto Form
task.spawn(function()
    while task.wait() do
        if _G.AutoForm and not _G.IsTransforming and not _G.QuestingMode then
            FireSkill("X")
            task.wait(2)
        end
    end
end)

CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data)
    if _G.QuestingMode then return end
    if _G.AutoForm and type(Data) == "table" and Data.Text == "You can now transform to Special Form!" then
        if not _G.IsTransforming then
            _G.IsTransforming = true 
            Fluent:Notify({Title = "AUTO FORM", Content = "Transforming...", Duration = 5})
            FireSkill("X")
            task.wait(8) 
            _G.IsTransforming = false 
        end
    end
end)

-- // WARP & GUI HELPERS // --

local function WarpTo(Destination)
    local Character = LocalPlayer.Character
    if Character and Character:FindFirstChild("PlayerHandler") and Character.PlayerHandler:FindFirstChild("HandlerEvent") then
        Character.PlayerHandler.HandlerEvent:FireServer({
            Warp = {
                "Plaza",
                Destination
            }
        })
    end
end

local function CloseCraftingGUI()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local CraftingGUI = PlayerGui:FindFirstChild("CraftingGUI")
        if CraftingGUI and CraftingGUI:FindFirstChild("Exit") then
            local ExitBtn = CraftingGUI.Exit
            if VirtualInputManager then
                local pos = ExitBtn.AbsolutePosition
                local size = ExitBtn.AbsoluteSize
                local center = Vector2.new(pos.X + size.X/2, pos.Y + size.Y/2)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            end
            if ExitBtn.MouseButton1Click then 
                 pcall(function() for _,c in pairs(getconnections(ExitBtn.MouseButton1Click)) do c:Fire() end end)
            end
            return true
        end
    end
    return false
end

-- // CRAFTING ROUTINE // --

local function RunCraftingRoutine()
    -- 1. WARP
    WarpTo("Rider's Center")
    Fluent:Notify({Title = "Crafting", Content = "Warping to Center...", Duration = 3})
    task.wait(6) 
    
    local NPC_Craft = Workspace:WaitForChild("NPC"):FindFirstChild("UniversalCrafting")
    if not NPC_Craft then 
        WarpTo("Rider's Center")
        task.wait(6)
        NPC_Craft = Workspace:WaitForChild("NPC"):FindFirstChild("UniversalCrafting")
    end
    if not NPC_Craft then return end 
    
    local Root = NPC_Craft:FindFirstChild("HumanoidRootPart") or NPC_Craft:FindFirstChild("Torso")
    if Root then
        -- 2. MOVE & INTERACT
        TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
        
        local Clicker = NPC_Craft:FindFirstChild("ClickDetector")
        if Clicker then fireclickdetector(Clicker); task.wait(1) end
        DIALOGUE_EVENT:FireServer({Choice = "[ Craft ]"})
        task.wait(1)
        
        -- 3. LISTEN FOR "UNABLE TO CRAFT"
        OutOfMaterials = false
        local Connection
        Connection = CRAFTING_EVENT.OnClientEvent:Connect(function(Data)
            if type(Data) == "table" and Data.Callback and string.find(Data.Callback, "Unable to craft") then
                OutOfMaterials = true
                Fluent:Notify({Title = "Crafting", Content = "Materials Empty!", Duration = 3})
            end
        end)
        
        -- 4. CRAFT LOOP
        while _G.AutoFarm and not OutOfMaterials do
            CRAFTING_EVENT:FireServer("Special", "Blue Fragment"); task.wait(0.1)
            CRAFTING_EVENT:FireServer("Special", "Red Fragment"); task.wait(0.1)
            CRAFTING_EVENT:FireServer("Special", "Blue Sappyre"); task.wait(0.1)
            CRAFTING_EVENT:FireServer("Special", "Red Emperor"); task.wait(0.1)
            task.wait(0.2)
        end
        
        if Connection then Connection:Disconnect() end
        CloseCraftingGUI()
        task.wait(1) 
        
        -- 5. RETURN TO MINE
        CurrentState = "FARMING"
        QuestCount = 0
        WarpTo("Mine's Field") 
        WarpedToMine = true 
        task.wait(5) 
    end
end

-- // QUEST LOGIC // --

local function IsInAncientDungeon()
    if Workspace:FindFirstChild("MAP") and Workspace.MAP:FindFirstChild("Trial") and Workspace.MAP.Trial:FindFirstChild("Trial - Zone") and Workspace.MAP.Trial["Trial - Zone"]:FindFirstChild("Trial of Ancient") then return true end
    return false
end

local function Press_E_Virtual(Prompt)
    if Prompt and Prompt.Enabled then
        if VirtualInputManager then 
            local HoldTime = Prompt.HoldDuration
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            if HoldTime > 0 then task.wait(HoldTime + 0.1) else task.wait(0.15) end
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        else
            fireproximityprompt(Prompt)
        end
        return true
    end
    return false
end

local function GetNearestTarget(EnemyName)
    local RootPart = GetRootPart()
    if not RootPart then return nil end
    local NearestMob = nil
    local ShortestDist = 9e9
    for _, Mob in ipairs(LIVES_FOLDER:GetChildren()) do
        if Mob.Name == EnemyName and Mob:FindFirstChild("Humanoid") and Mob.Humanoid.Health > 0 and Mob:FindFirstChild("HumanoidRootPart") then
            local Dist = (RootPart.Position - Mob.HumanoidRootPart.Position).Magnitude
            if Dist < ShortestDist then
                ShortestDist = Dist
                NearestMob = Mob
            end
        end
    end
    return NearestMob
end

local function KillEnemy(EnemyName)
    if not _G.AutoFarm then return end
    while _G.IsTransforming and _G.AutoFarm do task.wait(0.5) end
    
    local Target = GetNearestTarget(EnemyName)
    if not Target then task.wait(0.5) return end

    if Target then
        if EnemyName == "Agito Lv.90" then
            TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist), 60)
            local StartTime = tick()
            while _G.AutoFarm and Target.Parent == LIVES_FOLDER and Target.Humanoid.Health > 0 and (tick() - StartTime < 3) do
                if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming end
                local MyRoot = GetRootPart()
                if MyRoot then
                    MyRoot.CFrame = CFrame.new(Target.HumanoidRootPart.Position + Vector3.new(0, HEIGHT_OFFSET, _G.AttackDist), Target.HumanoidRootPart.Position)
                    MyRoot.Velocity = Vector3.zero
                    DoCombat()
                end
                task.wait(ATTACK_SPEED)
            end
            
            if Target.Humanoid.Health > 0 and _G.AutoFarm and LIVES_FOLDER:FindFirstChild(EnemyName) and not _G.IsTransforming then
                TweenTo(AGITO_SAFE_CRAME, AGITO_RETREAT_SPEED)
                if not _G.AutoFarm then return end
                task.wait(4)
                TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist))
            end
        else
            TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist))
        end
        
        local Sticker
        Sticker = RunService.Heartbeat:Connect(function()
            local MyRoot = GetRootPart()
            if not MyRoot then return end
            if _G.AutoFarm and Target and Target.Parent == LIVES_FOLDER and Target:FindFirstChild("HumanoidRootPart") and Target.Humanoid.Health > 0 then
                local EnemyCFrame = Target.HumanoidRootPart.CFrame
                local BehindPosition = EnemyCFrame * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                MyRoot.CFrame = CFrame.new(BehindPosition.Position, EnemyCFrame.Position)
                MyRoot.Velocity = Vector3.zero
            else
                if Sticker then Sticker:Disconnect() end
            end
        end)

        while _G.AutoFarm and Target.Parent == LIVES_FOLDER do
            if not Target:FindFirstChild("HumanoidRootPart") or Target.Humanoid.Health <= 0 then break end
            if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming else DoCombat() end
            task.wait(ATTACK_SPEED)
        end
        if Sticker then Sticker:Disconnect() end
    end
end

local function Kill_Mob_Daguba(Target)
    local RootPart = GetRootPart()
    local Hum = Target:FindFirstChild("Humanoid")
    local HRP = Target:FindFirstChild("HumanoidRootPart")
    if not Hum or not HRP or not RootPart then return end
    TweenTo(HRP.CFrame * CFrame.new(0, 2, _G.AttackDist), 60)
    local Sticker
    Sticker = RunService.Heartbeat:Connect(function()
        local MyRoot = GetRootPart()
        if not _G.AutoFarm or not Target or not Target.Parent or not HRP or Hum.Health <= 0 or not MyRoot then
            if Sticker then Sticker:Disconnect() end
            return
        end
        if not _G.IsTransforming then
            local EnemyCF = HRP.CFrame
            local Behind = EnemyCF * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
            MyRoot.CFrame = CFrame.new(Behind.Position, EnemyCF.Position)
            MyRoot.Velocity = Vector3.zero
        end
    end)
    while _G.AutoFarm and Target and Target.Parent == LIVES_FOLDER do
        if Hum.Health <= 0 then break end
        if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming else DoCombat() end
        task.wait(ATTACK_SPEED)
    end
    if Sticker then Sticker:Disconnect() end
end

local function Clear_Daguba_Room()
    while _G.AutoFarm do
        local EnemyFound = false
        for _, Name in ipairs(DAGUBA_BOSSES) do
            local Mob = LIVES_FOLDER:FindFirstChild(Name)
            if Mob and Mob:FindFirstChild("Humanoid") and Mob.Humanoid.Health > 0 then
                EnemyFound = true
                Kill_Mob_Daguba(Mob)
                break 
            end
        end
        if not EnemyFound then break end
        task.wait(0.5)
    end
end

local function Run_Daguba_Sequence()
    Fluent:Notify({Title = "Daguba", Content = "Running Dungeon Sequence...", Duration = 3})
    local KeyItem = Workspace:FindFirstChild("KeyItem")
    local TrialFolder = KeyItem and KeyItem:FindFirstChild("Trial")
    if TrialFolder then
        local Children = TrialFolder:GetChildren()
        local Targets = {{Name = "Child [3]", Object = Children[3]}, {Name = "Trial.Part", Object = TrialFolder:FindFirstChild("Part")}, {Name = "Child [2]", Object = Children[2]}}
        for i, Item in ipairs(Targets) do
            if not _G.AutoFarm then return end
            local Target = Item.Object
            if Target then
                local TargetPart = Target:IsA("BasePart") and Target or Target:FindFirstChildWhichIsA("BasePart", true)
                if TargetPart then
                    TweenTo(TargetPart.CFrame * CFrame.new(0, 0, 3))
                    local Prompt = Target:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if Prompt then Press_E_Virtual(Prompt); task.wait(1) end
                    Clear_Daguba_Room()
                end
            end
        end
    end
end

local function GetDagubaQuestStatus()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        local QuestFrame = GUI:FindFirstChild("Ancient Argument")
        if QuestFrame and QuestFrame.Visible then
            local Label = QuestFrame:FindFirstChild("TextLabel")
            if Label and string.find(Label.Text, "Completed") then return "COMPLETED" end
            return "ACTIVE" 
        end
    end
    return "NONE" 
end

local function Accept_Daguba_Quest()
    local NPC_Dojo = Workspace:WaitForChild("NPC"):FindFirstChild("DojoStudent")
    if NPC_Dojo then
        local Root = NPC_Dojo:FindFirstChild("HumanoidRootPart") or NPC_Dojo:FindFirstChild("Torso")
        if Root then
            _G.QuestingMode = true
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            for _, desc in pairs(NPC_Dojo:GetDescendants()) do
                if desc:IsA("ClickDetector") then fireclickdetector(desc) elseif desc:IsA("ProximityPrompt") then fireproximityprompt(desc) end
            end
            task.wait(0.5)
            local MaxTries = 0
            while _G.AutoFarm and GetDagubaQuestStatus() ~= "ACTIVE" and MaxTries < 3 do
                local steps = {{Choice = "Yes, I've completed it."}, {Choice = "Can I get another quest?"}, {Choice = "Sure.."}, {Choice = "Ancient Argument"}, {Choice = "Start 'Ancient Argument'"}, {Exit = true}}
                for _, step in ipairs(steps) do
                    if not _G.AutoFarm then _G.QuestingMode = false; return end
                    if step.Exit then DIALOGUE_EVENT:FireServer({Exit = true}) else DIALOGUE_EVENT:FireServer(step) end
                    task.wait(0.5)
                end
                task.wait(1) 
                MaxTries = MaxTries + 1
            end
            _G.QuestingMode = false
        end
    end
end

local function GetMinerGoonQuestStatus()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        local QuestFrame = GUI:FindFirstChild("Find Diamond?") 
        if QuestFrame and QuestFrame.Visible then
            local Label = QuestFrame:FindFirstChild("TextLabel")
            if Label and string.find(Label.Text, "Completed") then return "COMPLETED" end
            return "ACTIVE"
        end
    end
    return "NONE"
end

local function Accept_MinerGoon_Quest()
    local NPC_Lei = Workspace:WaitForChild("NPC"):FindFirstChild("LeeTheMiner")
    if NPC_Lei then
        local Root = NPC_Lei:FindFirstChild("HumanoidRootPart") or NPC_Lei:FindFirstChild("Torso")
        if Root then
            _G.QuestingMode = true
            Fluent:Notify({Title = "Miner Goon", Content = "Accepting / Turning In...", Duration = 2})
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            for _, desc in pairs(NPC_Lei:GetDescendants()) do
                if desc:IsA("ClickDetector") then fireclickdetector(desc) elseif desc:IsA("ProximityPrompt") then fireproximityprompt(desc) end
            end
            task.wait(0.5)
            local MaxTries = 0
            while _G.AutoFarm and GetMinerGoonQuestStatus() ~= "ACTIVE" and MaxTries < 3 do
                local steps = {{Choice = "[ Quest ]"}, {Choice = "[ Repeatable ]"}, {Choice = "Yes, I've done it."}, {Choice = "Okay"}, {Exit = true}}
                for _, step in ipairs(steps) do
                    if not _G.AutoFarm then _G.QuestingMode = false; return end
                    if step.Exit then DIALOGUE_EVENT:FireServer({Exit = true}) else DIALOGUE_EVENT:FireServer(step) end
                    task.wait(0.3) 
                end
                task.wait(1)
                MaxTries = MaxTries + 1
            end
            -- Count Quests
            if GetMinerGoonQuestStatus() == "ACTIVE" then
                QuestCount = QuestCount + 1
                Fluent:Notify({Title = "Progress", Content = "Quest: " .. tostring(QuestCount) .. " / " .. tostring(MaxQuests), Duration = 3})
            end
            _G.QuestingMode = false
        end
    end
end

local function Check_Agito_Quest_Active()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        local QuestFrame = GUI:FindFirstChild("Agito's Rules")
        if QuestFrame and QuestFrame.Visible then
            local Label = QuestFrame:FindFirstChild("TextLabel")
            if Label and string.find(Label.Text, "Completed") then return "COMPLETED" else return "ACTIVE" end
        end
    end
    return "NONE"
end

local function Farm_Agito_Quest()
    if _G.IsTransforming or not _G.AutoFarm then return end
    if Check_Agito_Quest_Active() == "ACTIVE" then return end

    local NPC_Agito = Workspace:WaitForChild("NPC"):FindFirstChild("Shoichi")
    if NPC_Agito then
        local AgitoPart = NPC_Agito:FindFirstChild("HumanoidRootPart") or AgitoPart:FindFirstChild("Torso")
        if AgitoPart then
            _G.QuestingMode = true
            TweenTo(AgitoPart.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end 
            
            for _, desc in pairs(NPC_Agito:GetDescendants()) do
                if desc:IsA("ClickDetector") then fireclickdetector(desc) elseif desc:IsA("ProximityPrompt") then fireproximityprompt(desc) end
            end
            task.wait(0.5)

            local MaxTries = 0
            while _G.AutoFarm and Check_Agito_Quest_Active() ~= "ACTIVE" and MaxTries < 3 do
                DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."})
                task.wait(0.3)
                DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"})
                task.wait(0.3)
                DIALOGUE_EVENT:FireServer({Choice = "[ Challenge ]"})
                task.wait(0.3)
                DIALOGUE_EVENT:FireServer({Choice = "[ Quest ]"})
                task.wait(0.3)
                DIALOGUE_EVENT:FireServer({Exit = true})
                task.wait(1)
                MaxTries = MaxTries + 1
            end
            _G.QuestingMode = false
        end
    end
end

local function Summon_Agito()
    if _G.IsTransforming or not _G.AutoFarm then return end
    if LIVES_FOLDER:FindFirstChild("Agito Lv.90") then return end
    local Stone = Workspace.KeyItem.Spawn:FindFirstChild("AgitoStone")
    if Stone then
        TweenTo(Stone.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.2)
        local Prompt = Stone:FindFirstChild("ProximityPrompt")
        if Prompt then fireproximityprompt(Prompt); task.wait(1.5) end
    end
end

local function WaitForQuestCompletion(QuestNameKeyword)
    if not _G.AutoFarm then return end
    local Timeout = 0
    while _G.AutoFarm and Timeout < 10 do
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if PlayerGui then
            local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
            for _, child in pairs(GUI:GetChildren()) do
                if string.find(child.Name, QuestNameKeyword) and child:FindFirstChild("TextLabel") and string.find(child.TextLabel.Text, "Completed") then
                    return 
                end
            end
        end
        Timeout = Timeout + 1
        task.wait(1)
    end
end

local function Farm_Yui_Quest()
    if _G.IsTransforming then return end
    local NPC_YUI = Workspace:WaitForChild("NPC"):WaitForChild("Yui")
    if NPC_YUI then
        local YuiPart = NPC_YUI:FindFirstChild("HumanoidRootPart") or NPC_YUI:FindFirstChild("Torso")
        if YuiPart then
            _G.QuestingMode = true
            TweenTo(YuiPart.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            
            local clicked = false
            for _, desc in pairs(NPC_YUI:GetDescendants()) do
                if desc:IsA("ClickDetector") then fireclickdetector(desc); clicked = true
                elseif desc:IsA("ProximityPrompt") then fireproximityprompt(desc); clicked = true end
            end
            task.wait(0.5)
            local choices = {"Yes, I've completed it.", "Can I get another quest?", "Dragon's Alliance", "Start 'Dragon's Alliance'", {Exit = true}}
            for _, choice in ipairs(choices) do
                if not _G.AutoFarm then _G.QuestingMode = false; return end
                if type(choice) == "table" and choice.Exit then DIALOGUE_EVENT:FireServer({Exit = true})
                else DIALOGUE_EVENT:FireServer({Choice = choice}) end
                task.wait(0.3)
            end
            _G.QuestingMode = false
        end
    end
end

-- // UI ELEMENTS // --

local YuiSection = Tabs.Main:AddSection("YUI QUEST")

local QuestDropdown = Tabs.Main:AddDropdown("QuestSelect", {
    Title = "Select Quest",
    Values = {"YUI (Lv. 1-35)", "AGITO (Shoichi)", "Auto Miner Goon", "DAGUBA (Auto Dungeon)"},
    Multi = false,
    Default = 1,
})

local FarmToggle = Tabs.Main:AddToggle("FarmToggle", {Title = "Enable Auto Farm", Default = false })

FarmToggle:OnChanged(function()
    _G.AutoFarm = Options.FarmToggle.Value
    
    CurrentState = "FARMING"
    QuestCount = 0
    WarpedToMine = false
    
    if _G.AutoFarm then
        task.spawn(function()
            while _G.AutoFarm do
                if not _G.IsTransforming then
                    
                    if QuestDropdown.Value == "YUI (Lv. 1-35)" then
                        if _G.AutoQuest then Farm_Yui_Quest() end
                        if not _G.AutoFarm then break end
                        KillEnemy("Dragon User Lv.7"); task.wait(WAIT_BETWEEN_KILLS)
                        if not _G.AutoFarm then break end
                        KillEnemy("Crab User Lv.10"); task.wait(WAIT_BETWEEN_KILLS)
                        if not _G.AutoFarm then break end
                        KillEnemy("Bat User Lv.12")
                        if _G.AutoQuest and _G.AutoFarm then WaitForQuestCompletion("Dragon's Alliance") end
                    
                    elseif QuestDropdown.Value == "AGITO (Shoichi)" then
                        local AgitoStatus = Check_Agito_Quest_Active() 
                        if _G.AutoQuest then
                            if AgitoStatus == "COMPLETED" or AgitoStatus == "NONE" then
                                Farm_Agito_Quest()
                            end
                            if Check_Agito_Quest_Active() == "ACTIVE" then
                                if not _G.AutoFarm then break end
                                Summon_Agito()
                                if not _G.AutoFarm then break end
                                KillEnemy("Agito Lv.90") 
                                if _G.AutoQuest and _G.AutoFarm then WaitForQuestCompletion("Agito") end
                            end
                        else
                             if not _G.AutoFarm then break end
                             KillEnemy("Agito Lv.90") 
                        end
                        
                    elseif QuestDropdown.Value == "Auto Miner Goon" then
                        
                        if CurrentState == "FARMING" then
                            if QuestCount >= MaxQuests then
                                CurrentState = "CRAFTING"
                                RunCraftingRoutine() -- Go Craft
                            else
                                if not WarpedToMine then
                                    WarpTo("Mine's Field")
                                    WarpedToMine = true
                                    Fluent:Notify({Title = "Status", Content = "Farming... Quest " .. tostring(QuestCount + 1) .. "/5", Duration = 3})
                                    task.wait(4) 
                                end

                                if _G.AutoQuest then
                                    local Status = GetMinerGoonQuestStatus()
                                    if Status == "COMPLETED" or Status == "NONE" then Accept_MinerGoon_Quest()
                                    elseif Status == "ACTIVE" then
                                        if not _G.AutoFarm then break end
                                        KillEnemy("Miner Goon Lv.50")
                                    end
                                else
                                    KillEnemy("Miner Goon Lv.50")
                                end
                            end
                        elseif CurrentState == "CRAFTING" then
                            -- Already handled by transition above
                        end
                    
                    elseif QuestDropdown.Value == "DAGUBA (Auto Dungeon)" then
                        local Status = GetDagubaQuestStatus()
                        
                        if Status == "COMPLETED" then
                            -- IDLE FIX: Stop moving and wait
                            Fluent:Notify({Title = "Daguba", Content = "Quest Completed! Waiting 20s...", Duration = 5})
                            local Root = GetRootPart()
                            if Root then Root.Velocity = Vector3.zero end
                            
                            for i = 1, 20 do 
                                if not _G.AutoFarm then break end 
                                task.wait(1) 
                            end
                            
                            if _G.AutoFarm then Accept_Daguba_Quest() end
                            
                        elseif Status == "NONE" then
                            Accept_Daguba_Quest()
                        elseif Status == "ACTIVE" then
                            if IsInAncientDungeon() then
                                Run_Daguba_Sequence()
                                task.wait(2)
                            elseif not IsEnteringDungeon then
                                IsEnteringDungeon = true
                                local DungeonStarted = false
                                local Con
                                Con = CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data)
                                    if string.find(Data.Text, "Trial of Ancient") and string.find(Data.Text, "Has begun") then DungeonStarted = true end
                                end)
                                RIDER_TRIAL_EVENT:FireServer("Trial of Ancient")
                                local T = 0
                                repeat task.wait(1); T = T + 1 until DungeonStarted or T > 15 or not _G.AutoFarm
                                if Con then Con:Disconnect() end
                                if DungeonStarted then
                                    task.wait(2)
                                    Run_Daguba_Sequence()
                                end
                                IsEnteringDungeon = false
                            end
                            task.wait(2)
                        end
                    end
                    
                end
                task.wait(1)
            end
        end)
    end
end)

-- SETTINGS
local FarmSettings = Tabs.Main:AddSection("Farm Settings")
local QuestToggle = Tabs.Main:AddToggle("QuestToggle", {Title = "Auto Accept Quest", Default = true })
QuestToggle:OnChanged(function() _G.AutoQuest = Options.QuestToggle.Value end)
local PriorityDrop = Tabs.Main:AddDropdown("PriorityDrop", {Title = "Attack Priority", Values = {"M1 First", "M2 First"}, Multi = false, Default = 1})
PriorityDrop:OnChanged(function(Value) _G.AttackPriority = Value end)
local M2Toggle = Tabs.Main:AddToggle("M2Toggle", {Title = "Auto M2 (Heavy Attack)", Default = true })
M2Toggle:OnChanged(function() _G.AutoM2 = Options.M2Toggle.Value end)
local M1Toggle = Tabs.Main:AddToggle("M1Toggle", {Title = "Auto M1 (Light Attack)", Default = true })
M1Toggle:OnChanged(function() _G.AutoM1 = Options.M1Toggle.Value end)
local SpeedSlider = Tabs.Main:AddSlider("SpeedSlider", {Title = "Tween Speed", Default = 60, Min = 10, Max = 300, Rounding = 0, Callback = function(Value) _G.TweenSpeed = Value end})
local DistSlider = Tabs.Main:AddSlider("DistSlider", {Title = "Position Behind", Default = 4, Min = 0, Max = 15, Rounding = 1, Callback = function(Value) _G.AttackDist = Value end})

local FormSection = Tabs.Main:AddSection("AUTO FORM")
local FormToggle = Tabs.Main:AddToggle("FormToggle", {Title = "Enable AUTO FORM (X)", Default = false })
FormToggle:OnChanged(function() _G.AutoForm = Options.FormToggle.Value end)
local FormSelect = Tabs.Main:AddDropdown("FormSelect", {Title = "Select Form", Values = {"Survive Bat", "Survival Dragon"}, Multi = false, Default = 1})
FormSelect:OnChanged(function(Value) _G.FormName = Value end)

local SkillSection = Tabs.Main:AddSection("AUTO SKILL")
local SkillToggle = Tabs.Main:AddToggle("SkillToggle", {Title = "Enable Auto Skill", Default = false })
SkillToggle:OnChanged(function() _G.AutoSkill = Options.SkillToggle.Value end)
local SkillDelay = Tabs.Main:AddSlider("SkillDelay", {Title = "Skill Delay", Default = 0.5, Min = 0.1, Max = 2, Rounding = 1, Callback = function(Value) _G.SkillDelay = Value end})
local ToggleE = Tabs.Main:AddToggle("KeyE", {Title = "Use Skill E", Default = false })
ToggleE:OnChanged(function() _G.SelectedKeys["E"] = Options.KeyE.Value end)
local ToggleR = Tabs.Main:AddToggle("KeyR", {Title = "Use Skill R", Default = false })
ToggleR:OnChanged(function() _G.SelectedKeys["R"] = Options.KeyR.Value end)
local ToggleC = Tabs.Main:AddToggle("KeyC", {Title = "Use Skill C", Default = false })
ToggleC:OnChanged(function() _G.SelectedKeys["C"] = Options.KeyC.Value end)
local ToggleV = Tabs.Main:AddToggle("KeyV", {Title = "Use Skill V", Default = false })
ToggleV:OnChanged(function() _G.SelectedKeys["V"] = Options.KeyV.Value end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/RiderWorld")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({Title = "Script Loaded", Content = "QUEST: I LOVE REGINLIEF", Duration = 5})
SaveManager:LoadAutoloadConfig()
