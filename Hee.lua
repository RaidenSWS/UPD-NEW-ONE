-- // RIDER WORLD SCRIPT // --
-- // VERSION: HALOOWEEN CHEST // --

print("Script Loading...")

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // 1. WINDOW // --
local Window = Fluent:CreateWindow({
    Title = "เสี่ยปาล์มขอเงินฟรี",
    SubTitle = "Exchange Miner",
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
local ExchangeCount = 0  -- ✅ ADD THIS
local MaxExchanges = 3   -- ✅ ADD THIS

-- LOGIC FLAGS
local HenshinDone = false 
local EquipDone = false
local IsRetreating = false 

local AGITO_SAFE_CRAME = CFrame.new(-3516.10425, -1.97061276, -3156.91821, -0.579402685, -7.18338145e-09, 0.815041423, -1.60398237e-08, 1, -2.58899147e-09, -0.815041423, -1.45731889e-08, -0.579402685)
local AGITO_RETREAT_SPEED = 20 
local DAGUBA_BOSSES = {"Empowered Daguba Lv.90", "Daguba Lv.90", "Mighty Rider Lv.90"}

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

-- // ⭐ NEW: SMART RANDOM SPOT SELECTION // --
local function GetSmartRandomSpot(currentPosition)
    local spotWeights = {}
    local totalWeight = 0
    
    -- Calculate distance-based weights (farther = higher priority)
    for i, spot in ipairs(CHRONOS_SAFE_SPOTS) do
        local distance = (currentPosition - spot.Position).Magnitude
        spotWeights[i] = distance
        totalWeight = totalWeight + distance
    end
    
    -- Weighted random selection
    local random = math.random() * totalWeight
    local cumulativeWeight = 0
    
    for i, weight in ipairs(spotWeights) do
        cumulativeWeight = cumulativeWeight + weight
        if random <= cumulativeWeight then
            return i
        end
    end
    
    -- Fallback
    return math.random(1, #CHRONOS_SAFE_SPOTS)
end
-- COMBO SETTINGS
_G.AutoCombo = false
_G.ComboName = "Faiz Blaster"

-- // HELPER FUNCTIONS // --

local function GetRootPart()
    local Character = LocalPlayer.Character
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart")
end

-- ✅ ADD THIS NEW FUNCTION HERE:
local function ForceResetCharacter()
    Fluent:Notify({Title = "Reset", Content = "Resetting character...", Duration = 3})
    
    -- Store old character for comparison
    local OldCharacter = LocalPlayer.Character
    
    -- Method 1: Kill character
    pcall(function()
        if OldCharacter and OldCharacter:FindFirstChild("Humanoid") then
            OldCharacter.Humanoid.Health = 0
        end
    end)
    
    task.wait(0.5)
    
    -- Method 2: LoadCharacter (backup)
    pcall(function()
        LocalPlayer:LoadCharacter()
    end)
    
    -- Wait for NEW character to spawn
    local StartTime = tick()
    local MaxWaitTime = 15
    local NewCharacterSpawned = false
    
    while (tick() - StartTime) < MaxWaitTime do
        task.wait(0.5)
        
        -- GET FRESH CHARACTER REFERENCE!
        local CurrentChar = LocalPlayer.Character
        
        -- Check if it's a NEW character (different from old one)
        if CurrentChar and CurrentChar ~= OldCharacter then
            local Humanoid = CurrentChar:FindFirstChild("Humanoid")
            local RootPart = CurrentChar:FindFirstChild("HumanoidRootPart")
            
            if Humanoid and RootPart and Humanoid.Health > 0 then
                NewCharacterSpawned = true
                print("✅ New character spawned successfully!")
                break
            end
        end
    end
    
    if NewCharacterSpawned then
        Fluent:Notify({Title = "Success", Content = "Character respawned!", Duration = 2})
        task.wait(2) -- Extra time for character to stabilize
        return true
    else
        warn("⚠️ Character reset timeout after " .. MaxWaitTime .. "s")
        Fluent:Notify({Title = "Warning", Content = "Reset may have failed", Duration = 5})
        return false
    end
end

local function TweenTo(TargetCFrame, CustomSpeed)
    local RootPart = GetRootPart()
    if not RootPart then return end
    
    if _G.IsTransforming and (tick() - TransformStartTime) > 12 then
        _G.IsTransforming = false
    end
    -- ... rest of function ...

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

-- // COMBO HELPER FUNCTIONS // --
local function CheckFaizMode()
    local isMode = false
    -- 1. Check UI Text (Mode Active?)
    pcall(function()
        local cdText = LocalPlayer.PlayerGui.Main.PreviewCore.CD_TEXT
        if cdText and cdText.Visible and cdText.Text ~= "" then
            isMode = true
        end
    end)
    -- 2. Safety Stamina Check
    if isMode then
        local Stats = LocalPlayer:FindFirstChild("RiderStats")
        if Stats and Stats:FindFirstChild("Stamina") and Stats.Stamina.Value <= 0 then
            isMode = false 
        end
    end
    return isMode
end

local function GetStamina()
    local stats = LocalPlayer:FindFirstChild("RiderStats")
    if stats and stats:FindFirstChild("Stamina") then
        return stats.Stamina.Value
    end
    return 0
end

local function CheckCombatText()
    local success, visible = pcall(function()
        return LocalPlayer.PlayerGui.Main.CombatText.Visible
    end)
    return success and visible
end

-- // UPDATED COMBO LOGIC // --
local function RunCombo(Target)
    if not Target or not Target:FindFirstChild("Humanoid") or Target.Humanoid.Health <= 0 then return end
    
    if _G.ComboName == "Faiz Blaster" then
        if CheckFaizMode() then
            -- NEW CHECK: If CombatText is visible, JUST M1
            if CheckCombatText() then
                 -- Visible == True that mean Spam M1
                 FireAttack()
                 task.wait() -- FAST SPAM
            else
                 -- Visible == False -> Use Skills (V Priority)
                 
                 -- 1. USE SKILL V FIRST (Priority)
                FireSkill("V")
                task.wait(0.15)
                
                -- 2. CHECK STAMINA FOR R AND E
                local stamina = GetStamina()
                
                if stamina > 500 then
                    FireSkill("R"); task.wait(0.15)
                    if stamina > 1300 then
                        FireSkill("E"); task.wait(0.15)
                    end
                end
                
                -- 3. FASTER M1 BURST
                for i=1, 8 do 
                    FireAttack()
                    task.wait() -- Minimal wait for max spam
                end
            end
        else
            -- Not in Blaster Mode? Use standard settings
            DoCombat()
        end
        
    elseif _G.ComboName == "Chronos" then
        FireSkill("C"); task.wait(0.2)
        if not Target.Parent then return end
        FireSkill("E"); task.wait(0.2)
        if not Target.Parent then return end
        FireSkill("V"); task.wait(0.2)
        if not Target.Parent then return end
        FireSkill("R"); task.wait(0.2)
        
        for i=1, 5 do FireAttack(); task.wait(0.1) end
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
        
        if _G.AutoForm and string.find(txt, "transform") and not IsRetreating then
            local AllowTransform = true
            if _G.AutoBoss and not IsBossPresent() then AllowTransform = false end
            
            if AllowTransform and not _G.IsTransforming then
                _G.IsTransforming = true 
                TransformStartTime = tick() 
                FireSkill("X")

                if _G.AutoBoss then
                    Fluent:Notify({Title = "INSTANT FORM", Content = "Boss Active - Resuming!", Duration = 2})
                    task.wait(0.1); _G.IsTransforming = false 
                else
                    Fluent:Notify({Title = "AUTO FORM", Content = "Transforming... Pausing 9s", Duration = 5})
                    task.wait(9); _G.IsTransforming = false 
                end
            end
        end
    
        if string.find(txt, "dont have enough stamina") or string.find(txt, "don't have enough stamina") then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("Humanoid") then Char.Humanoid.Health = 0 end
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
                if Tool then Character.Humanoid:EquipTool(Tool); EquipDone = true end
            end
            
            if _G.AutoHenshin and not HenshinDone and Handler then
                task.wait(3); FireHenshin(); HenshinDone = true 
                Fluent:Notify({Title = "Auto Henshin", Content = "Pressed H (Base Form)", Duration = 3})
            end
        end
    end
end)

-- Warp
local function WarpTo(Destination)
    local Character = LocalPlayer.Character
    if Character and Character:FindFirstChild("PlayerHandler") and Character.PlayerHandler:FindFirstChild("HandlerEvent") then
        Character.PlayerHandler.HandlerEvent:FireServer({ Warp = { "Plaza", Destination } })
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
            if Dist < ShortestDist then ShortestDist = Dist; NearestMob = Mob end
        end
    end
    return NearestMob
end

-- // PRESS E // --
local function Press_E_Virtual(Prompt, ExtraTime)
    local Extra = ExtraTime or 0
    if Prompt and Prompt.Enabled then
        local HoldTime = Prompt.HoldDuration + Extra
        if VirtualInputManager then 
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(HoldTime + 0.1) 
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        else fireproximityprompt(Prompt) end
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
                if not _G.IsTransforming and not IsRetreating then 
                    local EnemyCF = Target.HumanoidRootPart.CFrame
                    local BehindPosition = EnemyCF * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                    MyRoot.CFrame = MyRoot.CFrame:Lerp(CFrame.new(BehindPosition.Position, EnemyCF.Position), 0.5) 
                    MyRoot.Velocity = Vector3.zero
                end
            else if Sticker then Sticker:Disconnect() end end
        end)
        
        while _G.AutoBoss and Target.Parent == LIVES_FOLDER do
            if not Target:FindFirstChild("HumanoidRootPart") or Target.Humanoid.Health <= 0 then break end
            
            local ShouldAttack = true
            
            -- ⭐ IMPROVED CHRONOS EVASION WITH RANDOMIZATION ⭐
if BossName == "Cronus Lv.90" then
    local Judgement = Target:FindFirstChild("JudgementCalled")
    if Judgement then
        if not IsRetreating then
            IsRetreating = true
            Fluent:Notify({
                Title = "EVADE!", 
                Content = "Judgement! Smart Random Evasion!", 
                Duration = 2
            })
        end
        
        while Target and Target.Parent and Target:FindFirstChild("JudgementCalled") and _G.AutoBoss do
            local SafeSpot = CHRONOS_SAFE_SPOTS[ChronosSpotIndex]
            local MyRoot = GetRootPart()
            
            if not MyRoot then break end
            
            TweenTo(SafeSpot, 70)
            
            -- When reaching spot, pick smart random next location
            if (MyRoot.Position - SafeSpot.Position).Magnitude < 15 then
                -- Get weighted random spot (prefers distant locations)
                ChronosSpotIndex = GetSmartRandomSpot(MyRoot.Position)
                
                -- Random human-like delay
                task.wait(math.random(15, 35) / 100) -- 0.15 to 0.35 seconds
            end
            
            task.wait(0.1)
        end
        
        -- Return to boss after judgement ends
        while Target and Target.Parent and (GetRootPart().Position - Target.HumanoidRootPart.Position).Magnitude > 15 do
            if not _G.AutoBoss then break end
            TweenTo(Target.HumanoidRootPart.CFrame * CFrame.new(0, 2, _G.AttackDist), 70)
            task.wait(0.1)
        end
        
        IsRetreating = false
    else 
        IsRetreating = false 
    end
end

            if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming 
            else if not IsRetreating then 
                 if _G.AutoCombo then RunCombo(Target) else DoCombat() end
            end end
            task.wait(0.05)
        end
        if Sticker then Sticker:Disconnect() end; IsRetreating = false
    end
end

-- // FARM LOGIC // --
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
            if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming else 
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
            Press_E_Virtual(v, 2); break
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
    local GUI = LocalPlayer. PlayerGui:FindFirstChild("CraftingGUI")
    if GUI then
        local ExitBtn = GUI:FindFirstChild("Exit") 
        if ExitBtn then
            if VirtualInputManager then
                pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(ExitBtn.AbsolutePosition.X+10, ExitBtn.AbsolutePosition.Y+10, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(ExitBtn.AbsolutePosition.X+10, ExitBtn.AbsolutePosition.Y+10, 0, false, game, 1)
                end)
            end
            
            -- ✅ FIX: Wrap in pcall to avoid nil errors
            pcall(function()
                for _, c in pairs(getconnections(ExitBtn.MouseButton1Click)) do 
                    c:Fire() 
                end 
            end)
        end
        
        -- ✅ FIX: Safely close dialogue
        pcall(function()
            DIALOGUE_EVENT:FireServer({Exit = true})
        end)
    end
    
    -- ✅ FIX: Safely unanchor character
    local Char = LocalPlayer.Character
    if Char and Char:FindFirstChild("HumanoidRootPart") then 
        pcall(function()
            Char.HumanoidRootPart.Anchored = false
        end)
    end
end
-- ✅ NEW: Exchange Ore Function
local function ExchangeOreWithLei()
    Fluent:Notify({Title = "Exchange", Content = "Going to Lei for exchange...", Duration = 3})
    
    -- Find Lei NPC
    local NPC = Workspace.NPC:FindFirstChild("LeeTheMiner")
    if not NPC then
        warn("⚠️ LeeTheMiner NPC not found!")
        Fluent:Notify({Title = "Error", Content = "Lei NPC not found", Duration = 5})
        return false
    end
    
    -- Tween to NPC
    local NPCRoot = NPC:FindFirstChild("HumanoidRootPart")
    if NPCRoot then
        TweenTo(NPCRoot.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
    end
    
    -- Click NPC
    pcall(function()
        fireclickdetector(NPC.ClickDetector)
    end)
    task.wait(1)
    
    -- Send Exchange dialogue
    local success1 = pcall(function()
        DIALOGUE_EVENT:FireServer({Choice = "[ Exchange ]"})
    end)
    
    if not success1 then
        warn("⚠️ Failed to select Exchange option")
        return false
    end
    
    task.wait(0.5)
    
    -- Confirm exchange
    local success2 = pcall(function()
        DIALOGUE_EVENT:FireServer({Choice = "[ Confirm ]"})
    end)
    
    if not success2 then
        warn("⚠️ Failed to confirm exchange")
        return false
    end
    
    task.wait(0.5)
    
    -- Close dialogue
    pcall(function()
        DIALOGUE_EVENT:FireServer({Exit = true})
    end)
    
    task.wait(1)
    
    Fluent:Notify({Title = "Exchange", Content = "Exchange completed!", Duration = 2})
    print("✅ Exchange successful - Got Blue & Red Fragments")
    
    return true
end

-- ✅ NEW: Run Exchange Loop (3 times)
local function RunExchangeLoop()
    Fluent:Notify({Title = "Exchange Loop", Content = "Starting 3x exchange cycle...", Duration = 3})
    
    local ExchangeCount = 0
    local MaxExchanges = 3
    
    for i = 1, MaxExchanges do
        if not _G.AutoFarm then break end
        
        Fluent:Notify({Title = "Exchange", Content = "Exchange " .. i .. "/3", Duration = 2})
        
        -- Reset quest count for this cycle
        QuestCount = 0
        
        -- Do 5 quests
        while QuestCount < 5 and _G.AutoFarm do
            local Status = GetMinerGoonQuestStatus()
            
            if Status == "COMPLETED" or Status == "NONE" then
                Accept_MinerGoon_Quest()
            elseif Status == "ACTIVE" then
                if not _G.AutoFarm then break end
                KillEnemy("Miner Goon Lv.50")
            end
            
            task.wait(1)
        end
        
        -- After 5 quests, do exchange
        if QuestCount >= 5 then
            local ExchangeSuccess = ExchangeOreWithLei()
            
            if ExchangeSuccess then
                ExchangeCount = ExchangeCount + 1
                Fluent:Notify({Title = "Progress", Content = "Exchanges: " .. ExchangeCount .. "/3", Duration = 3})
            else
                warn("⚠️ Exchange failed, retrying...")
                task.wait(3)
                ExchangeOreWithLei() -- Retry once
            end
        end
        
        task.wait(2)
    end
    
    Fluent:Notify({Title = "Exchange Loop", Content = "All 3 exchanges complete!", Duration = 3})
    print("✅ Completed " .. ExchangeCount .. " exchanges")
    
    return ExchangeCount >= 3
end
local function RunCraftingRoutine()
    WarpTo("Rider's Center")
    Fluent:Notify({Title = "Crafting", Content = "Warping...", Duration = 3})
    task.wait(6)
    
    local NPC = Workspace.NPC:FindFirstChild("UniversalCrafting")
    if not NPC then
        warn("⚠️ UniversalCrafting NPC not found!")
        Fluent:Notify({Title = "Error", Content = "NPC not found", Duration = 5})
        return
    end
    
    local NPCRoot = NPC:FindFirstChild("HumanoidRootPart")
    if not NPCRoot then
        warn("⚠️ NPC HumanoidRootPart not found!")
        return
    end
    
    TweenTo(NPCRoot.CFrame * CFrame.new(0, 0, 3))
    task.wait(0.5)
    
    pcall(function()
        fireclickdetector(NPC.ClickDetector)
    end)
    task.wait(1)
    
    pcall(function()
        DIALOGUE_EVENT:FireServer({Choice = "[ Craft ]"})
    end)
    task.wait(1)
    
    CraftStatusSignal = "IDLE"
    local Con = CRAFTING_EVENT.OnClientEvent:Connect(function(Data)
        if type(Data) == "table" and Data.Callback then
            local msg = string.lower(Data.Callback)
            if string.find(msg, "limit") or string.find(msg, "max") then 
                CraftStatusSignal = "MAX"
            elseif string.find(msg, "not enough") then 
                CraftStatusSignal = "EMPTY"
            end
        end
    end)
    
    local Start = tick()
    -- ✅ CHANGED: Only craft Blue Sappyre and Red Emperor
    local Items = {"Blue Sappyre", "Red Emperor"}
    local Stop = false
    
    Fluent:Notify({Title = "Crafting", Content = "Crafting Blue Sappyre & Red Emperor only", Duration = 3})
    
    for _, Item in ipairs(Items) do
        if not _G.AutoFarm or Stop then break end
        local Active = true
        local Att = 0
        
        Fluent:Notify({Title = "Crafting", Content = "Now crafting: " .. Item, Duration = 2})
        
        while _G.AutoFarm and Active do
            CraftStatusSignal = "IDLE"
            
            pcall(function()
                CRAFTING_EVENT:FireServer("Special", Item)
            end)
            
            task.wait(0.3)
            Att = Att + 1
            
            if CraftStatusSignal == "MAX" then 
                Fluent:Notify({Title = "Crafting", Content = Item .. " maxed out!", Duration = 2})
                Active = false
            elseif CraftStatusSignal == "EMPTY" then 
                Fluent:Notify({Title = "Crafting", Content = "Not enough materials!", Duration = 2})
                Active = false
                Stop = true
            elseif Att > 20 then 
                Active = false
            end
            
            if (tick() - Start) > 60 then 
                Stop = true
                break 
            end
        end
    end
    
    if Con then Con:Disconnect() end
    
    CloseCraftingGUI()
    task.wait(1)
    
 -- Reset state (at the very end of RunCraftingRoutine)
    CurrentState = "FARMING"
    QuestCount = 0
    WarpedToMine = false
    ExchangeCount = 0  -- ✅ ADD THIS LINE if missing
    
    Fluent:Notify({Title = "Return", Content = "Resetting character...", Duration = 3})
    
    local ResetSuccess = ForceResetCharacter()
    
    -- ... rest of the function
    if ResetSuccess then
        task.wait(2)
        
        local Character = LocalPlayer.Character
        if Character and Character:FindFirstChild("Humanoid") and Character:FindFirstChild("HumanoidRootPart") then
            print("✅ Character verified ready for warp")
        else
            warn("⚠️ Character may not be fully ready, waiting extra time...")
            task.wait(2)
        end
    else
        warn("⚠️ Reset function reported failure, waiting 5s...")
        task.wait(5)
    end
    
    Fluent:Notify({Title = "Return", Content = "Returning to Mine's Field...", Duration = 3})
    
    for i = 1, 5 do 
        pcall(function()
            WarpTo("Mine's Field")
        end)
        task.wait(1)
    end
    
    task.wait(1)
    Fluent:Notify({Title = "Ready", Content = "Crafting complete! Resuming...", Duration = 3})
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

-- // SOUL FRAG HELPERS // --
local function GetSoulFragStatus()
    local success, result = pcall(function()
        local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
        -- Note: User specified ["No CAP!"] as the quest frame name
        local QuestFrame = GUI:FindFirstChild("No CAP!") 
        
        if QuestFrame and QuestFrame:FindFirstChild("TextLabel") and QuestFrame.Visible then
            if string.find(QuestFrame.TextLabel.Text, "Completed") then 
                return "COMPLETED" 
            else 
                return "ACTIVE" 
            end
        end
        return "NONE"
    end)
    return success and result or "NONE"
end

local function Accept_Ryuga_Quest()
    local NPC = Workspace.NPC:FindFirstChild("Ryuga")
    if NPC then
        local Root = NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChild("Torso")
        if Root then
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.5)
            
            -- Click
            pcall(function() fireclickdetector(NPC.ClickDetector) end)
            task.wait(1)
            
            -- Select Quest
            pcall(function() 
                DIALOGUE_EVENT:FireServer({Choice = "[ Repeatable Quest ]"}) 
            end)
            task.wait(0.5)
            
            -- Exit
            pcall(function() DIALOGUE_EVENT:FireServer({Exit = true}) end)
            task.wait(1)
            _G.QuestingMode = false
        end
    else
        warn("⚠️ Ryuga NPC not found!")
    end
end

-- // MAIN SOUL FRAG FARM FUNCTION // --
local function Farm_Soul_Frag_Quest()
    local Status = GetSoulFragStatus()
    
    if Status == "NONE" or Status == "COMPLETED" then
        if _G.AutoQuest then
            Accept_Ryuga_Quest()
        end
        
    elseif Status == "ACTIVE" then
        if not _G.AutoFarm then return end
        
        -- Priority 1: Mad Isurugi
        local Mob1 = LIVES_FOLDER:FindFirstChild("Mad Isurugi Lv.80")
        
        -- Priority 2: Utsumi
        local Mob2 = LIVES_FOLDER:FindFirstChild("Utsumi Lv.80")
        
        if Mob1 and Mob1:FindFirstChild("Humanoid") and Mob1.Humanoid.Health > 0 then
            Fluent:Notify({Title = "Soul Frag", Content = "Killing Mad Isurugi...", Duration = 2})
            KillEnemy("Mad Isurugi Lv.80")
            
        elseif Mob2 and Mob2:FindFirstChild("Humanoid") and Mob2.Humanoid.Health > 0 then
            Fluent:Notify({Title = "Soul Frag", Content = "Killing Utsumi...", Duration = 2})
            KillEnemy("Utsumi Lv.80")
            
        else
             -- Wait if neither are spawned
             Fluent:Notify({Title = "Soul Frag", Content = "Waiting for spawns...", Duration = 1})
             task.wait(1)
        end
    end
end

-- // DAGUBA FIX // --
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

local function Kill_Mob_Daguba(Target)
    local RootPart = GetRootPart(); local Hum = Target:FindFirstChild("Humanoid"); local HRP = Target:FindFirstChild("HumanoidRootPart")
    if not Hum or not HRP or not RootPart then return end
    TweenTo(HRP.CFrame * CFrame.new(0, 2, _G.AttackDist), 60)
    local Sticker = RunService.Heartbeat:Connect(function()
        local MyRoot = GetRootPart(); if not MyRoot then return end
        if _G.AutoFarm and Target and Target.Parent == LIVES_FOLDER and Target:FindFirstChild("HumanoidRootPart") and Target.Humanoid.Health > 0 then
            if not _G.IsTransforming then
                local EnemyCF = Target.HumanoidRootPart.CFrame
                local BehindPosition = EnemyCF * CFrame.new(0, HEIGHT_OFFSET, _G.AttackDist)
                MyRoot.CFrame = CFrame.new(BehindPosition.Position, EnemyCF.Position)
                MyRoot.Velocity = Vector3.zero
            end
        else if Sticker then Sticker:Disconnect() end end
    end)
    while _G.AutoFarm and Target.Parent == LIVES_FOLDER do
        if Hum.Health <= 0 then break end
        if _G.IsTransforming then repeat task.wait(0.2) until not _G.IsTransforming else 
            if _G.AutoCombo then RunCombo(Target) else DoCombat() end
        end
        task.wait(ATTACK_SPEED)
    end
    if Sticker then Sticker:Disconnect() end
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
                       
                       -- ADDED WAIT AFTER SUMMON (CRITICAL FIX)
                       task.wait(1.5)
                       
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
local YuiSection = Tabs.Main:AddSection("QUEST")

local QuestDropdown = Tabs.Main:AddDropdown("QuestSelect", {
    Title = "Select Quest",
    Values = {
        "Quest 1-40", 
        "Mummy", 
        "Quest 40-80", 
        "Rook&Bishop", 
        "AGITO", 
        "Miner Goon", 
        "DAGUBA (Auto Dungeon)", 
        "Zyga",
        "ARK",
        "Halloween Chest",
        "ARK + HALLOWEEN CHEST",
        "SOUL FRAG"
    },
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
ToggleHenshin:OnChanged(function() _G.AutoHenshin = Options.AutoHenshin. Value end)
local ToggleEquip = Tabs.Main:AddToggle("AutoEquip", {Title = "Auto Equip Weapon", Default = true })
ToggleEquip:OnChanged(function() _G.AutoEquip = Options.AutoEquip.Value end)

local FormSection = Tabs.Main:AddSection("AUTO FORM")
local FormToggle = Tabs.Main:AddToggle("FormToggle", {Title = "Enable AUTO FORM (X)", Default = false })
FormToggle:OnChanged(function() _G.AutoForm = Options.FormToggle.Value end)
local FormSelect = Tabs.Main:AddDropdown("FormSelect", {Title = "Select Form", Values = {"Survive Bat", "Survival Dragon"}, Multi = false, Default = 1})
FormSelect:OnChanged(function(Value) _G.FormName = Value end)

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

-- // === PASTE THIS IN THE SHARED FUNCTIONS AREA (ABOVE MAIN LOOP) === //

-- 1. CONFIG
local CHEST_SCAN_POSITIONS = {
    CFrame.new(-866.59, 25.52, -288.02),
    CFrame.new(-1088.06, 2.65, -644.51),
    CFrame.new(-1403.94, 0.12, 497.61)
}
local ARK_NPC_POSITION = CFrame.new(-1403.94, 0.12, 497.61)
local SPAWN_POSITIONS = {
    CFrame.new(-866.59, 25.52, -288.02),
    CFrame.new(-1088.06, 2.65, -644.51),
    CFrame.new(-1403.94, 0.12, 497.61)
}

-- 2. CHEST HELPERS
local function FindHalloweenChest()
    if Workspace:FindFirstChild("KeyItem") then
        local Chest = Workspace.KeyItem:FindFirstChild("Halloween Chest")
        if Chest then return Chest end
    end
    return nil
end

local function ScanForChest()
    Fluent:Notify({Title = "Halloween", Content = "Scanning...", Duration = 2})
    
    for i, ScanPos in ipairs(CHEST_SCAN_POSITIONS) do
        if not _G.AutoFarm then return nil end
        
        local RootPart = GetRootPart()
        if not RootPart then return nil end
        
        -- Check BEFORE moving
        local Chest = FindHalloweenChest()
        if Chest then return Chest end

        -- Start Moving
        local Distance = (ScanPos.Position - RootPart.Position).Magnitude
        local Time = Distance / _G.TweenSpeed
        local TweenInfo = TweenInfo.new(Time, Enum.EasingStyle.Linear)
        local Tween = TweenService:Create(RootPart, TweenInfo, {CFrame = ScanPos})
        
        Tween:Play()
        
        -- STOP & GO LOGIC: Scan WHILE moving
        local StartTime = tick()
        while (tick() - StartTime) < Time do
            if not _G.AutoFarm then Tween:Cancel(); return nil end
            if _G.IsTransforming then Tween:Cancel(); while _G.IsTransforming do task.wait(0.1) end return nil end

            -- !!! IF FOUND, STOP TWEEN IMMEDIATELY !!!
            Chest = FindHalloweenChest()
            if Chest then
                local ChestPart = Chest:IsA("BasePart") and Chest or Chest:FindFirstChildWhichIsA("BasePart", true)
                if ChestPart then
                    Tween:Cancel() -- STOP HERE
                    Fluent:Notify({Title = "Found!", Content = "Stopping to collect!", Duration = 2})
                    return Chest
                end
            end
            
            task.wait(0.1)
        end
    end
    return nil
end

local function PressHalloweenChest()
    local Chest = FindHalloweenChest()
    if not Chest then return false end
    local ChestPart = Chest:IsA("BasePart") and Chest or Chest:FindFirstChildWhichIsA("BasePart", true)
    if not ChestPart then return false end
    
    TweenTo(ChestPart.CFrame * CFrame.new(0, 0, 3))
    task.wait(0.5)
    
    local Prompt = Chest:FindFirstChildWhichIsA("ProximityPrompt", true)
    if Prompt then 
        Press_E_Virtual(Prompt, 2) 
        task.wait(2) 
        return true 
    end
    return false
end

local function OpenCurrencyCrate()
    pcall(function() game:GetService("ReplicatedStorage").Remote.Function.InventoryFunction:InvokeServer("Currency Crate I") end)
end

-- 3. MOB HELPERS
local function AreAllHollowedGoonsDead()
    for _, mob in pairs(LIVES_FOLDER:GetChildren()) do
        if mob.Name == "Hollowed Goon Lv.80" then
            local Humanoid = mob:FindFirstChild("Humanoid")
            if Humanoid and Humanoid.Health > 0 then return false end
        end
    end
    return true
end

local function WaitForEnemySpawn()
    local StartTime = tick()
    while (tick() - StartTime) < 5 and _G.AutoFarm do
        if LIVES_FOLDER:FindFirstChild("Hollowed Goon Lv.80") then return true end
        task.wait(0.3)
    end
    return false
end

local function KillAllHollowedGoons()
    local MaxLoops = 50
    local LoopCount = 0
    while _G.AutoFarm and LoopCount < MaxLoops do
        LoopCount = LoopCount + 1
        if AreAllHollowedGoonsDead() then break end
        
        local Enemy = nil
        for _, mob in pairs(LIVES_FOLDER:GetChildren()) do
            if mob.Name == "Hollowed Goon Lv.80" then
                local Humanoid = mob:FindFirstChild("Humanoid")
                if Humanoid and Humanoid.Health > 0 then Enemy = mob; break end
            end
        end
        
        if Enemy then 
            KillEnemy("Hollowed Goon Lv.80")
            task.wait(0.5) 
        else 
            task.wait(0.5) 
        end
    end
end

-- 4. ARK HELPERS
local function GetARKQuestStatus()
    local success, result = pcall(function()
        local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
        local QuestFrame = GUI:FindFirstChild("Desire Games")
        if QuestFrame and QuestFrame:FindFirstChild("TextLabel") and QuestFrame.TextLabel.Visible then
            if string.find(QuestFrame.TextLabel.Text, "Completed") then return "COMPLETED" else return "ACTIVE" end
        end
        return "NONE"
    end)
    return success and result or "NONE"
end

local function AcceptARKQuest()
    TweenTo(ARK_NPC_POSITION); task.wait(1)
    local ARKNpc = Workspace.NPC:FindFirstChild("ARKReplicator")
    if ARKNpc then
        local ARKPart = ARKNpc.PrimaryPart or ARKNpc:FindFirstChild("ARK Replicator") or ARKNpc:FindFirstChildWhichIsA("BasePart")
        if ARKPart then
            TweenTo(ARKPart.CFrame * CFrame.new(0, 0, 3)); task.wait(0.5)
            pcall(function() fireclickdetector(ARKNpc.ClickDetector) end); task.wait(1)
            pcall(function() DIALOGUE_EVENT:FireServer({Choice = "[ Desire Games ]"}) end); task.wait(0.5)
            pcall(function() DIALOGUE_EVENT:FireServer({Exit = true}) end); task.wait(1)
        end
    end
end

local function TurnInARKQuest()
    TweenTo(ARK_NPC_POSITION); task.wait(1)
    local ARKNpc = Workspace.NPC:FindFirstChild("ARKReplicator")
    if ARKNpc then
        local ARKPart = ARKNpc.PrimaryPart or ARKNpc:FindFirstChild("ARK Replicator") or ARKNpc:FindFirstChildWhichIsA("BasePart")
        if ARKPart then
            TweenTo(ARKPart.CFrame * CFrame.new(0, 0, 3)); task.wait(0.5)
            pcall(function() fireclickdetector(ARKNpc.ClickDetector) end); task.wait(1)
            pcall(function() DIALOGUE_EVENT:FireServer({Choice = "Completed it."}) end); task.wait(0.5)
            pcall(function() DIALOGUE_EVENT:FireServer({Exit = true}) end); task.wait(1)
        end
    end
end

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
                
                if QuestDropdown.Value == "Quest 1-40" then
    if _G.AutoQuest then Farm_Yui_Quest() end
    if not _G.AutoFarm then break end
    KillEnemy("Dragon User Lv.7"); task.wait(ATTACK_SPEED)
    if not _G.AutoFarm then break end
    KillEnemy("Crab User Lv.10"); task.wait(ATTACK_SPEED)
    if not _G.AutoFarm then break end
    KillEnemy("Bat User Lv.12")
    if _G.AutoQuest and _G.AutoFarm then WaitForQuestCompletion("Dragon's Alliance") end

elseif QuestDropdown.Value == "Mummy" then
    local Status = GetWindQuestStatus()
    if Status == "COMPLETED" or Status == "NONE" then
        if _G.AutoQuest then Accept_Wind_Quest() end
    elseif Status == "ACTIVE" then
        if not _G.AutoFarm then break end
        KillEnemy("Mummy Lv.40")
    end

elseif QuestDropdown.Value == "Quest 40-80" then
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

elseif QuestDropdown.Value == "Rook&Bishop" then
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

elseif QuestDropdown.Value == "AGITO" then
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
elseif QuestDropdown.Value == "Miner Goon" then
                    local MaxQuests = 5
                    local MaxExchanges = 3
                    if not ExchangeCount then ExchangeCount = 0 end 
                    
                    if CurrentState == "FARMING" then
                        -- 1. PRIORITY: CHECK EXCHANGES (3/3 -> Craft)
                        if ExchangeCount >= MaxExchanges then
                            print("🎯 3 Exchanges done! Going to craft...")
                            CurrentState = "CRAFTING"
                            Fluent:Notify({Title = "Crafting", Content = "3 exchanges complete! Starting craft...", Duration = 3})
                            task.wait(1)
                            RunCraftingRoutine()
                            
                            -- Reset after crafting
                            ExchangeCount = 0
                            QuestCount = 0
                            
                        -- 2. QUEST 5/5 -> GO EXCHANGE
                        elseif QuestCount >= MaxQuests then
                            print("💎 Quests done ("..QuestCount.."), Doing Exchange #" .. (ExchangeCount + 1))
                            
                            local NPC = Workspace.NPC:FindFirstChild("LeeTheMiner")
                            if NPC then
                                local Root = GetRootPart()
                                if Root then
                                    -- Go to NPC
                                    TweenTo(NPC.HumanoidRootPart.CFrame * CFrame.new(0,0,3))
                                    fireclickdetector(NPC.ClickDetector); task.wait(1)
                                    
                                    -- 1. Select Exchange
                                    DIALOGUE_EVENT:FireServer({Choice = "[ Exchange ]"}) 
                                    task.wait(0.5)
                                    
                                    -- 2. Confirm Exchange (ADDED THIS)
                                    DIALOGUE_EVENT:FireServer({Choice = "[ Confirm ]"})
                                    task.wait(0.5)
                                    
                                    -- 3. Exit
                                    DIALOGUE_EVENT:FireServer({Exit = true})
                                    
                                    -- Update Counters
                                    ExchangeCount = ExchangeCount + 1
                                    QuestCount = 0
                                    Fluent:Notify({Title = "Exchange", Content = "Done " .. ExchangeCount .. "/3", Duration = 3})
                                end
                            else
                                Fluent:Notify({Title = "Error", Content = "Miner NPC not found!", Duration = 3})
                            end
                            
                        else
                            -- 3. FARM QUESTS (Normal Logic)
                            if not WarpedToMine then
                                Fluent:Notify({Title = "Status", Content = "Warping to Mine...", Duration = 3})
                                for i=1,5 do WarpTo("Mine's Field"); task.wait(0.2) end
                                task.wait(3); WarpedToMine = true
                            end
                            
                            if _G.AutoQuest then
                                local Status = GetMinerGoonQuestStatus()
                                if Status == "COMPLETED" or Status == "NONE" then 
                                    Accept_MinerGoon_Quest() 
                                    -- Note: Accept function should increment QuestCount when turning in!
                                elseif Status == "ACTIVE" then 
                                    if not _G.AutoFarm then break end
                                    KillEnemy("Miner Goon Lv.50") 
                                end
                            else 
                                KillEnemy("Miner Goon Lv.50") 
                            end
                        end
                        
                    elseif CurrentState == "CRAFTING" then
                        task.wait(1)
                    end

elseif QuestDropdown.Value == "DAGUBA (Auto Dungeon)" then
    local Status = GetDagubaQuestStatus()
    
    if Status == "COMPLETED" then
        CancelMovement()
        Fluent:Notify({Title = "Daguba", Content = "Quest Completed! Waiting 20s...", Duration = 5})
        for i = 1, 20 do if not _G.AutoFarm then break end task.wait(1) end
        if _G.AutoFarm then Accept_Daguba_Quest() end
        
    elseif IsInAncientDungeon() then
        Run_Daguba_Sequence()
        task.wait(2)
        
    elseif Status == "NONE" then
        Accept_Daguba_Quest()
        
    elseif Status == "ACTIVE" then
        if not IsEnteringDungeon then
            IsEnteringDungeon = true
            RIDER_TRIAL_EVENT:FireServer("Trial of Ancient") 
            
            local T = 0
            repeat 
                task.wait(1)
                T = T + 1
            until IsInAncientDungeon() or T > 10 or not _G.AutoFarm
            
            IsEnteringDungeon = false
        end
        task.wait(2)
    end

elseif QuestDropdown.Value == "Zyga" then
    RunZygaLogic()
-- ✅ HALLOWEEN CHEST AUTO FARM (IMPROVED)
elseif QuestDropdown.Value == "Halloween Chest" then
    -- Define chest scan positions
    local CHEST_SCAN_POSITIONS = {
        CFrame.new(-866.59, 25.52, -288.02),
        CFrame.new(-1088.06, 2.65, -644.51),
        CFrame.new(-1403.94, 0.12, 497.61)
    }
    
    -- Helper function to find Halloween Chest
    local function FindHalloweenChest()
        if Workspace:FindFirstChild("KeyItem") then
            local Chest = Workspace.KeyItem:FindFirstChild("Halloween Chest")
            if Chest then
                return Chest
            end
        end
        return nil
    end
    
    -- Helper function to press chest
    local function PressHalloweenChest()
        local Chest = FindHalloweenChest()
        
        if not Chest then
            warn("⚠️ Halloween Chest not found!")
            return false
        end
        
        -- Get the chest's BasePart
        local ChestPart = Chest:IsA("BasePart") and Chest or Chest:FindFirstChildWhichIsA("BasePart", true)
        
        if not ChestPart then
            warn("⚠️ Halloween Chest part not found!")
            return false
        end
        
        -- Tween to chest
        Fluent:Notify({Title = "Halloween", Content = "Opening chest...", Duration = 2})
        TweenTo(ChestPart.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
        
        -- Find and press ProximityPrompt
        local Prompt = Chest:FindFirstChildWhichIsA("ProximityPrompt", true)
        
        if Prompt then
            Press_E_Virtual(Prompt, 2)
            task.wait(2)
            return true
        else
            warn("⚠️ Halloween Chest ProximityPrompt not found!")
            return false
        end
    end
    
    -- ✅ NEW: Helper function to open Currency Crate
    local function OpenCurrencyCrate()
        local success, result = pcall(function()
            local Event = game:GetService("ReplicatedStorage").Remote.Function.InventoryFunction
            return Event:InvokeServer("Currency Crate I")
        end)
        
        if success then
            Fluent:Notify({Title = "Halloween", Content = "Opened Currency Crate!", Duration = 2})
            print("✅ Currency Crate opened successfully")
            return true
        else
            warn("⚠️ Failed to open Currency Crate:", result)
            return false
        end
    end
    
    -- ✅ NEW: Improved function to detect if all Hollowed Goons are dead
    local function AreAllHollowedGoonsDead()
        -- Check if ANY Hollowed Goon exists in Lives folder
        for _, mob in pairs(LIVES_FOLDER:GetChildren()) do
            if mob.Name == "Hollowed Goon Lv.80" then
                -- Found one, check if it's alive
                local Humanoid = mob:FindFirstChild("Humanoid")
                if Humanoid and Humanoid.Health > 0 then
                    return false -- At least one is still alive
                end
            end
        end
        
        -- No alive Hollowed Goons found
        return true
    end
    
    -- ✅ NEW: Function to wait for enemies to spawn
    local function WaitForEnemySpawn()
        Fluent:Notify({Title = "Halloween", Content = "Waiting for enemies to spawn...", Duration = 2})
        
        local StartTime = tick()
        local MaxWaitTime = 5
        
        while (tick() - StartTime) < MaxWaitTime and _G.AutoFarm do
            if LIVES_FOLDER:FindFirstChild("Hollowed Goon Lv.80") then
                Fluent:Notify({Title = "Halloween", Content = "Enemies spawned!", Duration = 2})
                return true
            end
            task.wait(0.3)
        end
        
        -- No enemies spawned - probably already got reward
        return false
    end
    
    -- Helper function to scan for chest at both positions
    local function ScanForChest()
        Fluent:Notify({Title = "Halloween", Content = "Scanning for chest...", Duration = 2})
        
        for i, ScanPos in ipairs(CHEST_SCAN_POSITIONS) do
            if not _G.AutoFarm then return nil end
            
            -- Go to scan position
            TweenTo(ScanPos)
            task.wait(1)
            
            -- Check if chest is nearby
            local Chest = FindHalloweenChest()
            if Chest then
                local ChestPart = Chest:IsA("BasePart") and Chest or Chest:FindFirstChildWhichIsA("BasePart", true)
                if ChestPart then
                    local Distance = (GetRootPart().Position - ChestPart.Position).Magnitude
                    if Distance < 200 then -- Chest is nearby
                        Fluent:Notify({Title = "Halloween", Content = "Chest found at position " .. i .. "!", Duration = 2})
                        return Chest
                    end
                end
            end
        end
        
        return nil
    end
    
    -- ✅ IMPROVED: Kill all Hollowed Goons until none remain
    local function KillAllHollowedGoons()
        Fluent:Notify({Title = "Halloween", Content = "Starting combat...", Duration = 2})
        
        local MaxLoops = 50 -- Safety limit to prevent infinite loop
        local LoopCount = 0
        
        while _G.AutoFarm and LoopCount < MaxLoops do
            LoopCount = LoopCount + 1
            
            -- Check if all enemies are dead
            if AreAllHollowedGoonsDead() then
                Fluent:Notify({Title = "Halloween", Content = "All enemies defeated!", Duration = 3})
                print("✅ All Hollowed Goons are dead!")
                break
            end
            
            -- Still have enemies, find and kill one
            local Enemy = nil
            
            -- Find any alive Hollowed Goon
            for _, mob in pairs(LIVES_FOLDER:GetChildren()) do
                if mob.Name == "Hollowed Goon Lv.80" then
                    local Humanoid = mob:FindFirstChild("Humanoid")
                    if Humanoid and Humanoid.Health > 0 then
                        Enemy = mob
                        break
                    end
                end
            end
            
            if Enemy then
                -- Found alive enemy, kill it
                Fluent:Notify({Title = "Halloween", Content = "Enemy detected! Attacking...", Duration = 1})
                KillEnemy("Hollowed Goon Lv.80")
                task.wait(0.5) -- Brief wait before checking again
            else
                -- No enemy found but function says they're not all dead?
                -- Wait a moment and check again
                task.wait(0.5)
            end
        end
        
        if LoopCount >= MaxLoops then
            warn("⚠️ Kill loop reached safety limit!")
        end
        
        task.wait(1)
    end
    
    -- Main Halloween Chest Loop
    if not _G.AutoFarm then break end
    
    -- Step 1: Scan for chest at both positions
    local FoundChest = ScanForChest()
    
    if not FoundChest then
        -- Chest not found at either position, try direct approach
        Fluent:Notify({Title = "Halloween", Content = "Chest not found, trying direct...", Duration = 2})
        FoundChest = FindHalloweenChest()
    end
    
    if not FoundChest then
        warn("⚠️ Halloween Chest not found anywhere!")
        Fluent:Notify({Title = "Error", Content = "Halloween Chest not found!", Duration = 5})
        task.wait(5)
    else
        -- Step 2: Press the chest
        local ChestPressed = PressHalloweenChest()
        
        if ChestPressed then
            -- Step 3: Wait for enemies to spawn (or detect already got reward)
            local EnemiesSpawned = WaitForEnemySpawn()
            
            if not EnemiesSpawned then
                -- No enemies spawned = already got reward
                Fluent:Notify({Title = "Halloween", Content = "Already received reward today!", Duration = 3})
                
                -- ✅ Open Currency Crate anyway
                task.wait(1)
                OpenCurrencyCrate()
                
                task.wait(10)
            else
                -- Step 4: Kill all spawned Hollowed Goons
                task.wait(1) -- Brief wait for all enemies to spawn
                KillAllHollowedGoons()
                
                -- Step 5: Verify all are dead before proceeding
                if not AreAllHollowedGoonsDead() then
                    warn("⚠️ Warning: Some enemies may still be alive!")
                    task.wait(3) -- Extra wait
                end
                
                -- Step 6: Return to chest and press again to collect reward
                if not _G.AutoFarm then break end
                
                Fluent:Notify({Title = "Halloween", Content = "Returning to chest for reward...", Duration = 2})
                
                local FinalChest = FindHalloweenChest()
                if FinalChest then
                    PressHalloweenChest()
                    task.wait(2)
                    
                    -- ✅ Open Currency Crate after collecting reward
                    OpenCurrencyCrate()
                    
                    Fluent:Notify({Title = "Halloween", Content = "Cycle complete! Restarting...", Duration = 3})
                    task.wait(3)
                else
                    warn("⚠️ Could not find chest after killing enemies!")
                    task.wait(5)
                end
            end
        end
    end
elseif QuestDropdown.Value == "SOUL FRAG" then
                    Farm_Soul_Frag_Quest()
elseif QuestDropdown.Value == "ARK + HALLOWEEN CHEST" then
                    -- // 1. CHECK ARK QUEST // --
                    local ArkStatus = GetARKQuestStatus()
                    
                    -- Local helper to open cache multiple times
                    local function OpenProgrise(times)
                        for i = 1, times do
                            pcall(function() 
                                game:GetService("ReplicatedStorage").Remote.Function.InventoryFunction:InvokeServer("Progrise Cache")
                            end)
                            task.wait(0.2)
                        end
                        Fluent:Notify({Title = "Cache", Content = "Opened Progrise Cache x" .. times, Duration = 2})
                    end

                    if ArkStatus == "NONE" then 
                        AcceptARKQuest() 
                        
                    elseif ArkStatus == "ACTIVE" then
                        -- Hunt ARK Boss
                        local Enemy = LIVES_FOLDER:FindFirstChild("Possessed Rider Lv.90")
                        
                        -- If Boss found, Kill it
                        if Enemy and Enemy:FindFirstChild("Humanoid") and Enemy.Humanoid.Health > 0 then 
                            Fluent:Notify({Title = "ARK", Content = "Fighting Possessed Rider...", Duration = 2})
                            KillEnemy("Possessed Rider Lv.90")
                            
                            -- OPEN CACHE 2x AFTER KILL
                            OpenProgrise(2)
                        else
                            -- If not found, Scan spawn locations
                            Fluent:Notify({Title = "ARK", Content = "Scanning for Boss...", Duration = 1})
                            for _, pos in ipairs(SPAWN_POSITIONS) do
                                if not _G.AutoFarm then break end
                                TweenTo(pos); task.wait(1)
                                local E = LIVES_FOLDER:FindFirstChild("Possessed Rider Lv.90")
                                if E and E:FindFirstChild("Humanoid") and E.Humanoid.Health > 0 then 
                                    KillEnemy("Possessed Rider Lv.90")
                                    
                                    -- OPEN CACHE 2x AFTER KILL
                                    OpenProgrise(2)
                                    break 
                                end
                            end
                        end
                        
                    elseif ArkStatus == "COMPLETED" then 
                        -- Turn in Quest
                        TurnInARKQuest()
                        
                        -- OPEN CACHE 2x AFTER TURN IN
                        OpenProgrise(2)
                        
                        -- // 2. SWITCH TO HALLOWEEN CHEST // --
                        if _G.AutoFarm then
                            Fluent:Notify({Title = "Switch", Content = "Going to Halloween Chest...", Duration = 3})
                            task.wait(1)
                            
                            -- Find Chest
                            local Chest = ScanForChest()
                            if not Chest then Chest = FindHalloweenChest() end
                            
                            if Chest then
                                -- 1. Press Chest to Summon Mobs
                                local Opened = PressHalloweenChest()
                                
                                if Opened then
                                    -- 2. Wait for Mobs & Kill
                                    local EnemiesSpawned = WaitForEnemySpawn()
                                    if EnemiesSpawned then
                                        KillAllHollowedGoons()
                                        task.wait(1)
                                        
                                        -- 3. Press Chest again for Reward
                                        PressHalloweenChest()
                                        
                                        -- 4. Open Currency Crate
                                        OpenCurrencyCrate()
                                        
                                        Fluent:Notify({Title = "Cycle Complete", Content = "Restarting loop...", Duration = 3})
                                    else
                                        -- If no enemies spawned, try opening crate anyway (maybe lag)
                                        OpenCurrencyCrate()
                                    end
                                end
                            else
                                Fluent:Notify({Title = "Skip", Content = "Halloween Chest not found!", Duration = 2})
                            end
                        end
                    end
-- ✅ IMPROVED ARK QUEST WITH FULL LOGIC (keep this as is)
elseif QuestDropdown.Value == "ARK" then
    -- Define positions
    local ARK_NPC_POSITION = CFrame.new(-1403.94, 0.12, 497.61)
    local SPAWN_POSITIONS = {
        CFrame.new(-866.59, 25.52, -288.02),
        CFrame.new(-1088.06, 2.65, -644.51),
        CFrame.new(-1403.94, 0.12, 497.61)
    }
    
    -- Helper function to check quest status
    local function GetARKQuestStatus()
        local success, result = pcall(function()
            local GUI = LocalPlayer.PlayerGui.Main.QuestAlertFrame.QuestGUI
            local QuestFrame = GUI:FindFirstChild("Desire Games")
            
            if QuestFrame and QuestFrame:FindFirstChild("TextLabel") then
                local TextLabel = QuestFrame.TextLabel
                if TextLabel.Visible then
                    -- Quest is active - check if completed
                    if string.find(TextLabel.Text, "Completed") then
                        return "COMPLETED"
                    else
                        return "ACTIVE"
                    end
                end
            end
            return "NONE"
        end)
        
        return success and result or "NONE"
    end
    
    -- Helper function to accept ARK quest
    local function AcceptARKQuest()
        Fluent:Notify({Title = "ARK Quest", Content = "Accepting quest...", Duration = 2})
        
        -- Step 1: Go to NPC position
        TweenTo(ARK_NPC_POSITION)
        task.wait(1)
        
        -- Step 2: Find and interact with NPC
        local ARKNpc = Workspace.NPC:FindFirstChild("ARKReplicator")
        if ARKNpc then
            local ARKPart = ARKNpc.PrimaryPart or ARKNpc:FindFirstChild("ARK Replicator") or ARKNpc:FindFirstChildWhichIsA("BasePart")
            
            if ARKPart then
                TweenTo(ARKPart.CFrame * CFrame.new(0, 0, 3))
                task.wait(0.5)
                
                -- Click NPC
                pcall(function()
                    fireclickdetector(ARKNpc.ClickDetector)
                end)
                task.wait(1)
                
                -- Send dialogue to get quest
                pcall(function()
                    DIALOGUE_EVENT:FireServer({Choice = "[ Desire Games ]"})
                end)
                task.wait(0.5)
                
                pcall(function()
                    DIALOGUE_EVENT:FireServer({Exit = true})
                end)
                task.wait(1)
                
                Fluent:Notify({Title = "ARK Quest", Content = "Quest accepted!", Duration = 2})
            else
                warn("⚠️ ARKReplicator part not found!")
            end
        else
            warn("⚠️ ARKReplicator NPC not found!")
        end
    end
    
    -- Helper function to turn in completed quest
    local function TurnInARKQuest()
        Fluent:Notify({Title = "ARK Quest", Content = "Quest completed! Turning in...", Duration = 2})
        
        -- Step 1: Return to NPC position
        TweenTo(ARK_NPC_POSITION)
        task.wait(1)
        
        -- Step 2: Find and interact with NPC
        local ARKNpc = Workspace.NPC:FindFirstChild("ARKReplicator")
        if ARKNpc then
            local ARKPart = ARKNpc.PrimaryPart or ARKNpc:FindFirstChild("ARK Replicator") or ARKNpc:FindFirstChildWhichIsA("BasePart")
            
            if ARKPart then
                TweenTo(ARKPart.CFrame * CFrame.new(0, 0, 3))
                task.wait(0.5)
                
                -- Click NPC
                pcall(function()
                    fireclickdetector(ARKNpc.ClickDetector)
                end)
                task.wait(1)
                
                -- Turn in quest
                pcall(function()
                    DIALOGUE_EVENT:FireServer({Choice = "Completed it."})
                end)
                task.wait(0.5)
                
                pcall(function()
                    DIALOGUE_EVENT:FireServer({Exit = true})
                end)
                task.wait(1)
                
                Fluent:Notify({Title = "ARK Quest", Content = "Quest turned in! Restarting...", Duration = 2})
            end
        end
    end
    
    -- Main ARK Quest Logic
    local Status = GetARKQuestStatus()
    
    if Status == "NONE" then
        -- No quest active, go accept it
        AcceptARKQuest()
        
    elseif Status == "COMPLETED" then
        -- Quest completed, turn it in
        TurnInARKQuest()
        
    elseif Status == "ACTIVE" then
        -- Quest active, go kill the enemy
        if not _G.AutoFarm then break end
        
        -- First, check if enemy already spawned
        local Enemy = LIVES_FOLDER:FindFirstChild("Possessed Rider Lv.90")
        
        if Enemy and Enemy:FindFirstChild("HumanoidRootPart") and Enemy:FindFirstChild("Humanoid") and Enemy.Humanoid.Health > 0 then
            -- Enemy found! Go directly to it
            Fluent:Notify({Title = "ARK Quest", Content = "Enemy found! Attacking...", Duration = 2})
            KillEnemy("Possessed Rider Lv.90")
        else
            -- Enemy not found, check spawn positions
            Fluent:Notify({Title = "ARK Quest", Content = "Searching for enemy...", Duration = 2})
            
            for i, SpawnPos in ipairs(SPAWN_POSITIONS) do
                if not _G.AutoFarm then break end
                
                -- Go to spawn position
                TweenTo(SpawnPos)
                task.wait(1)
                
                -- Check if enemy spawned
                Enemy = LIVES_FOLDER:FindFirstChild("Possessed Rider Lv.90")
                
                if Enemy and Enemy:FindFirstChild("HumanoidRootPart") and Enemy:FindFirstChild("Humanoid") and Enemy.Humanoid.Health > 0 then
                    -- Found the enemy!
                    Fluent:Notify({Title = "ARK Quest", Content = "Enemy spotted! Attacking...", Duration = 2})
                    KillEnemy("Possessed Rider Lv.90")
                    break
                end
            end
            
            -- If still not found after checking all positions, just kill normally
            if not _G.AutoFarm then break end
            KillEnemy("Possessed Rider Lv.90")
        end
    end

end -- ✅ CLOSE the main quest selection

task.wait(1)

task.wait(1) -- ✅ ADD THIS LINE (was missing!)

            end  -- ✅ Close task.spawn function
        end)
    end
end)  -- ✅ Close FarmToggle:OnChanged

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/RiderWorld")
InterfaceManager:BuildInterfaceSection(Tabs. Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({Title = "Script Loaded", Content = " Open Progrise", Duration = 5})
SaveManager:LoadAutoloadConfig()
