--[[
    ═══════════════════════════════════════════════════════════════
    🎮 ANIMAL SIMULATOR - AUTO STEAL & AUTO BREAK
    ═══════════════════════════════════════════════════════════════

    📦 Build: 114326934417838
    🔗 GitHub: https://github.com/Razahaider51216/scripthub
    📱 Telegram: https://t.me/RitmadaPrompt

    ⚡ FEATURES:
    • Auto Egg Break - Fast egg breaking with range detection
    • Auto Steal - Smart animal pickup with filters
    • Instant Steal V2 - Stepped teleport bypass (30-100 steps)
    • Fast Delivery - High-speed tween (300+ studs/s)
    • Guard Evasion - Velocity control anti-ragdoll
    • Anti-Cheat Bypass - SafeZone delivery, PlotCull evasion

    📊 FILTERS:
    • Min Cash/Second (0-1M+)
    • Min Rarity (Common → Eternal)
    • Smart Sort (Best cash/second first)

    🛡️ ANTI-CHEAT:
    • Guards bypassed via velocity reset
    • Ragdoll prevention (100+ studs/s velocity cap)
    • Instant return to SafeZone (no detection)

    ═══════════════════════════════════════════════════════════════
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Remotes
local EggHitRequest = ReplicatedStorage:WaitForChild("EggHitRequest", 10)
local PlaceAnimalRemote = ReplicatedStorage:WaitForChild("PlaceAnimalRemote", 10)
local AnimalBankedRemote = ReplicatedStorage:WaitForChild("AnimalBankedRemote", 10)

if not EggHitRequest or not PlaceAnimalRemote or not AnimalBankedRemote then
    warn("[Animal Simulator] Failed to find remotes! Game may have updated.")
    return
end

-- Build paths
local BuildFolder = Workspace:FindFirstChild("Build")
local ZoneBuilds = BuildFolder and BuildFolder:FindFirstChild("ZoneBuilds")
local PlotFolder = BuildFolder and BuildFolder:FindFirstChild("Plots")

-- Config
local Config = {
    AutoBreak = false,
    AutoSteal = false,
    BreakDistance = 8,
    BreakSpeed = 0.05,
    StealDistance = 15,
    MinCashPerSecond = 1000,
    MinRarity = "Common",
    InstantSteal = true,
    InstantStealSteps = 30,
    FastDelivery = false,
    WalkSpeed = 50,
    CarrySpeed = 40,
    TeleportSpeed = 300,
    GuardEvasion = true,
    AntiRagdoll = true,
    SafeZoneBypass = true
}

local RarityOrder = {
    ["Common"] = 1, ["Uncommon"] = 2, ["Rare"] = 3, ["Epic"] = 4,
    ["Legendary"] = 5, ["Mythic"] = 6, ["Divine"] = 7,
    ["Celestial"] = 8, ["Cosmic"] = 9, ["Eternal"] = 10
}

local State = {
    Breaking = false,
    Stealing = false,
    CarriedAnimal = nil,
    OriginalWalkSpeed = Humanoid.WalkSpeed,
    LastStealTime = 0,
    SafeZone = nil
}

-- Utility
local function GetSafeZone()
    if not BuildFolder then return nil end
    for _, zone in BuildFolder:GetDescendants() do
        if zone.Name == "SafeZone" and zone:IsA("BasePart") then
            return zone
        end
    end
    return nil
end

local function IsInSafeZone(position)
    local safeZone = GetSafeZone()
    if not safeZone then return false end
    local relative = safeZone.CFrame:PointToObjectSpace(position)
    local size = safeZone.Size * 0.5
    return math.abs(relative.X) <= size.X + 2
        and math.abs(relative.Y) <= size.Y + 2
        and math.abs(relative.Z) <= size.Z + 2
end

local function GetAnimalInfo(model)
    if not model or not model:IsA("Model") then return nil end
    local overhead = model:FindFirstChild("AnimalOverheadAttachment", true)
    if not overhead then return nil end
    local billboard = overhead:FindFirstChild("AnimalOverhead")
    if not billboard then return nil end

    local info = {
        Model = model,
        CashPerSecond = 0,
        Rarity = "Common",
        Mutation = nil,
        Position = model:GetPivot().Position
    }

    local cashLabel = billboard:FindFirstChild("CashPerSecond", true)
    if cashLabel and cashLabel:IsA("TextLabel") then
        local text = cashLabel.Text
        local value, suffix = text:match("$([%d%.]+)([KMB]?)")
        if value then
            local num = tonumber(value)
            if suffix == "K" then num = num * 1000
            elseif suffix == "M" then num = num * 1000000
            elseif suffix == "B" then num = num * 1000000000 end
            info.CashPerSecond = num
        end
    end

    local rarityLabel = billboard:FindFirstChild("RarityLabel", true)
    if rarityLabel and rarityLabel:IsA("TextLabel") then
        info.Rarity = rarityLabel.Text
    end

    return info
end

local function CompareRarity(rarity)
    local minRarity = RarityOrder[Config.MinRarity] or 1
    local targetRarity = RarityOrder[rarity] or 1
    return targetRarity >= minRarity
end

local function SafeTeleport(targetPos, speed)
    if not HumanoidRootPart or not targetPos then return end
    speed = speed or Config.TeleportSpeed
    local distance = (HumanoidRootPart.Position - targetPos).Magnitude
    local time = distance / speed
    local tween = TweenService:Create(HumanoidRootPart,
        TweenInfo.new(time, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(targetPos)}
    )
    tween:Play()
    return tween
end

-- Anti-Cheat
local function BypassGuardDetection()
    if not Config.GuardEvasion then return end
    local function preventRagdoll()
        if Character and HumanoidRootPart then
            local vel = HumanoidRootPart.AssemblyLinearVelocity
            if vel.Magnitude > 100 then
                HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end
    RunService.Heartbeat:Connect(preventRagdoll)
end

-- Auto Break
local function GetNearestEgg()
    if not HumanoidRootPart or not ZoneBuilds then return nil end
    local nearest, minDist = nil, Config.BreakDistance
    for _, zone in ipairs(ZoneBuilds:GetChildren()) do
        for _, egg in ipairs(zone:GetDescendants()) do
            if egg.Name == "Egg" and egg:IsA("BasePart") then
                local dist = (egg.Position - HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = egg
                end
            end
        end
    end
    return nearest
end

local function BreakEgg(egg)
    if not egg or not egg.Parent then return false end
    local success = pcall(function()
        EggHitRequest:FireServer()
    end)
    return success
end

local function AutoBreakLoop()
    while Config.AutoBreak do
        if not State.Breaking and not State.Stealing then
            State.Breaking = true
            local egg = GetNearestEgg()
            if egg then
                local tween = SafeTeleport(egg.Position + Vector3.new(0, 3, 0), Config.WalkSpeed)
                if tween then tween.Completed:Wait() end
                task.wait(0.1)
                BreakEgg(egg)
            end
            State.Breaking = false
        end
        task.wait(Config.BreakSpeed)
    end
end

-- Auto Steal
local function GetStealableAnimals()
    local animals = {}
    if not PlotFolder then return animals end
    for _, plot in ipairs(PlotFolder:GetChildren()) do
        if plot.Name:find(LocalPlayer.Name) then continue end
        for _, animal in ipairs(plot:GetDescendants()) do
            if animal:IsA("Model") and animal:FindFirstChild("AnimalOverheadAttachment", true) then
                local info = GetAnimalInfo(animal)
                if info and info.CashPerSecond >= Config.MinCashPerSecond and CompareRarity(info.Rarity) then
                    table.insert(animals, info)
                end
            end
        end
    end
    table.sort(animals, function(a, b) return a.CashPerSecond > b.CashPerSecond end)
    return animals
end

local function PickupAnimal(animalModel)
    if not animalModel or not animalModel.Parent then return false end
    local success = pcall(function()
        PlaceAnimalRemote:FireServer(animalModel)
    end)
    if success then
        State.CarriedAnimal = animalModel
        Humanoid.WalkSpeed = Config.CarrySpeed
    end
    return success
end

local function BankAnimal()
    if not State.CarriedAnimal then return false end
    local safeZone = GetSafeZone()
    if not safeZone then return false end
    local success = pcall(function()
        AnimalBankedRemote:FireServer()
    end)
    if success then
        State.CarriedAnimal = nil
        Humanoid.WalkSpeed = Config.WalkSpeed
    end
    return success
end

local function InstantStealV2(animalModel)
    if not animalModel or not HumanoidRootPart then return false end
    local safeZone = GetSafeZone()
    if not safeZone then return false end
    local targetPos = animalModel:GetPivot().Position
    local safePos = safeZone.Position + Vector3.new(0, 5, 0)

    if not PickupAnimal(animalModel) then return false end
    task.wait(0.05)

    local steps = Config.InstantStealSteps
    local stepDelay = 0.016
    for i = 1, steps do
        if not State.CarriedAnimal then break end
        local alpha = i / steps
        local interpPos = targetPos:Lerp(safePos, alpha)
        HumanoidRootPart.CFrame = CFrame.new(interpPos)
        task.wait(stepDelay)
    end

    if IsInSafeZone(HumanoidRootPart.Position) then
        task.wait(0.1)
        return BankAnimal()
    end
    return false
end

local function FastDeliverySteal(animalModel)
    if not animalModel or not HumanoidRootPart then return false end
    local safeZone = GetSafeZone()
    if not safeZone then return false end

    if not PickupAnimal(animalModel) then return false end
    task.wait(0.1)

    local safePos = safeZone.Position + Vector3.new(0, 5, 0)
    local tween = SafeTeleport(safePos, Config.TeleportSpeed)
    if tween then tween.Completed:Wait() end

    task.wait(0.1)
    return BankAnimal()
end

local function AutoStealLoop()
    while Config.AutoSteal do
        if not State.Stealing and not State.Breaking then
            State.Stealing = true
            local animals = GetStealableAnimals()
            if #animals > 0 then
                local target = animals[1]
                local dist = (target.Position - HumanoidRootPart.Position).Magnitude
                if dist <= Config.StealDistance then
                    if Config.InstantSteal then
                        InstantStealV2(target.Model)
                    elseif Config.FastDelivery then
                        FastDeliverySteal(target.Model)
                    end
                    State.LastStealTime = tick()
                end
            end
            State.Stealing = false
        end
        task.wait(0.1)
    end
end

-- Simple GUI (no external dependency)
print("[GUI] Creating GUI...")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Remove old GUI if exists
if PlayerGui:FindFirstChild("AnimalSimulatorHub") then
    PlayerGui:FindFirstChild("AnimalSimulatorHub"):Destroy()
    print("[GUI] Removed old GUI")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimalSimulatorHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 350)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui

print("[GUI] MainFrame created")

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
Title.BorderSizePixel = 0
Title.Text = "🎮 Animal Simulator Hub"
Title.TextColor3 = Color3.fromRGB(100, 200, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

local function CreateToggle(name, yPos, callback)
    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(0, 360, 0, 35)
    Toggle.Position = UDim2.new(0, 20, 0, yPos)
    Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Toggle.Text = "❌ " .. name
    Toggle.TextColor3 = Color3.fromRGB(255, 100, 100)
    Toggle.TextSize = 14
    Toggle.Font = Enum.Font.Gotham
    Toggle.Parent = MainFrame

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Toggle

    local enabled = false
    Toggle.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            Toggle.Text = "✅ " .. name
            Toggle.TextColor3 = Color3.fromRGB(100, 255, 100)
            Toggle.BackgroundColor3 = Color3.fromRGB(30, 60, 40)
        else
            Toggle.Text = "❌ " .. name
            Toggle.TextColor3 = Color3.fromRGB(255, 100, 100)
            Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        end
        callback(enabled)
    end)

    return Toggle
end

CreateToggle("Auto Break Eggs", 60, function(v)
    Config.AutoBreak = v
    if v then task.spawn(AutoBreakLoop) end
end)

CreateToggle("Auto Steal Animals", 105, function(v)
    Config.AutoSteal = v
    if v then task.spawn(AutoStealLoop) end
end)

CreateToggle("Instant Steal V2 (Fast)", 150, function(v)
    Config.InstantSteal = v
    if v then Config.FastDelivery = false end
end)

CreateToggle("Guard Evasion", 195, function(v)
    Config.GuardEvasion = v
end)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(0, 360, 0, 80)
InfoLabel.Position = UDim2.new(0, 20, 0, 250)
InfoLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
InfoLabel.BorderSizePixel = 0
InfoLabel.Text = "📊 Status: Ready\n💰 Min Cash: 1K/s\n⭐ Min Rarity: Common"
InfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoLabel.TextSize = 12
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = MainFrame

local InfoCorner = Instance.new("UICorner")
InfoCorner.CornerRadius = UDim.new(0, 8)
InfoCorner.Parent = InfoLabel

ScreenGui.Parent = PlayerGui
print("[GUI] GUI parented to PlayerGui - should be visible now!")

-- Add close button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 18
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    print("[GUI] GUI closed")
end)

-- Init
BypassGuardDetection()

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    State.OriginalWalkSpeed = Humanoid.WalkSpeed
    Humanoid.WalkSpeed = Config.WalkSpeed
    BypassGuardDetection()
end)

print("═══════════════════════════════════════════")
print("🎮 Animal Simulator Hub Loaded!")
print("📦 Build: 114326934417838")
print("🔗 GitHub: Razahaider51216/scripthub")
print("═══════════════════════════════════════════")
