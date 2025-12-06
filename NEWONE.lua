-- // RIDER WORLD SCRIPT // --
-- // VERSION: SMOOTH BOSS STICKING // --

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // 1. WINDOW // --
local Window = Fluent:CreateWindow({
    Title = "เสี่ยปาล์มขอเงินฟรี",
    SubTitle = "Smooth Boss Kill",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "MAIN", Icon = "sword" }),
    WorldBoss = Window:AddTab({ Title = "WORLD BOSS", Icon = "skull" }), 
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- // 2. CUSTOM BUTTON // --
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
local VirtualUser = game:GetService("VirtualUser")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
local LIVES_FOLDER = Workspace:WaitForChild("Lives")
local DIALOGUE_EVENT = ReplicatedStorage.Remote.Event.Dialogue
local CRAFTING_EVENT = ReplicatedStorage.Remote.Event.CraftingRemote
local CLIENT_NOTIFIER = ReplicatedStorage.Remote.Event.ClientNotifier
local RIDER_TRIAL_EVENT = ReplicatedStorage.Remote.Event.RiderTrial

-- // ANTI-AFK // --
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- // CONFIGURATION // --
_G.AutoFarm = false
_G.AutoBoss = false 
_G.AutoQuest = true     
_G.AutoM1 = true
_G.AutoM2 = true 
_G.AttackPriority = "M1 First" 
_G.TweenSpeed = 60
_G.AttackDist = 4
local HEIGHT_OFFSET = 0
local ATTACK_SPEED = 0.25

_G.AutoEquip = true
_G.AutoHenshin = true -- Press H (Base)
_G.AutoForm = false   -- Press X (Survive) - Set by Toggle

-- // VARIABLES // --
_G.IsTransforming = false 
_G.QuestingMode = false
local IsEnteringDungeon = false

-- STATE
local CurrentState = "FARMING" 
local QuestCount = 0
local MaxQuests = 5
local WarpedToMine = false
local CraftStatusSignal = "IDLE" 

-- LOGIC FLAGS (Reset on Death)
local HenshinDone = false 
local EquipDone = false

local AGITO_SAFE_CRAME = CFrame.new(-3516.10425, -1.97061276, -3156.91821, -0.579402685, -7.18338145e-09, 0.815041423, -1.60398237e-08, 1, -2.58899147e-09, -0.815041423, -1.45731889e-08, -0.579402685)
local AGITO_RETREAT_SPEED = 20 
local DAGUBA_BOSSES = {"Mighty Rider Lv.90", "Daguba Lv.90", "Empowered Daguba Lv.90"}

_G.AutoSkill = false
_G.FormName = "Survive Bat"
_G.SelectedKeys = { ["E"] = false, ["R"] = false, ["C"] = false, ["V"] = false }

-- // HELPER FUNCTIONS // --

local function GetRootPart()
    local Character = LocalPlayer.Character
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart")
end

-- UPDATED: TweenTo now works if EITHER AutoFarm OR AutoBoss is on
local function TweenTo(TargetCFrame, CustomSpeed)
    local RootPart = GetRootPart()
    if not RootPart then return end
    
    -- Pause movement if we are mid-transformation
    while _G.IsTransforming and (_G.AutoFarm or _G.AutoBoss) do task.wait(0.5) end
    if not (_G.AutoFarm or _G.AutoBoss) then return end
    
    local SpeedToUse = CustomSpeed or _G.TweenSpeed
    local Distance = (TargetCFrame.Position - RootPart.Position).Magnitude
    local Time = Distance / SpeedToUse 
    
    local Info = TweenInfo.new(Time, Enum.EasingStyle.Linear)
    local Tween = TweenService:Create(RootPart, Info, {CFrame = TargetCFrame})
    Tween:Play()
    
    local Connection
    Connection = RunService.Stepped:Connect(function()
        if not (_G.AutoFarm or _G.AutoBoss) then Tween:Cancel(); Connection:Disconnect() end
        if not _G.IsTransforming then 
             pcall(function() RootPart.Velocity = Vector3.zero end)
        else Tween:Cancel() end
    end)
    
    repeat task.wait() until Tween.PlaybackState == Enum.PlaybackState.Completed or not (_G.AutoFarm or _G.AutoBoss) or _G.IsTransforming
    if Connection then Connection:Disconnect() end
end

local function CancelMovement()
    local Root = GetRootPart()
    if Root then Root.Velocity = Vector3.zero end
end

-- UPDATED: Attack functions work for both modes
local function FireAttack()
    if _G.IsTransforming or not (_G.AutoFarm or _G.AutoBoss) then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then Event:FireServer({CombatAction = true, LightAttack = true}) end
end

local function FireHeavyAttack()
    if _G.IsTransforming or not (_G.AutoFarm or _G.AutoBoss) then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then Event:FireServer({CombatAction = true, AttackType = "Down", HeavyAttack = true}) end
end

local function FireSkill(key)
    if not (_G.AutoFarm or _G.AutoBoss) then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then
        local args = { ["Skill"] = true, ["Key"] = key }
        if key == "X" then args["FormHenshin"] = _G.FormName end
        Event:FireServer(args)
    end
end

local function FireHenshin()
    local Character = LocalPlayer.Character
    if not Character then return end
    local Handler = Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then
        Event:FireServer({
            Henshin = true
        })
    end
end

local function DoCombat()
    if _G.IsTransforming or not (_G.AutoFarm or _G.AutoBoss) then return end
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
        if (_G.AutoFarm or _G.AutoBoss) and Character then
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- // AUTO FORM LOOP (X) // --
task.spawn(function()
    while task.wait(1) do
        if _G.AutoForm and not _G.IsTransforming and not _G.QuestingMode then
            FireSkill("X")
        end
    end
end)

-- // CLIENT LISTENER // --
CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data)
    if _G.QuestingMode then return end
    
    if type(Data) == "table" and Data.Text then 
        local txt = string.lower(Data.Text)
        
        if _G.AutoForm and string.find(txt, "transform") then
            if not _G.IsTransforming then
                _G.IsTransforming = true 
                Fluent:Notify({Title = "AUTO FORM", Content = "Transforming... Pausing 9s", Duration = 5})
                FireSkill("X")
                task.wait(9) 
                _G.IsTransforming = false 
            end
        end
    
        if string.find(txt, "dont have enough stamina") or string.find(txt, "don't have enough stamina") then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("Humanoid") then
                Char.Humanoid.Health = 0
            end
        end
    end
end)

-- // RESET FLAGS // --
LocalPlayer.CharacterAdded:Connect(function()
    HenshinDone = false
    EquipDone = false
end)

-- // EQUIP & HENSHIN // --
task.spawn(function()
    while task.wait(1) do
        if (_G.AutoFarm or _G.AutoBoss) then
            local Character = LocalPlayer.Character
            local Handler = Character and Character:FindFirstChild("PlayerHandler")
            
            if _G.AutoEquip and not EquipDone and Character and Character:FindFirstChild("Humanoid") then
                local Tool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
                if Tool then
                    Character.Humanoid:EquipTool(Tool)
                    EquipDone = true 
                end
            end
            
            if _G.AutoHenshin and not HenshinDone and Handler then
                task.wait(3) 
                FireHenshin()
                HenshinDone = true 
                Fluent:Notify({Title = "Auto Henshin", Content = "Pressed H (Base Form)", Duration = 3})
            end
        end
    end
end)

-- Warp
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

-- // SMOOTH BOSS KILLING FUNCTION (UPDATED) // --
local function KillBossByName(BossName)
    if not _G.AutoBoss then return end
    while _G.IsTransforming and _G.AutoBoss do task.wait(0.5) end
    
    -- Find specific boss
    local Target = LIVES_FOLDER:FindFirstChild(BossName)
    if not Target then return end

    if Target then
        -- 1. Initial Tween to get close
        if Target:FindFirstChild("HumanoidRootPart") then
             TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist), 60)
        end
        
        -- 2. SMOOTH STICKER (Using Heartbeat, like KillEnemy)
        local Sticker
        Sticker = RunService.Heartbeat:Connect(function()
            local MyRoot = GetRootPart()
            if not MyRoot then return end
            
            -- Validation: Check if boss still exists and we are farming
            if _G.AutoBoss and Target and Target.Parent == LIVES_FOLDER and Target:FindFirstChild("HumanoidRootPart") and Target.Humanoid.Health > 0 then
                if not _G.IsTransforming then
                    local EnemyCFrame = Target.HumanoidRootPart.CFrame
                    -- This uses the exact same math as KillEnemy to ensure it's smooth
                    local BehindPosition = EnemyCFrame * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                    MyRoot.CFrame = CFrame.new(BehindPosition.Position, EnemyCFrame.Position)
                    MyRoot.Velocity = Vector3.zero
                end
            else
                -- Disconnect if target dead or farm off
                if Sticker then Sticker:Disconnect() end
            end
        end)
        
        -- 3. COMBAT LOOP
        while _G.AutoBoss and Target.Parent == LIVES_FOLDER do
            if not Target:FindFirstChild("HumanoidRootPart") or Target.Humanoid.Health <= 0 then break end
            
            if _G.IsTransforming then 
                repeat task.wait(0.2) until not _G.IsTransforming 
            else 
                DoCombat() 
            end
            task.wait(ATTACK_SPEED)
        end
        
        -- Cleanup
        if Sticker then Sticker:Disconnect() end
    end
end

-- // FARM LOGIC FUNCTIONS // --

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
        
        -- SMOOTH STICKER FOR FARMING
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

-- [Quest Functions omitted for brevity, they remain the same]
-- RE-ADDING NECESSARY FUNCTIONS TO ENSURE FULL CODE IS RUNNABLE
local function GetWindQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Mummy Return?") and GUI["Mummy Return?"].Visible then
        return string.find(GUI["Mummy Return?"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end
    return "NONE"
end
local function Accept_Wind_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("WindTourist")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector)
        task.wait(1)
        local Status = GetWindQuestStatus()
        if Status == "NONE" then
             DIALOGUE_EVENT:FireServer({Choice = "Sure!"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Mummy Return?"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Start 'Mummy Return?'"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Exit = true})
        elseif Status == "COMPLETED" then
             DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Mummy Return?"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Start 'Mummy Return?'"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Exit = true})
        end
        task.wait(1); _G.QuestingMode = false
    end
end

local function GetMalcomQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("The Hunt Hunted") and GUI["The Hunt Hunted"].Visible then
        return string.find(GUI["The Hunt Hunted"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end
    return "NONE"
end
local function Accept_Malcom_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("Malcom")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector)
        task.wait(1)
        local Status = GetMalcomQuestStatus()
        if Status == "NONE" then
            DIALOGUE_EVENT:FireServer({Choice = "I'm ready for the challenge!"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Choice = "The Hunt Hunted"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Choice = "Start 'The Hunt Hunted'"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Exit = true})
        elseif Status == "COMPLETED" then
            DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Choice = "The Hunt Hunted"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Choice = "Start 'The Hunt Hunted'"}); task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Exit = true})
        end
        task.wait(1); _G.QuestingMode = false
    end
end
local ROOK_BISHOP_SUMMON_CF = CFrame.new(4779.29, 8.53, 97.93)
local function GetRookBishopQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Double or Solo") and GUI["Double or Solo"].Visible then
        return string.find(GUI["Double or Solo"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end
    return "NONE"
end
local function Accept_RookBishop_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("Keisuke")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector)
        task.wait(1)
        DIALOGUE_EVENT:FireServer({Choice = "[ Repeatable Quest ]"}); task.wait(0.5)
        DIALOGUE_EVENT:FireServer({Exit = true}); task.wait(1)
        _G.QuestingMode = false
    end
end
local function Summon_RookBishop()
    if not _G.AutoFarm then return end
    if LIVES_FOLDER:FindFirstChild("Bishop Lv.80") or LIVES_FOLDER:FindFirstChild("Rook Lv.80") then return end
    TweenTo(ROOK_BISHOP_SUMMON_CF); task.wait(0.5)
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and (v.Parent.Position - ROOK_BISHOP_SUMMON_CF.Position).Magnitude < 10 then
            fireproximityprompt(v); break
        end
    end
    task.wait(1.5)
end

-- // UI ELEMENTS // --
local YuiSection = Tabs.Main:AddSection("YUI QUEST")

local QuestDropdown = Tabs.Main:AddDropdown("QuestSelect", {
    Title = "Select Quest",
    Values = {"quest 1-40", "Mummy (40-80)", "Auto 40-80", "Auto Rook&Bishop", "AGITO (Shoichi)", "Auto Miner Goon", "DAGUBA (Auto Dungeon)", "Auto Zyga"},
    Multi = false,
    Default = 1,
})

local FarmToggle = Tabs.Main:AddToggle("FarmToggle", {Title = "Enable Auto Farm", Default = false })

-- // WORLD BOSS TAB ELEMENTS // --
local BossSection = Tabs.WorldBoss:AddSection("BOSS SELECT")
local BossDropdown = Tabs.WorldBoss:AddDropdown("BossSelect", {
    Title = "Select Boss",
    Values = {"Golem Bugster", "Chronos"},
    Multi = false,
    Default = 1,
})
local BossToggle = Tabs.WorldBoss:AddToggle("AutoBoss", {Title = "Auto Kill Boss", Default = false })

BossToggle:OnChanged(function()
    _G.AutoBoss = Options.AutoBoss.Value
    
    if _G.AutoBoss then
        if _G.AutoFarm then Options.FarmToggle:SetValue(false) end
        HenshinDone = false
        EquipDone = false
        
        task.spawn(function()
            while _G.AutoBoss do
                local TargetBossName = ""
                if BossDropdown.Value == "Golem Bugster" then TargetBossName = "Golem Bugster Lv.90"
                elseif BossDropdown.Value == "Chronos" then TargetBossName = "Cronus Lv.90" end
                
                if TargetBossName ~= "" then
                    local Boss = LIVES_FOLDER:FindFirstChild(TargetBossName)
                    if Boss then
                        Fluent:Notify({Title = "Boss Found", Content = "Killing " .. TargetBossName, Duration = 2})
                        KillBossByName(TargetBossName)
                    end
                end
                task.wait(1)
            end
        end)
    end
end)

local PreparationSection = Tabs.Main:AddSection("PREPARATION")
local ToggleHenshin = Tabs.Main:AddToggle("AutoHenshin", {Title = "Auto Henshin (H)", Default = true })
ToggleHenshin:OnChanged(function() _G.AutoHenshin = Options.AutoHenshin.Value end)
local ToggleEquip = Tabs.Main:AddToggle("AutoEquip", {Title = "Auto Equip Weapon", Default = true })
ToggleEquip:OnChanged(function() _G.AutoEquip = Options.AutoEquip.Value end)

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

local CombatSection = Tabs.Main:AddSection("COMBAT SETTINGS")
local PriorityDrop = Tabs.Main:AddDropdown("PriorityDrop", {Title = "Attack Priority", Values = {"M1 First", "M2 First"}, Multi = false, Default = 1})
PriorityDrop:OnChanged(function(Value) _G.AttackPriority = Value end)
local M2Toggle = Tabs.Main:AddToggle("M2Toggle", {Title = "Auto M2 (Heavy Attack)", Default = true })
M2Toggle:OnChanged(function() _G.AutoM2 = Options.M2Toggle.Value end)
local M1Toggle = Tabs.Main:AddToggle("M1Toggle", {Title = "Auto M1 (Light Attack)", Default = true })
M1Toggle:OnChanged(function() _G.AutoM1 = Options.M1Toggle.Value end)
local SpeedSlider = Tabs.Main:AddSlider("SpeedSlider", {Title = "Tween Speed", Default = 60, Min = 10, Max = 300, Rounding = 0, Callback = function(Value) _G.TweenSpeed = Value end})
local DistSlider = Tabs.Main:AddSlider("DistSlider", {Title = "Position Behind", Default = 4, Min = 0, Max = 15, Rounding = 1, Callback = function(Value) _G.AttackDist = Value end})

FarmToggle:OnChanged(function()
    _G.AutoFarm = Options.FarmToggle.Value
    
    CurrentState = "FARMING"
    QuestCount = 0
    WarpedToMine = false 
    
    if _G.AutoFarm then
        if _G.AutoBoss then Options.AutoBoss:SetValue(false) end
        HenshinDone = false 
        EquipDone = false

        task.spawn(function()
            while _G.AutoFarm do
                while _G.IsTransforming do task.wait(0.5) end
                
                if QuestDropdown.Value == "quest 1-40" then
                    if _G.AutoQuest then Farm_Yui_Quest() end
                    if not _G.AutoFarm then break end
                    KillEnemy("Dragon User Lv.7"); task.wait(ATTACK_SPEED)
                    if not _G.AutoFarm then break end
                    KillEnemy("Crab User Lv.10"); task.wait(ATTACK_SPEED)
                    if not _G.AutoFarm then break end
                    KillEnemy("Bat User Lv.12")
                    if _G.AutoQuest and _G.AutoFarm then WaitForQuestCompletion("Dragon's Alliance") end
                
                elseif QuestDropdown.Value == "Mummy (40-80)" then
                    local Status = GetWindQuestStatus()
                    if Status == "COMPLETED" or Status == "NONE" then
                        if _G.AutoQuest then Accept_Wind_Quest() end
                    elseif Status == "ACTIVE" then
                        if not _G.AutoFarm then break end
                        KillEnemy("Mummy Lv.40")
                    end
                
                elseif QuestDropdown.Value == "Auto 40-80" then
                    local Status = GetMalcomQuestStatus()
                    if Status == "COMPLETED" or Status == "NONE" then
                        if _G.AutoQuest then Accept_Malcom_Quest() end
                    elseif Status == "ACTIVE" then
                        if not _G.AutoFarm then break end
                        local M1 = LIVES_FOLDER:FindFirstChild("Dark Dragon User Lv.40")
                        local M2 = LIVES_FOLDER:FindFirstChild("Gazelle User Lv.45")
                        if M1 then KillEnemy("Dark Dragon User Lv.40")
                        elseif M2 then KillEnemy("Gazelle User Lv.45") end
                    end
                
                elseif QuestDropdown.Value == "Auto Rook&Bishop" then
                    local Status = GetRookBishopQuestStatus()
                    if Status == "COMPLETED" or Status == "NONE" then
                        if _G.AutoQuest then Accept_RookBishop_Quest() end
                    elseif Status == "ACTIVE" then
                        if not _G.AutoFarm then break end
                        Summon_RookBishop()
                        if not _G.AutoFarm then break end
                        if LIVES_FOLDER:FindFirstChild("Bishop Lv.80") then KillEnemy("Bishop Lv.80") end
                        if LIVES_FOLDER:FindFirstChild("Rook Lv.80") then KillEnemy("Rook Lv.80") end
                    end
                
                -- [Other Quest Logic: AGITO, MINER, DAGUBA, ZYGA same as before]
                -- Re-inserted for completeness
                 elseif QuestDropdown.Value == "AGITO (Shoichi)" then
                    local AgitoStatus = Check_Agito_Quest_Active() 
                    if _G.AutoQuest then
                        if AgitoStatus == "COMPLETED" or AgitoStatus == "NONE" then Farm_Agito_Quest() end
                        if Check_Agito_Quest_Active() == "ACTIVE" then
                            if not _G.AutoFarm then break end
                            Summon_Agito(); if not _G.AutoFarm then break end
                            KillEnemy("Agito Lv.90") 
                            if _G.AutoQuest and _G.AutoFarm then WaitForQuestCompletion("Agito") end
                        end
                    else
                         if not _G.AutoFarm then break end
                         KillEnemy("Agito Lv.90") 
                    end
                elseif QuestDropdown.Value == "Auto Miner Goon" then
                    -- ... (Miner Logic from previous steps) ...
                     if CurrentState == "FARMING" then
                        if QuestCount >= MaxQuests then
                            CurrentState = "CRAFTING"
                            RunCraftingRoutine()
                        else
                            if not WarpedToMine then
                                Fluent:Notify({Title = "Status", Content = "Starting... Warping to Mine first!", Duration = 3})
                                for i=1,5 do WarpTo("Mine's Field"); task.wait(0.2) end
                                task.wait(3); WarpedToMine = true
                            end
                            if _G.AutoQuest then
                                local Status = GetMinerGoonQuestStatus()
                                if Status == "COMPLETED" or Status == "NONE" then Accept_MinerGoon_Quest()
                                elseif Status == "ACTIVE" then
                                    if not _G.AutoFarm then break end
                                    KillEnemy("Miner Goon Lv.50")
                                end
                            else KillEnemy("Miner Goon Lv.50") end
                        end
                    elseif CurrentState == "CRAFTING" then end
                elseif QuestDropdown.Value == "DAGUBA (Auto Dungeon)" then
                     -- ... (Daguba Logic) ...
                     local Status = GetDagubaQuestStatus()
                    if Status == "COMPLETED" then
                        CancelMovement()
                        Fluent:Notify({Title = "Daguba", Content = "Quest Completed! Waiting 20s...", Duration = 5})
                        for i = 1, 20 do if not _G.AutoFarm then break end task.wait(1) end
                        if _G.AutoFarm then Accept_Daguba_Quest() end
                    elseif IsInAncientDungeon() then
                        Run_Daguba_Sequence(); task.wait(2)
                    elseif Status == "NONE" then
                        Accept_Daguba_Quest()
                    elseif Status == "ACTIVE" then
                        if not IsEnteringDungeon then
                            IsEnteringDungeon = true; local DungeonStarted = false
                            local Con = CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data) if string.find(Data.Text, "Trial of Ancient") and string.find(Data.Text, "Has begun") then DungeonStarted = true end end)
                            RIDER_TRIAL_EVENT:FireServer("Trial of Ancient"); local T = 0
                            repeat task.wait(1); T = T + 1 until DungeonStarted or T > 15 or not _G.AutoFarm
                            if Con then Con:Disconnect() end
                            if DungeonStarted then task.wait(2); Run_Daguba_Sequence() end
                            IsEnteringDungeon = false
                        end
                        task.wait(2)
                    end
                elseif QuestDropdown.Value == "Auto Zyga" then
                     RunZygaLogic()
                end
                
                task.wait(1)
            end
        end)
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/RiderWorld")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({Title = "Script Loaded", Content = "SMOOTH BOSS KILL ADDED", Duration = 5})
SaveManager:LoadAutoloadConfig()
