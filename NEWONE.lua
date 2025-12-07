-- // RIDER WORLD SCRIPT // --
-- // VERSION: SMART COOLDOWN DETECT (LOCALPLAYER CHECK) // --

print("Script Loading...")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // 1. WINDOW // --
local Window = Fluent:CreateWindow({
    Title = "เสี่ยปาล์มขอเงินฟรี",
    SubTitle = "Smart Skill Cooldowns",
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
_G.AutoForm = false   -- Press X (Survive)

-- // VARIABLES // --
_G.IsTransforming = false 
_G.QuestingMode = false
local IsEnteringDungeon = false
local TransformStartTime = 0

-- STATE
local CurrentState = "FARMING" 
local QuestCount = 0
local MaxQuests = 5
local WarpedToMine = false
local CraftStatusSignal = "IDLE" 

-- LOGIC FLAGS
local HenshinDone = false 
local EquipDone = false
local IsRetreating = false 

local AGITO_SAFE_CRAME = CFrame.new(-3516.10425, -1.97061276, -3156.91821, -0.579402685, -7.18338145e-09, 0.815041423, -1.60398237e-08, 1, -2.58899147e-09, -0.815041423, -1.45731889e-08, -0.579402685)
local AGITO_RETREAT_SPEED = 20 
local DAGUBA_BOSSES = {"Mighty Rider Lv.90", "Daguba Lv.90", "Empowered Daguba Lv.90"}

-- CHRONOS SAFE SPOTS
local CHRONOS_SAFE_SPOTS = {
    CFrame.new(3341.01, -3.17, -1939.04),
    CFrame.new(3332.62, -2.14, -1822.81),
    CFrame.new(3460.22, -2.14, -1816.35),
    CFrame.new(3465.59, -2.14, -1956.87)
}
local ChronosSpotIndex = 1

-- ROOK & BISHOP VARS
local ROOK_BISHOP_SUMMON_CF = CFrame.new(4779.29, 8.53, 97.93)

_G.AutoSkill = false
_G.FormName = "Survive Bat"
_G.SelectedKeys = { ["E"] = false, ["R"] = false, ["C"] = false, ["V"] = false }

-- COMBO SETTINGS
_G.AutoCombo = false
_G.ComboName = "Faiz Blaster"

-- // HELPER FUNCTIONS // --

local function GetRootPart()
    local Character = LocalPlayer.Character
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart")
end

local function TweenTo(TargetCFrame, CustomSpeed)
    local RootPart = GetRootPart()
    if not RootPart then return end
    
    if _G.IsTransforming and (tick() - TransformStartTime) > 12 then
        _G.IsTransforming = false
    end

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

-- COMBAT
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

-- // NEW: SKILL COOLDOWN DETECTION // --
local function IsSkillReady(Key)
    -- If LocalPlayer[Key] exists, it means the skill is on COOLDOWN.
    -- We want to fire only if it is NOT there.
    return not LocalPlayer:FindFirstChild(Key)
end

-- // UPDATED COMBO LOGIC // --
local function RunCombo(Target)
    if not Target or not Target:FindFirstChild("Humanoid") or Target.Humanoid.Health <= 0 then return end
    
    -- Always do basic attacks (M1/M2) to keep DPS up
    DoCombat()

    if _G.ComboName == "Faiz Blaster" then
        -- Logic: V (Open) -> R -> E
        if IsSkillReady("V") then
            FireSkill("V")
        elseif IsSkillReady("R") then
            FireSkill("R")
        elseif IsSkillReady("E") then
            FireSkill("E")
        end
        
    elseif _G.ComboName == "Chronos" then
        -- Logic: C > E > V > R
        if IsSkillReady("C") then
            FireSkill("C")
        elseif IsSkillReady("E") then
            FireSkill("E")
        elseif IsSkillReady("V") then
            FireSkill("V")
        elseif IsSkillReady("R") then
            FireSkill("R")
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

-- // CHECK IF BOSS IS ALIVE // --
local function IsBossPresent()
    if LIVES_FOLDER:FindFirstChild("Golem Bugster Lv.90") or LIVES_FOLDER:FindFirstChild("Cronus Lv.90") then
        return true
    end
    return false
end

-- // AUTO FORM LOOP (X) // --
task.spawn(function()
    while task.wait(1) do
        if _G.AutoForm and not _G.IsTransforming and not _G.QuestingMode and not IsRetreating then
            
            -- BOSS CHECK
            local ShouldTransform = true
            if _G.AutoBoss then
                if not IsBossPresent() then
                    ShouldTransform = false 
                end
            end
            
            if ShouldTransform then
                FireSkill("X")
            end
        end
    end
end)

-- // CLIENT LISTENER // --
CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data)
    if _G.QuestingMode then return end
    
    if type(Data) == "table" and Data.Text then 
        local txt = string.lower(Data.Text)
        
        -- // TRANSFORM LOGIC //
        if _G.AutoForm and string.find(txt, "transform") and not IsRetreating then
            
            local AllowTransform = true
            if _G.AutoBoss and not IsBossPresent() then
                AllowTransform = false 
            end
            
            if AllowTransform and not _G.IsTransforming then
                _G.IsTransforming = true 
                TransformStartTime = tick() 
                
                FireSkill("X")

                if _G.AutoBoss then
                    Fluent:Notify({Title = "INSTANT FORM", Content = "Boss Active - Resuming!", Duration = 2})
                    task.wait(0.1) 
                    _G.IsTransforming = false 
                else
                    Fluent:Notify({Title = "AUTO FORM", Content = "Transforming... Pausing 9s", Duration = 5})
                    task.wait(9) 
                    _G.IsTransforming = false 
                end
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
    IsRetreating = false
    _G.IsTransforming = false
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

-- // UPDATED: PRESS E VIRTUAL (LONG PRESS) // --
local function Press_E_Virtual(Prompt, ExtraTime)
    local Extra = ExtraTime or 0
    if Prompt and Prompt.Enabled then
        local HoldTime = Prompt.HoldDuration + Extra
        if VirtualInputManager then 
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(HoldTime + 0.1) 
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        else
            fireproximityprompt(Prompt)
        end
        return true
    end
    return false
end

-- // SMOOTH BOSS KILLING FUNCTION // --
local function KillBossByName(BossName)
    if not _G.AutoBoss then return end
    while _G.IsTransforming and _G.AutoBoss do task.wait(0.5) end
    
    local Target = LIVES_FOLDER:FindFirstChild(BossName)
    if not Target then return end
    
    if Target then
        if Target:FindFirstChild("HumanoidRootPart") then
             TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist), 60)
        end
        
        local Sticker
        Sticker = RunService.Heartbeat:Connect(function()
            local MyRoot = GetRootPart()
            if not MyRoot then return end
            if _G.AutoBoss and Target and Target.Parent == LIVES_FOLDER and Target:FindFirstChild("HumanoidRootPart") and Target.Humanoid.Health > 0 then
                if not _G.IsTransforming and not IsRetreating then -- Do not stick if retreating
                    local EnemyCF = Target.HumanoidRootPart.CFrame
                    local BehindPosition = EnemyCF * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                    -- LERP FOR SMOOTHNESS
                    MyRoot.CFrame = MyRoot.CFrame:Lerp(CFrame.new(BehindPosition.Position, EnemyCF.Position), 0.5) 
                    MyRoot.Velocity = Vector3.zero
                end
            else
                if Sticker then Sticker:Disconnect() end
            end
        end)
        
        while _G.AutoBoss and Target.Parent == LIVES_FOLDER do
            if not Target:FindFirstChild("HumanoidRootPart") or Target.Humanoid.Health <= 0 then break end
            
            local ShouldAttack = true
            
            -- // CHRONOS LOGIC // --
            if BossName == "Cronus Lv.90" then
                -- 1. EVASION ONLY
                local Judgement = Target:FindFirstChild("JudgementCalled")
                if Judgement then
                    if not IsRetreating then
                        IsRetreating = true 
                        Fluent:Notify({Title = "EVADE!", Content = "Judgement Detected! Running...", Duration = 2})
                    end
                    
                    while Target and Target.Parent and Target:FindFirstChild("JudgementCalled") and _G.AutoBoss do
                         local SafeSpot = CHRONOS_SAFE_SPOTS[ChronosSpotIndex]
                         TweenTo(SafeSpot, 70) 
                         
                         if (GetRootPart().Position - SafeSpot.Position).Magnitude < 15 then
                             ChronosSpotIndex = ChronosSpotIndex + 1
                             if ChronosSpotIndex > 4 then ChronosSpotIndex = 1 end
                         end
                         task.wait(0.1)
                    end
                    
                    -- SMOOTH RETURN
                    while Target and Target.Parent and (GetRootPart().Position - Target.HumanoidRootPart.Position).Magnitude > 15 do
                        if not _G.AutoBoss then break end
                        TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist), 70)
                    end
                    
                    IsRetreating = false
                else
                    IsRetreating = false
                end
            end

            if _G.IsTransforming then 
                repeat task.wait(0.2) until not _G.IsTransforming 
            else
                if not IsRetreating then 
                    -- COMBO LOGIC HERE
                    if _G.AutoCombo then
                         RunCombo(Target)
                    else
                         DoCombat() 
                    end
                end
            end
            
            task.wait(0.05)
        end
        
        if Sticker then Sticker:Disconnect() end
        IsRetreating = false
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
                       
                       -- COMBO OR COMBAT
                       if _G.AutoCombo then RunCombo(Target) else DoCombat() end
                  end
                  task.wait(ATTACK_SPEED)
             end
             if Target.Humanoid.Health > 0 and _G.AutoFarm and LIVES_FOLDER:FindFirstChild(EnemyName) and not _G.IsTransforming then
                  IsRetreating = true; TweenTo(AGITO_SAFE_CRAME, AGITO_RETREAT_SPEED)
                  if not _G.AutoFarm then IsRetreating = false; return end
                  task.wait(4); IsRetreating = false
                  TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist))
             end
        else TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist)) end
        
        local Sticker
        Sticker = RunService.Heartbeat:Connect(function()
            local MyRoot = GetRootPart(); if not MyRoot then return end
            if _G.AutoFarm and Target and Target.Parent == LIVES_FOLDER and Target:FindFirstChild("HumanoidRootPart") and Target.Humanoid.Health > 0 then
                local EnemyCFrame = Target.HumanoidRootPart.CFrame
                local BehindPosition = EnemyCFrame * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                MyRoot.CFrame = CFrame.new(BehindPosition.Position, EnemyCFrame.Position)
                MyRoot.Velocity = Vector3.zero
            else if Sticker then Sticker:Disconnect() end end
        end)
        
        while _G.AutoFarm and Target.Parent == LIVES_FOLDER do
            if not Target:FindFirstChild("HumanoidRootPart") or Target.Humanoid.Health <= 0 then break end
            
            if _G.IsTransforming then 
                repeat task.wait(0.2) until not _G.IsTransforming 
            else 
                 if _G.AutoCombo then RunCombo(Target) else DoCombat() end
            end
            
            task.wait(ATTACK_SPEED)
        end
        if Sticker then Sticker:Disconnect() end
    end
end

-- [QUESTS]
local function WaitForQuestCompletion(QuestNameKeyword)
    if not _G.AutoFarm then return end
    local Timeout = 0
    while _G.AutoFarm and Timeout < 10 do
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if PlayerGui then
            local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
            for _, child in pairs(GUI:GetChildren()) do
                if string.find(child.Name, QuestNameKeyword) and child:FindFirstChild("TextLabel") and string.find(child.TextLabel.Text, "Completed") then return end
            end
        end
        Timeout = Timeout + 1; task.wait(1)
    end
end
local function GetWindQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Mummy Return?") and GUI["Mummy Return?"].Visible then
        return string.find(GUI["Mummy Return?"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end return "NONE"
end
local function Accept_Wind_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("WindTourist")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector); task.wait(1)
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
    end return "NONE"
end
local function Accept_Malcom_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("Malcom")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector); task.wait(1)
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
local function GetRookBishopQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Double or Solo") and GUI["Double or Solo"].Visible then
        return string.find(GUI["Double or Solo"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end return "NONE"
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
            Press_E_Virtual(v, 2) -- HOLD E FOR 2 SECONDS
            break
        end
    end
    task.wait(1.5)
end

local function GetMinerGoonQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Find Diamond?") and GUI["Find Diamond?"].Visible then
        return string.find(GUI["Find Diamond?"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end return "NONE"
end
local function Accept_MinerGoon_Quest()
    while _G.IsTransforming do task.wait(1) end
    local NPC = Workspace.NPC:FindFirstChild("LeeTheMiner")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector)
        task.wait(1)
        local Status = GetMinerGoonQuestStatus()
        if Status == "NONE" then
             DIALOGUE_EVENT:FireServer({Choice = "[ Quest ]"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "[ Repeatable ]"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Okay"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Exit = true})
        elseif Status == "COMPLETED" then
             DIALOGUE_EVENT:FireServer({Choice = "Yes, I've done it."}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Okay"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Exit = true})
             QuestCount = QuestCount + 1
             Fluent:Notify({Title = "Progress", Content = "Quest: " .. tostring(QuestCount) .. " / " .. tostring(MaxQuests), Duration = 3})
        end
        task.wait(1); _G.QuestingMode = false
    end
end
local function CloseCraftingGUI()
    local GUI = LocalPlayer.PlayerGui:FindFirstChild("CraftingGUI")
    if GUI then
        local ExitBtn = GUI:FindFirstChild("Exit") 
        if ExitBtn then
            if VirtualInputManager then
                 VirtualInputManager:SendMouseButtonEvent(ExitBtn.AbsolutePosition.X+10, ExitBtn.AbsolutePosition.Y+10, 0, true, game, 1)
                 task.wait(0.05)
                 VirtualInputManager:SendMouseButtonEvent(ExitBtn.AbsolutePosition.X+10, ExitBtn.AbsolutePosition.Y+10, 0, false, game, 1)
            end
            for _, c in pairs(getconnections(ExitBtn.MouseButton1Click)) do c:Fire() end
        end
        DIALOGUE_EVENT:FireServer({Exit = true})
    end
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("HumanoidRootPart") then Char.HumanoidRootPart.Anchored = false end
end
local function RunCraftingRoutine()
    WarpTo("Rider's Center"); Fluent:Notify({Title = "Crafting", Content = "Warping...", Duration = 3})
    task.wait(6)
    local NPC = Workspace.NPC:FindFirstChild("UniversalCrafting")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector); task.wait(1)
        DIALOGUE_EVENT:FireServer({Choice = "[ Craft ]"}); task.wait(1)
        CraftStatusSignal = "IDLE"
        local Con = CRAFTING_EVENT.OnClientEvent:Connect(function(Data)
            if type(Data) == "table" and Data.Callback then
                local msg = string.lower(Data.Callback)
                if string.find(msg, "limit") or string.find(msg, "max") then CraftStatusSignal = "MAX"
                elseif string.find(msg, "not enough") then CraftStatusSignal = "EMPTY" end
            end
        end)
        local Start = tick()
        local Items = {"Blue Fragment", "Red Fragment", "Blue Sappyre", "Red Emperor"}
        local Stop = false
        for _, Item in ipairs(Items) do
            if not _G.AutoFarm or Stop then break end
            local Active = true
            local Att = 0
            while _G.AutoFarm and Active do
                CraftStatusSignal = "IDLE"
                CRAFTING_EVENT:FireServer("Special", Item); task.wait(0.3); Att = Att + 1
                if CraftStatusSignal == "MAX" then Active = false
                elseif CraftStatusSignal == "EMPTY" then Active = false; Stop = true
                elseif Att > 20 then Active = false end
                if (tick() - Start) > 60 then Stop = true; break end
            end
        end
        if Con then Con:Disconnect() end
        CloseCraftingGUI(); task.wait(1)
        CurrentState = "FARMING"; QuestCount = 0; WarpedToMine = false
        Fluent:Notify({Title = "Return", Content = "Respawning to Clear UI...", Duration = 3})
        if LocalPlayer.Character then LocalPlayer.Character.Humanoid.Health = 0 end
        LocalPlayer.CharacterAdded:Wait(); task.wait(2)
        for i=1,5 do WarpTo("Mine's Field"); task.wait(0.5) end
        task.wait(1)
    end
end
local function Farm_Yui_Quest()
    if _G.IsTransforming then return end
    local NPC = Workspace.NPC:FindFirstChild("Yui")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector); task.wait(1)
        DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."}); task.wait(0.3)
        DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"}); task.wait(0.3)
        DIALOGUE_EVENT:FireServer({Choice = "Dragon's Alliance"}); task.wait(0.3)
        DIALOGUE_EVENT:FireServer({Choice = "Start 'Dragon's Alliance'"}); task.wait(0.3)
        DIALOGUE_EVENT:FireServer({Exit = true}); task.wait(0.3)
        _G.QuestingMode = false
    end
end
local function Check_Agito_Quest_Active()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Agito's Rules") and GUI["Agito's Rules"].Visible then
        return string.find(GUI["Agito's Rules"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end return "NONE"
end
local function Farm_Agito_Quest()
    if _G.IsTransforming or not _G.AutoFarm then return end
    if Check_Agito_Quest_Active() == "ACTIVE" then return end
    local NPC = Workspace.NPC:FindFirstChild("Shoichi")
    if not NPC then NPC = Workspace.NPC:WaitForChild("Shoichi", 5) end

    if NPC then
        local Part = NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChild("Torso")
        if Part then
             TweenTo(Part.CFrame * CFrame.new(0,0,3)); task.wait(0.2)
             fireclickdetector(NPC.ClickDetector); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."}); task.wait(0.3)
             DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"}); task.wait(0.3)
             DIALOGUE_EVENT:FireServer({Choice = "[ Challenge ]"}); task.wait(0.3)
             DIALOGUE_EVENT:FireServer({Choice = "[ Quest ]"}); task.wait(0.3)
             DIALOGUE_EVENT:FireServer({Exit = true}); task.wait(1)
             _G.QuestingMode = false
        end
    end
end
local function Summon_Agito()
    if _G.IsTransforming or not _G.AutoFarm then return end
    if LIVES_FOLDER:FindFirstChild("Agito Lv.90") then return end
    if Workspace:FindFirstChild("KeyItem") and Workspace.KeyItem:FindFirstChild("Spawn") then
        local Stone = Workspace.KeyItem.Spawn:FindFirstChild("AgitoStone")
        if Stone then
             TweenTo(Stone.CFrame * CFrame.new(0,0,3)); task.wait(0.2)
             local P = Stone:FindFirstChild("ProximityPrompt")
             if P then fireproximityprompt(P); task.wait(1.5) end
        end
    end
end

-- // DAGUBA: FORCE ENTRY (NO UI CHECK) // --
local function GetDagubaQuestStatus()
    local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
    if GUI:FindFirstChild("Ancient Argument") and GUI["Ancient Argument"].Visible then
        return string.find(GUI["Ancient Argument"].TextLabel.Text, "Completed") and "COMPLETED" or "ACTIVE"
    end return "NONE"
end

local function Accept_Daguba_Quest()
    local NPC = Workspace.NPC:FindFirstChild("DojoStudent")
    if NPC then
        TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
        fireclickdetector(NPC.ClickDetector); task.wait(1)
        
        -- Use Status Check to avoid spamming unnecessary dialog
        local Status = GetDagubaQuestStatus()
        
        if Status == "NONE" or Status == "COMPLETED" then
             DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Sure.."}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Ancient Argument"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Choice = "Start 'Ancient Argument'"}); task.wait(0.5)
             DIALOGUE_EVENT:FireServer({Exit = true})
        end
        task.wait(1); _G.QuestingMode = false
    end
end

local function Clear_Daguba_Room()
    -- 1. WAIT FOR SPAWN
    local StartWait = tick()
    while _G.AutoFarm and (tick() - StartWait < 5) do 
        local found = false
        for _, name in pairs(DAGUBA_BOSSES) do
            if LIVES_FOLDER:FindFirstChild(name) then found = true; break end
        end
        if found then break end
        task.wait(0.2)
    end
    
    -- 2. KILL
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

local function IsInAncientDungeon()
    if Workspace:FindFirstChild("MAP") and Workspace.MAP:FindFirstChild("Trial") and Workspace.MAP.Trial:FindFirstChild("Trial - Zone") and Workspace.MAP.Trial["Trial - Zone"]:FindFirstChild("Trial of Ancient") then return true end
    return false
end

local function Run_Daguba_Sequence()
    local Trial = Workspace.KeyItem:FindFirstChild("Trial")
    if Trial then
        local Targets = {Trial:GetChildren()[3], Trial:FindFirstChild("Part"), Trial:GetChildren()[2]}
        for _, Target in ipairs(Targets) do
             if not _G.AutoFarm then return end
             if Target then
                  local Part = Target:IsA("BasePart") and Target or Target:FindFirstChildWhichIsA("BasePart", true)
                  if Part then
                       TweenTo(Part.CFrame * CFrame.new(0,0,3))
                       local P = Target:FindFirstChildWhichIsA("ProximityPrompt", true)
                       if P then Press_E_Virtual(P, 2) end 
                       Clear_Daguba_Room()
                  end
             end
        end
    end
end
-- // END FIXED DAGUBA // --

local function RunZygaLogic()
    if IsEnteringDungeon then return end
    local Boss = LIVES_FOLDER:FindFirstChild("Zyga Lv.85")
    if not Boss then
        IsEnteringDungeon = true
        Fluent:Notify({Title = "Auto Zyga", Content = "Starting Trial...", Duration = 3})
        RIDER_TRIAL_EVENT:FireServer("Trial of Zyga")
        local T = 0
        repeat task.wait(1); T=T+1; Boss = LIVES_FOLDER:FindFirstChild("Zyga Lv.85") until Boss or T>15 or not _G.AutoFarm
        IsEnteringDungeon = false; task.wait(2)
    else
        KillEnemy("Zyga Lv.85")
        if not LIVES_FOLDER:FindFirstChild("Zyga Lv.85") and _G.AutoFarm then
            Fluent:Notify({Title = "Auto Zyga", Content = "Boss Dead! Waiting 20s...", Duration = 20})
            CancelMovement(); task.wait(20)
        end
    end
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

local ComboSection = Tabs.Main:AddSection("COMBO SKILL")
local ComboToggle = Tabs.Main:AddToggle("AutoCombo", {Title = "Enable Combo", Default = false })
ComboToggle:OnChanged(function() _G.AutoCombo = Options.AutoCombo.Value end)
local ComboSelect = Tabs.Main:AddDropdown("ComboSelect", {
    Title = "Select Combo",
    Values = {"Faiz Blaster", "Chronos"},
    Multi = false,
    Default = 1,
})
ComboSelect:OnChanged(function(Value) _G.ComboName = Value end)

FarmToggle:OnChanged(function()
    _G.AutoFarm = Options.FarmToggle.Value
    
    CurrentState = "FARMING"
    QuestCount = 0
    WarpedToMine = false 
    
    if _G.AutoFarm then
        if _G.AutoBoss then Options.AutoBoss:SetValue(false) end
        HenshinDone = false 
        EquipDone = false
        _G.IsTransforming = false

        task.spawn(function()
            while _G.AutoFarm do
                Fluent:Notify({Title = "Status", Content = "Running Quest: " .. QuestDropdown.Value, Duration = 1}) 
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
                
                -- // FIXED DAGUBA LOGIC // --
                elseif QuestDropdown.Value == "DAGUBA (Auto Dungeon)" then
                     local Status = GetDagubaQuestStatus()
                    
                    if Status == "COMPLETED" then
                        CancelMovement()
                        Fluent:Notify({Title = "Daguba", Content = "Quest Completed! Waiting 20s...", Duration = 5})
                        for i = 1, 20 do if not _G.AutoFarm then break end task.wait(1) end
                        if _G.AutoFarm then Accept_Daguba_Quest() end
                        
                    elseif IsInAncientDungeon() then
                        Run_Daguba_Sequence() -- Already inside, clear room
                        task.wait(2)
                        
                    elseif Status == "NONE" then
                        Accept_Daguba_Quest()
                        
                    elseif Status == "ACTIVE" then
                        -- QUEST IS ACTIVE BUT NOT IN DUNGEON?
                        -- 1. Try to Enter immediately
                        if not IsEnteringDungeon then
                            IsEnteringDungeon = true
                            RIDER_TRIAL_EVENT:FireServer("Trial of Ancient") -- Force enter
                            
                            -- Wait loop to check if entered
                            local T = 0
                            repeat 
                                task.wait(1)
                                T = T + 1
                            until IsInAncientDungeon() or T > 10 or not _G.AutoFarm
                            
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
Fluent:Notify({Title = "Script Loaded", Content = "DAGUBA BOSS KILL & QUEST DETECT FIX", Duration = 5})
SaveManager:LoadAutoloadConfig()
