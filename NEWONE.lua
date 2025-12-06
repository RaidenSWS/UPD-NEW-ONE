-- // RIDER WORLD SCRIPT // --
-- // VERSION: ADDED AUTO ROOK & BISHOP // --

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- // 1. WINDOW // --
local Window = Fluent:CreateWindow({
    Title = "เสี่ยปาล์มขอเงินฟรี",
    SubTitle = "Auto Rook & Bishop Added",
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

-- NEW: ROOK & BISHOP VARS
local ROOK_BISHOP_SUMMON_CF = CFrame.new(4779.29, 8.53, 97.93)

_G.AutoSkill = false
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

local function CancelMovement()
    local Root = GetRootPart()
    if Root then Root.Velocity = Vector3.zero end
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

-- GENERIC SKILL FIRE
local function FireSkill(key)
    if not _G.AutoFarm then return end
    local Character = LocalPlayer.Character
    local Handler = Character and Character:FindFirstChild("PlayerHandler")
    local Event = Handler and Handler:FindFirstChild("HandlerEvent")
    if Event then
        local args = { ["Skill"] = true, ["Key"] = key }
        -- OLD LOGIC RESTORED: Include FormHenshin if X is pressed
        if key == "X" then args["FormHenshin"] = _G.FormName end
        Event:FireServer(args)
    end
end

-- *** SPECIFIC HENSHIN FUNCTION (H) ***
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

-- // OLD AUTO FORM LOGIC (RESTORED) // --
-- This runs constantly if toggle is ON
task.spawn(function()
    while task.wait() do
        if _G.AutoForm and not _G.IsTransforming and not _G.QuestingMode then
            FireSkill("X")
            task.wait(2)
        end
    end
end)

-- // CLIENT LISTENER FOR TRANSFORM (X) - RESTORED // --
CLIENT_NOTIFIER.OnClientEvent:Connect(function(Data)
    if _G.QuestingMode then return end
    
    -- OLD TRANSFORM LOGIC
    if _G.AutoForm and type(Data) == "table" and Data.Text == "You can now transform to Special Form!" then
        if not _G.IsTransforming then
            _G.IsTransforming = true 
            Fluent:Notify({Title = "AUTO FORM", Content = "Transforming...", Duration = 5})
            FireSkill("X")
            task.wait(8) -- Old wait time
            _G.IsTransforming = false 
        end
    end
    
    -- STAMINA BUG FIX (Keep this because it's useful)
    if type(Data) == "table" and Data.Text then 
        local txt = string.lower(Data.Text)
        if string.find(txt, "dont have enough stamina") or string.find(txt, "don't have enough stamina") then
            local Char = LocalPlayer.Character
            if Char and Char:FindFirstChild("Humanoid") then
                Char.Humanoid.Health = 0
            end
        end
    end
end)

-- // RESET FLAGS ON SPAWN // --
LocalPlayer.CharacterAdded:Connect(function()
    HenshinDone = false
    EquipDone = false
end)

-- // MAIN LOOP FOR EQUIP & HENSHIN (H) // --
task.spawn(function()
    while task.wait(1) do
        if _G.AutoFarm then
            local Character = LocalPlayer.Character
            local Handler = Character and Character:FindFirstChild("PlayerHandler")
            
            -- 1. AUTO EQUIP (One Time)
            if _G.AutoEquip and not EquipDone and Character and Character:FindFirstChild("Humanoid") then
                local Tool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
                if Tool then
                    Character.Humanoid:EquipTool(Tool)
                    EquipDone = true -- Lock it
                    -- Fluent:Notify({Title = "Equip", Content = "Weapon Equipped!", Duration = 2})
                end
            end
            
            -- 2. AUTO HENSHIN (KEY H) (One Time)
            if _G.AutoHenshin and not HenshinDone and Handler then
                task.wait(3) -- Wait 3s after spawn to load
                FireHenshin()
                HenshinDone = true -- Lock it
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

-- // DESTRUCTIVE GUI CLOSE // --
local function ClickExitButton()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end
    
    local CraftingGUI = PlayerGui:FindFirstChild("CraftingGUI")
    if CraftingGUI then
        local ExitBtn = CraftingGUI:FindFirstChild("Exit") 
        if ExitBtn then
            if VirtualInputManager then
                local pos = ExitBtn.AbsolutePosition
                local size = ExitBtn.AbsoluteSize
                local center = Vector2.new(pos.X + size.X/2, pos.Y + size.Y/2)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            end
            for _, c in pairs(getconnections(ExitBtn.MouseButton1Click)) do c:Fire() end
        end
        DIALOGUE_EVENT:FireServer({Exit = true})
    end
    
    local Char = LocalPlayer.Character
    if Char then
        local HRP = Char:FindFirstChild("HumanoidRootPart")
        if HRP then HRP.Anchored = false end
    end
end

-- // CRAFTING ROUTINE // --

local function RunCraftingRoutine()
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
        TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
        
        local Clicker = NPC_Craft:FindFirstChild("ClickDetector")
        if Clicker then fireclickdetector(Clicker); task.wait(1) end
        DIALOGUE_EVENT:FireServer({Choice = "[ Craft ]"})
        task.wait(1)
        
        -- // SMART SIGNAL LISTENER // --
        CraftStatusSignal = "IDLE"
        local Connection
        Connection = CRAFTING_EVENT.OnClientEvent:Connect(function(Data)
            if type(Data) == "table" and Data.Callback then
                local msg = string.lower(Data.Callback)
                
                if string.find(msg, "limit") or string.find(msg, "unable") or string.find(msg, "max") or string.find(msg, "full") then
                    CraftStatusSignal = "MAX"
                elseif string.find(msg, "not enough") and not string.find(msg, "limit") then
                    CraftStatusSignal = "EMPTY" 
                end
            end
        end)
        
        local StartCraftTime = tick()
        local CraftList = {"Blue Fragment", "Red Fragment", "Blue Sappyre", "Red Emperor"}
        local MustReturnToFarm = false
        
        for _, ItemName in ipairs(CraftList) do
            if not _G.AutoFarm then break end
            if MustReturnToFarm then break end
            
            if (tick() - StartCraftTime) > 60 then break end
            
            local ItemActive = true
            local ItemAttempt = 0
            
            Fluent:Notify({Title = "Crafting", Content = "Crafting: " .. ItemName, Duration = 2})
            
            while _G.AutoFarm and ItemActive do
                CraftStatusSignal = "IDLE"
                CRAFTING_EVENT:FireServer("Special", ItemName)
                task.wait(0.3) 
                
                ItemAttempt = ItemAttempt + 1
                
                if CraftStatusSignal == "MAX" then
                    Fluent:Notify({Title = "Crafting", Content = ItemName .. " Limit Reached! Switching...", Duration = 2})
                    ItemActive = false 
                    
                elseif CraftStatusSignal == "EMPTY" then
                    Fluent:Notify({Title = "Crafting", Content = "Materials Empty! Returning...", Duration = 3})
                    ItemActive = false
                    MustReturnToFarm = true 
                    
                elseif ItemAttempt > 20 then
                    Fluent:Notify({Title = "Skipping", Content = ItemName .. " (Timeout)", Duration = 2})
                    ItemActive = false 
                end
                
                if (tick() - StartCraftTime) > 60 then MustReturnToFarm = true; break end
            end
        end
        
        if Connection then Connection:Disconnect() end
        
        ClickExitButton()
        task.wait(1) 
        
        -- // TACTICAL RESPAWN // --
        CurrentState = "FARMING"
        QuestCount = 0 
        WarpedToMine = false 
        
        Fluent:Notify({Title = "Unstucking", Content = "Respawning to Clear UI State...", Duration = 3})
        
        local Char = LocalPlayer.Character
        if Char and Char:FindFirstChild("Humanoid") then
            Char.Humanoid.Health = 0
        end
        
        LocalPlayer.CharacterAdded:Wait()
        local NewChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        NewChar:WaitForChild("HumanoidRootPart")
        task.wait(2) 
        
        Fluent:Notify({Title = "Return", Content = "Respawned! Warping to Mine...", Duration = 3})
        for i = 1, 5 do 
            WarpTo("Mine's Field")
            task.wait(0.5) 
        end
        
        task.wait(1) 
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

local function WaitForDialogueUI()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return false end
    
    local Timeout = 0
    while _G.AutoFarm and Timeout < 20 do 
        if PlayerGui:FindFirstChild("DialogueGui") or PlayerGui:FindFirstChild("Dialogue") or PlayerGui:FindFirstChild("NPCGui") then
            return true
        end
        Timeout = Timeout + 1
        Fluent:Notify({Title = "Waiting", Content = "Waiting for Dialogue Window...", Duration = 1})
        task.wait(0.5)
    end
    return false
end

local function Accept_MinerGoon_Quest()
    while _G.IsTransforming do 
        Fluent:Notify({Title = "Paused", Content = "Waiting for Transformation...", Duration = 1})
        task.wait(1)
        if not _G.AutoFarm then return end
    end

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
            
            if not WaitForDialogueUI() then
                _G.QuestingMode = false
                return 
            end
            
            local Status = GetMinerGoonQuestStatus()
            
            if Status == "NONE" then
                 local steps = {{Choice = "[ Quest ]"}, {Choice = "[ Repeatable ]"}, {Choice = "Okay"}, {Exit = true}}
                 for _, step in ipairs(steps) do
                     if not _G.AutoFarm then break end
                     if step.Exit then DIALOGUE_EVENT:FireServer({Exit = true}) 
                     else DIALOGUE_EVENT:FireServer(step) end
                     task.wait(0.5)
                 end
                 
            elseif Status == "COMPLETED" then
                 DIALOGUE_EVENT:FireServer({Choice = "Yes, I've done it."})
                 task.wait(0.5)
                 DIALOGUE_EVENT:FireServer({Choice = "Okay"})
                 task.wait(0.5)
                 DIALOGUE_EVENT:FireServer({Exit = true})
                 
                 QuestCount = QuestCount + 1
                 Fluent:Notify({Title = "Progress", Content = "Quest: " .. tostring(QuestCount) .. " / " .. tostring(MaxQuests), Duration = 3})
            end
            
            task.wait(1)
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

-- // WIND EXPERT (MUMMY) FUNCTIONS // --

local function GetWindQuestStatus()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        if GUI:FindFirstChild("Mummy Return?") and GUI["Mummy Return?"].Visible then
            if string.find(GUI["Mummy Return?"].TextLabel.Text, "Completed") then
                return "COMPLETED"
            end
            return "ACTIVE"
        end
    end
    return "NONE"
end

local function Accept_Wind_Quest()
    while _G.IsTransforming do task.wait(1) end

    local NPC = Workspace:WaitForChild("NPC"):FindFirstChild("WindTourist")
    if NPC then
        local Root = NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChild("Torso")
        if Root then
            _G.QuestingMode = true
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            
            local Clicker = NPC:FindFirstChild("ClickDetector")
            if Clicker then fireclickdetector(Clicker) end
            
            task.wait(1) 
            local Status = GetWindQuestStatus()
            
            if Status == "NONE" then
                DIALOGUE_EVENT:FireServer({Choice = "Sure!"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Mummy Return?"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Start 'Mummy Return?'"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Exit = true})
                
            elseif Status == "COMPLETED" then
                DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Mummy Return?"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Start 'Mummy Return?'"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Exit = true})
            end
            
            task.wait(1)
            _G.QuestingMode = false
        end
    end
end

-- // MALCOM (AUTO 40-80) FUNCTIONS // --

local function GetMalcomQuestStatus()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        if GUI:FindFirstChild("The Hunt Hunted") and GUI["The Hunt Hunted"].Visible then
            if string.find(GUI["The Hunt Hunted"].TextLabel.Text, "Completed") then
                return "COMPLETED"
            end
            return "ACTIVE"
        end
    end
    return "NONE"
end

local function Accept_Malcom_Quest()
    while _G.IsTransforming do task.wait(1) end

    local NPC = Workspace:WaitForChild("NPC"):FindFirstChild("Malcom")
    if NPC then
        local Root = NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChild("Torso")
        if Root then
            _G.QuestingMode = true
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            
            local Clicker = NPC:FindFirstChild("ClickDetector")
            if Clicker then fireclickdetector(Clicker) end
            
            task.wait(1)
            local Status = GetMalcomQuestStatus()
            
            if Status == "NONE" then
                DIALOGUE_EVENT:FireServer({Choice = "I'm ready for the challenge!"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "The Hunt Hunted"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Start 'The Hunt Hunted'"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Exit = true})
                
            elseif Status == "COMPLETED" then
                DIALOGUE_EVENT:FireServer({Choice = "Yes, I've completed it."})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Can I get another quest?"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "The Hunt Hunted"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Choice = "Start 'The Hunt Hunted'"})
                task.wait(0.5)
                DIALOGUE_EVENT:FireServer({Exit = true})
            end
            
            task.wait(1)
            _G.QuestingMode = false
        end
    end
end

-- // ROOK & BISHOP (AUTO ROOK&BISHOP) FUNCTIONS // --

local function GetRookBishopQuestStatus()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if PlayerGui then
        local GUI = PlayerGui.Main.QuestAlertFrame.QuestGUI
        if GUI:FindFirstChild("Double or Solo") and GUI["Double or Solo"].Visible then
            if string.find(GUI["Double or Solo"].TextLabel.Text, "Completed") then
                return "COMPLETED"
            end
            return "ACTIVE"
        end
    end
    return "NONE"
end

local function Accept_RookBishop_Quest()
    while _G.IsTransforming do task.wait(1) end
    
    -- Keisuke is the NPC
    local NPC = Workspace:WaitForChild("NPC"):FindFirstChild("Keisuke")
    if NPC then
        local Root = NPC:FindFirstChild("HumanoidRootPart") or NPC:FindFirstChild("Torso")
        if Root then
            _G.QuestingMode = true
            TweenTo(Root.CFrame * CFrame.new(0, 0, 3))
            task.wait(0.2)
            if not _G.AutoFarm then _G.QuestingMode = false; return end
            
            local Clicker = NPC:FindFirstChild("ClickDetector")
            if Clicker then fireclickdetector(Clicker) end
            
            task.wait(1)
            local Status = GetRookBishopQuestStatus()
            
            -- Simple logic: [ Repeatable Quest ] -> Exit
            -- Works for both Accept and Turn In according to logs
            DIALOGUE_EVENT:FireServer({Choice = "[ Repeatable Quest ]"})
            task.wait(0.5)
            DIALOGUE_EVENT:FireServer({Exit = true})
            
            task.wait(1)
            _G.QuestingMode = false
        end
    end
end

local function Summon_RookBishop()
    if not _G.AutoFarm then return end
    
    -- Check if bosses already exist
    if LIVES_FOLDER:FindFirstChild("Bishop Lv.80") or LIVES_FOLDER:FindFirstChild("Rook Lv.80") then
        return -- Already summoned
    end
    
    -- Go to Summon Spot
    TweenTo(ROOK_BISHOP_SUMMON_CF)
    task.wait(0.5)
    
    -- Press E logic (needs to find the ProximityPrompt at this location)
    -- Assuming there is a part nearby with a prompt
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and (v.Parent.Position - ROOK_BISHOP_SUMMON_CF.Position).Magnitude < 10 then
            fireproximityprompt(v)
            break
        end
    end
    task.wait(1.5)
end

-- // AUTO ZYGA LOGIC // --
local function RunZygaLogic()
    if IsEnteringDungeon then return end
    
    local Boss = LIVES_FOLDER:FindFirstChild("Zyga Lv.85")
    
    if not Boss then
        IsEnteringDungeon = true
        Fluent:Notify({Title = "Auto Zyga", Content = "Starting Trial...", Duration = 3})
        
        RIDER_TRIAL_EVENT:FireServer("Trial of Zyga")
        
        local T = 0
        repeat 
            task.wait(1)
            T = T + 1
            Boss = LIVES_FOLDER:FindFirstChild("Zyga Lv.85")
        until Boss or T > 15 or not _G.AutoFarm
        
        IsEnteringDungeon = false
        task.wait(2)
    else
        KillEnemy("Zyga Lv.85")
        
        if not LIVES_FOLDER:FindFirstChild("Zyga Lv.85") and _G.AutoFarm then
            Fluent:Notify({Title = "Auto Zyga", Content = "Boss Dead! Waiting 20s...", Duration = 20})
            CancelMovement()
            task.wait(20)
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

local PreparationSection = Tabs.Main:AddSection("PREPARATION")
local ToggleHenshin = Tabs.Main:AddToggle("AutoHenshin", {Title = "Auto Henshin (H)", Default = true })
ToggleHenshin:OnChanged(function() _G.AutoHenshin = Options.AutoHenshin.Value end)
local ToggleEquip = Tabs.Main:AddToggle("AutoEquip", {Title = "Auto Equip Weapon", Default = true })
ToggleEquip:OnChanged(function() _G.AutoEquip = Options.AutoEquip.Value end)

-- RESTORED: AUTO FORM (X) IN ITS OWN SECTION
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
    -- !!! FIX: ALWAYS WARP FIRST WHEN TOGGLED ON !!! --
    WarpedToMine = false 
    
    if _G.AutoFarm then
        -- !!! NEW: RESET FLAGS ON TOGGLE START !!!
        -- This ensures it runs once every time you enable the farm
        HenshinDoneForThisLife = false 
        EquipDoneForThisLife = false

        task.spawn(function()
            while _G.AutoFarm do
                
                -- Check pause
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
                        
                        if M1 then
                             KillEnemy("Dark Dragon User Lv.40")
                        elseif M2 then
                             KillEnemy("Gazelle User Lv.45")
                        end
                    end
                
                elseif QuestDropdown.Value == "Auto Rook&Bishop" then
                    local Status = GetRookBishopQuestStatus()
                    
                    if Status == "COMPLETED" or Status == "NONE" then
                        if _G.AutoQuest then Accept_RookBishop_Quest() end
                    elseif Status == "ACTIVE" then
                        if not _G.AutoFarm then break end
                        Summon_RookBishop() -- Go summon if not there
                        if not _G.AutoFarm then break end
                        
                        local B1 = LIVES_FOLDER:FindFirstChild("Bishop Lv.80")
                        local B2 = LIVES_FOLDER:FindFirstChild("Rook Lv.80")
                        
                        if B1 then KillEnemy("Bishop Lv.80") end
                        if B2 then KillEnemy("Rook Lv.80") end
                    end
                
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
                            -- !!! WARP FIRST LOGIC !!! --
                            if not WarpedToMine then
                                Fluent:Notify({Title = "Status", Content = "Starting... Warping to Mine first!", Duration = 3})
                                for i=1,5 do WarpTo("Mine's Field"); task.wait(0.2) end
                                task.wait(3) 
                                WarpedToMine = true
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
                        CancelMovement() -- STOP
                        Fluent:Notify({Title = "Daguba", Content = "Quest Completed! Waiting 20s...", Duration = 5})
                        
                        for i = 1, 20 do 
                            if not _G.AutoFarm then break end 
                            task.wait(1) 
                        end
                        
                        if _G.AutoFarm then Accept_Daguba_Quest() end
                        
                    elseif IsInAncientDungeon() then
                        Run_Daguba_Sequence()
                        task.wait(2)
                        
                    elseif Status == "NONE" then
                        Accept_Daguba_Quest()
                        
                    elseif Status == "ACTIVE" then
                        if not IsEnteringDungeon then
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
Fluent:Notify({Title = "Script Loaded", Content = "AUTO ROOK & BISHOP ADDED", Duration = 5})
SaveManager:LoadAutoloadConfig()
