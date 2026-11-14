-- ========================================
-- DEVIL HUB - Egg Breaker & Animal Stealer
-- Complete Auto Farm System
-- PlaceId: 114326934417838
-- ========================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- ZONE DATA (จาก ZonesConfig.lua dump)
-- ========================================
local ZONE_DATA = {
    {Id = "Zone1", Name = "Zone 1 - Common", Guard = "Chicken", Rarity = "Common", RequiredPower = 5},
    {Id = "Zone2", Name = "Zone 2 - Uncommon", Guard = "SPHINX", Rarity = "Uncommon", RequiredPower = 1000},
    {Id = "Zone3", Name = "Zone 3 - Rare", Guard = "IceYeti", Rarity = "Rare", RequiredPower = 50000},
    {Id = "Zone4", Name = "Zone 4 - Epic", Guard = "EmeraldSerpent", Rarity = "Epic", RequiredPower = 750000},
    {Id = "Zone5", Name = "Zone 5 - Legendary", Guard = "WoollyMammoth", Rarity = "Legendary", RequiredPower = 12000000},
    {Id = "Zone6", Name = "Zone 6 - Mythic", Guard = "RedshellCrab", Rarity = "Mythic", RequiredPower = 150000000},
    {Id = "Zone7", Name = "Zone 7 - Divine", Guard = "MoleTitan", Rarity = "Divine", RequiredPower = 1000000000},
    {Id = "Zone8", Name = "Zone 8 - Cosmic", Guard = "Griffin", Rarity = "Cosmic", RequiredPower = 5000000000},
    {Id = "Zone9", Name = "Zone 9 - Secret", Guard = "3Hydra", Rarity = "Secret", RequiredPower = 25000000000},
    {Id = "Zone10", Name = "Zone 10 - Celestial", Guard = "AlienGuardian", Rarity = "Celestial", RequiredPower = 100000000000},
    {Id = "Zone11", Name = "Zone 11 - Inferno", Guard = "SkeletonDragon", Rarity = "Inferno", RequiredPower = 200000000000},
    {Id = "Zone12", Name = "Zone 12 - Void", Guard = "ZoneBoss", Rarity = "Void", RequiredPower = 750000000000},
    {Id = "Zone13", Name = "Zone 13 - Omega", Guard = "LionTitanBoss", Rarity = "Omega", RequiredPower = 1500000000000},
}

-- ========================================
-- EGG DATA (จาก EggConfig.lua dump)
-- ========================================
local EGG_LIST = {
    "Basic Egg", "Forest Egg", "Rock Egg", "Swamp Egg", "Cactus Egg", "Bones Egg", "Scorpion Egg",
    "Frozen Egg", "Frosty Egg", "Yeti Egg", "Rainbow Egg", "Easter Bunny Egg", "Candy Egg",
    "Gooey Egg", "Tree Egg", "Lake Egg", "Sea Stones Egg", "Sea Egg", "Water Egg",
    "Angel Egg", "Fallen Angel Egg", "Volcanic Egg", "Bamboo Egg", "Blossom Egg", "Fortune Egg",
    "Starry Egg", "Sun Egg", "BlackHole Egg", "Plasma Egg", "Nebula Egg", "Supernova Egg",
    "Skull Egg", "LockedEgg", "Phantom Egg", "LunaEgg", "FairyEgg", "PhoenixEgg",
    "CrystalEgg", "RoyalDragonEgg", "Castle Egg", "Cracked Egg", "Lion Egg"
}

local RARITY_LIST = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
    "Divine", "Cosmic", "Secret", "Celestial", "Inferno", "Void", "Omega"
}

-- ========================================
-- REMOTES (จาก RemoteDump)
-- ========================================
local Remotes = {
    EggHitRequest = ReplicatedStorage:WaitForChild("EggHitRequest", 5),
    PlaceAnimalRemote = ReplicatedStorage:WaitForChild("PlaceAnimalRemote", 5),
    AnimalBankedRemote = ReplicatedStorage:WaitForChild("AnimalBankedRemote", 5),
    RideRemote = ReplicatedStorage:WaitForChild("RideRemote", 5),
    BackpackSellRemote = ReplicatedStorage:WaitForChild("BackpackSellRemote", 5),
}

-- ========================================
-- STATE MANAGEMENT
-- ========================================
local State = {
    EggBreaking = {
        Active = false,
        SelectedZone = "Zone1",
        SelectedEggs = {},
        Status = "Ready",
        EggsHit = 0,
    },
    AnimalStealing = {
        Active = false,
        Mode = "All", -- "All" or "ByRarity"
        SelectedRarities = {},
        Status = "Ready",
        AnimalsStolen = 0,
        CurrentTarget = nil,
        Phase = "Idle", -- "Idle", "Approach", "Steal", "Return"
    },
}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================
local Utils = {}

function Utils.GetCharacter()
    return LocalPlayer.Character
end

function Utils.GetHumanoidRootPart()
    local char = Utils.GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Utils.TeleportTo(position, offset)
    local hrp = Utils.GetHumanoidRootPart()
    if not hrp then return false end

    offset = offset or Vector3.new(0, 5, 0)
    hrp.CFrame = CFrame.new(position + offset)
    return true
end

function Utils.FindZoneFolder(zoneId)
    local build = Workspace:FindFirstChild("Build")
    if not build then return nil end

    local zoneBuilds = build:FindFirstChild("ZoneBuilds")
    if not zoneBuilds then return nil end

    return zoneBuilds:FindFirstChild(zoneId)
end

function Utils.FindEggsInZone(zoneId)
    local zoneFolder = Utils.FindZoneFolder(zoneId)
    if not zoneFolder then return {} end

    local eggsFolder = zoneFolder:FindFirstChild("Eggs")
    if not eggsFolder then return {} end

    local eggs = {}
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        if egg:IsA("Model") and egg:FindFirstChild("Egg") then
            table.insert(eggs, egg)
        end
    end

    return eggs
end

function Utils.FindAnimals()
    local animals = {}
    local animalPickups = Workspace:FindFirstChild("AnimalPickups")

    if animalPickups then
        for _, animal in ipairs(animalPickups:GetChildren()) do
            if animal:IsA("Model") and animal:FindFirstChild("HumanoidRootPart") then
                table.insert(animals, animal)
            end
        end
    end

    return animals
end

function Utils.GetAnimalInfo(animalModel)
    local info = {
        model = animalModel,
        name = animalModel.Name,
        rarity = "Unknown",
        variant = "Normal",
        mutation = "",
        position = nil,
        income = 0,
    }

    -- อ่านข้อมูลจาก Overhead BillboardGui
    local hrp = animalModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        info.position = hrp.Position

        local overhead = hrp:FindFirstChild("AnimalOverhead")
        if overhead and overhead:IsA("BillboardGui") then
            -- อ่าน rarity
            local rarityFrame = overhead:FindFirstChild("Rarity")
            if rarityFrame then
                local rarityLabel = rarityFrame:FindFirstChild("RarityLabel")
                if rarityLabel and rarityLabel:IsA("TextLabel") then
                    info.rarity = rarityLabel.Text or "Unknown"
                end
            end

            -- อ่าน income
            local cashFrame = overhead:FindFirstChild("CashPerSecond")
            if cashFrame then
                local cashLabel = cashFrame:FindFirstChild("CashPerSecond")
                if cashLabel and cashLabel:IsA("TextLabel") then
                    info.income = cashLabel.Text or "$0/s"
                end
            end

            -- อ่าน mutation
            local mutationLabel = overhead:FindFirstChild("Mutation")
            if mutationLabel and mutationLabel:IsA("TextLabel") and mutationLabel.Visible then
                info.mutation = mutationLabel.Text or ""
            end
        end
    end

    return info
end

function Utils.FilterAnimalsByRarity(animals, rarities)
    if #rarities == 0 then return animals end

    local filtered = {}
    for _, animal in ipairs(animals) do
        local info = Utils.GetAnimalInfo(animal)
        for _, rarity in ipairs(rarities) do
            if info.rarity == rarity then
                table.insert(filtered, animal)
                break
            end
        end
    end

    return filtered
end

-- ========================================
-- EGG BREAKER MODULE
-- ========================================
local EggBreaker = {}

function EggBreaker.Start(zoneId, selectedEggs)
    if State.EggBreaking.Active then
        return false, "Already breaking eggs"
    end

    State.EggBreaking.Active = true
    State.EggBreaking.SelectedZone = zoneId
    State.EggBreaking.SelectedEggs = selectedEggs or {}
    State.EggBreaking.Status = "Starting..."
    State.EggBreaking.EggsHit = 0

    task.spawn(EggBreaker.Loop)
    return true, "Started egg breaking"
end

function EggBreaker.Stop()
    State.EggBreaking.Active = false
    State.EggBreaking.Status = "Stopped"
end

function EggBreaker.Loop()
    while State.EggBreaking.Active do
        local eggs = Utils.FindEggsInZone(State.EggBreaking.SelectedZone)

        if #eggs == 0 then
            State.EggBreaking.Status = "No eggs found in zone"
            task.wait(2)
        else
            -- Filter eggs based on selection
            local targetEggs = {}
            if #State.EggBreaking.SelectedEggs > 0 then
                for _, egg in ipairs(eggs) do
                    local eggName = egg.Name
                    for _, selected in ipairs(State.EggBreaking.SelectedEggs) do
                        if eggName:find(selected) then
                            table.insert(targetEggs, egg)
                            break
                        end
                    end
                end
            else
                targetEggs = eggs
            end

            if #targetEggs > 0 then
                for _, egg in ipairs(targetEggs) do
                    if not State.EggBreaking.Active then break end

                    local eggPart = egg:FindFirstChild("Egg")
                    if eggPart then
                        -- Teleport to egg
                        Utils.TeleportTo(eggPart.Position, Vector3.new(0, 3, 0))
                        task.wait(0.1)

                        -- Hit egg
                        State.EggBreaking.Status = "Breaking " .. egg.Name

                        if Remotes.EggHitRequest then
                            Remotes.EggHitRequest:FireServer(eggPart)
                            State.EggBreaking.EggsHit = State.EggBreaking.EggsHit + 1
                        end

                        task.wait(0.15)
                    end
                end
            else
                State.EggBreaking.Status = "No matching eggs"
                task.wait(2)
            end
        end

        task.wait(0.5)
    end
end

-- ========================================
-- ANIMAL STEALER MODULE
-- ========================================
local AnimalStealer = {}

function AnimalStealer.Start(mode, selectedRarities)
    if State.AnimalStealing.Active then
        return false, "Already stealing animals"
    end

    State.AnimalStealing.Active = true
    State.AnimalStealing.Mode = mode or "All"
    State.AnimalStealing.SelectedRarities = selectedRarities or {}
    State.AnimalStealing.Status = "Starting..."
    State.AnimalStealing.AnimalsStolen = 0
    State.AnimalStealing.Phase = "Idle"

    task.spawn(AnimalStealer.Loop)
    return true, "Started animal stealing"
end

function AnimalStealer.Stop()
    State.AnimalStealing.Active = false
    State.AnimalStealing.Status = "Stopped"
    State.AnimalStealing.Phase = "Idle"
    State.AnimalStealing.CurrentTarget = nil
end

function AnimalStealer.StealOne(animalModel)
    if not State.AnimalStealing.Active then return false end

    State.AnimalStealing.CurrentTarget = animalModel.Name
    local animalHRP = animalModel:FindFirstChild("HumanoidRootPart")

    if not animalHRP then
        State.AnimalStealing.Status = "Invalid animal model"
        return false
    end

    local playerHRP = Utils.GetHumanoidRootPart()
    if not playerHRP then
        State.AnimalStealing.Status = "Player not found"
        return false
    end

    -- Save spawn position
    local spawnPosition = playerHRP.Position

    -- Phase 1: Approach animal
    State.AnimalStealing.Phase = "Approach"
    State.AnimalStealing.Status = "Approaching " .. animalModel.Name
    Utils.TeleportTo(animalHRP.Position, Vector3.new(0, 3, 0))
    task.wait(0.2)

    -- Phase 2: Steal animal
    State.AnimalStealing.Phase = "Steal"
    State.AnimalStealing.Status = "Stealing " .. animalModel.Name

    if Remotes.PlaceAnimalRemote then
        Remotes.PlaceAnimalRemote:FireServer(animalModel)
        task.wait(0.3)
    end

    -- Phase 3: Return to spawn
    State.AnimalStealing.Phase = "Return"
    State.AnimalStealing.Status = "Returning home"
    Utils.TeleportTo(spawnPosition, Vector3.new(0, 0, 0))
    task.wait(0.2)

    -- Phase 4: Bank animal
    State.AnimalStealing.Status = "Banking animal"
    if Remotes.AnimalBankedRemote then
        Remotes.AnimalBankedRemote:FireServer()
        task.wait(0.2)
    end

    State.AnimalStealing.AnimalsStolen = State.AnimalStealing.AnimalsStolen + 1
    State.AnimalStealing.Phase = "Idle"

    return true
end

function AnimalStealer.Loop()
    while State.AnimalStealing.Active do
        local animals = Utils.FindAnimals()

        if #animals == 0 then
            State.AnimalStealing.Status = "No animals found"
            State.AnimalStealing.Phase = "Idle"
            task.wait(2)
        else
            -- Filter by rarity if mode is ByRarity
            local targetAnimals = animals
            if State.AnimalStealing.Mode == "ByRarity" and #State.AnimalStealing.SelectedRarities > 0 then
                targetAnimals = Utils.FilterAnimalsByRarity(animals, State.AnimalStealing.SelectedRarities)
            end

            if #targetAnimals > 0 then
                -- Sort by distance
                local playerPos = Utils.GetHumanoidRootPart()
                if playerPos then
                    table.sort(targetAnimals, function(a, b)
                        local aPart = a:FindFirstChild("HumanoidRootPart")
                        local bPart = b:FindFirstChild("HumanoidRootPart")
                        if not aPart then return false end
                        if not bPart then return true end
                        return (aPart.Position - playerPos.Position).Magnitude <
                               (bPart.Position - playerPos.Position).Magnitude
                    end)
                end

                -- Steal closest animal
                local success = AnimalStealer.StealOne(targetAnimals[1])

                if success then
                    task.wait(0.5)
                else
                    task.wait(1)
                end
            else
                State.AnimalStealing.Status = "No matching animals"
                State.AnimalStealing.Phase = "Idle"
                task.wait(2)
            end
        end

        task.wait(0.3)
    end
end

-- ========================================
-- GUI INTEGRATION
-- ========================================
local GUI = {}

function GUI.Initialize()
    -- โหลด Devil Hub GUI
    local DevilHubGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/DevilHub/GUI/main/devil-blue-gui.lua"))()

    if not DevilHubGui then
        warn("Failed to load Devil Hub GUI")
        return
    end

    -- สร้าง Main Window
    local Window = DevilHubGui:CreateWindow({
        Title = "DEVIL HUB - Auto Farm",
        Theme = "Blue",
        Size = UDim2.fromOffset(550, 650),
        Draggable = true,
    })

    -- ========================================
    -- TAB: EGG BREAKER
    -- ========================================
    local EggTab = Window:CreateTab({
        Name = "Egg Breaker",
        Icon = "rbxassetid://84488003116697",
    })

    local EggSection = EggTab:CreateSection("Egg Breaking System")

    -- Zone Selector
    local zoneOptions = {}
    for _, zone in ipairs(ZONE_DATA) do
        table.insert(zoneOptions, zone.Name)
    end

    local selectedZone = "Zone1"
    EggSection:CreateDropdown({
        Name = "Select Zone",
        Options = zoneOptions,
        Default = ZONE_DATA[1].Name,
        Callback = function(option)
            for _, zone in ipairs(ZONE_DATA) do
                if zone.Name == option then
                    selectedZone = zone.Id
                    break
                end
            end
        end,
    })

    -- Egg Selector (Multi-select via checklist)
    local selectedEggs = {}
    local eggCheckSection = EggTab:CreateSection("Select Eggs to Break")

    for _, eggName in ipairs(EGG_LIST) do
        eggCheckSection:CreateToggle({
            Name = eggName,
            Default = false,
            Callback = function(enabled)
                if enabled then
                    if not table.find(selectedEggs, eggName) then
                        table.insert(selectedEggs, eggName)
                    end
                else
                    local index = table.find(selectedEggs, eggName)
                    if index then
                        table.remove(selectedEggs, index)
                    end
                end
            end,
        })
    end

    -- Status Label
    local eggStatusLabel = EggSection:CreateLabel("Status: Ready")

    -- Toggle Auto Break
    EggSection:CreateToggle({
        Name = "Auto Break Eggs",
        Default = false,
        Callback = function(enabled)
            if enabled then
                local success, message = EggBreaker.Start(selectedZone, selectedEggs)
                eggStatusLabel:UpdateText(message)
            else
                EggBreaker.Stop()
                eggStatusLabel:UpdateText("Stopped")
            end
        end,
    })

    -- Stats Display
    local eggStatsLabel = EggSection:CreateLabel("Eggs Hit: 0")

    -- Update stats every second
    task.spawn(function()
        while true do
            eggStatusLabel:UpdateText("Status: " .. State.EggBreaking.Status)
            eggStatsLabel:UpdateText("Eggs Hit: " .. tostring(State.EggBreaking.EggsHit))
            task.wait(1)
        end
    end)

    -- ========================================
    -- TAB: ANIMAL STEALER
    -- ========================================
    local AnimalTab = Window:CreateTab({
        Name = "Animal Stealer",
        Icon = "rbxassetid://95024755729764",
    })

    local StealSection = AnimalTab:CreateSection("Animal Stealing System")

    -- Mode Selector
    local stealMode = "All"
    StealSection:CreateDropdown({
        Name = "Steal Mode",
        Options = {"All Animals", "By Rarity"},
        Default = "All Animals",
        Callback = function(option)
            stealMode = (option == "All Animals") and "All" or "ByRarity"
        end,
    })

    -- Rarity Selector
    local selectedRarities = {}
    local raritySection = AnimalTab:CreateSection("Select Rarities (For By Rarity Mode)")

    for _, rarity in ipairs(RARITY_LIST) do
        raritySection:CreateToggle({
            Name = rarity,
            Default = false,
            Callback = function(enabled)
                if enabled then
                    if not table.find(selectedRarities, rarity) then
                        table.insert(selectedRarities, rarity)
                    end
                else
                    local index = table.find(selectedRarities, rarity)
                    if index then
                        table.remove(selectedRarities, index)
                    end
                end
            end,
        })
    end

    -- Status Label
    local stealStatusLabel = StealSection:CreateLabel("Status: Ready")

    -- Toggle Auto Steal
    StealSection:CreateToggle({
        Name = "Auto Steal Animals",
        Default = false,
        Callback = function(enabled)
            if enabled then
                local success, message = AnimalStealer.Start(stealMode, selectedRarities)
                stealStatusLabel:UpdateText(message)
            else
                AnimalStealer.Stop()
                stealStatusLabel:UpdateText("Stopped")
            end
        end,
    })

    -- Stats Display
    local stealStatsLabel = StealSection:CreateLabel("Animals Stolen: 0")
    local stealPhaseLabel = StealSection:CreateLabel("Phase: Idle")

    -- Update stats every second
    task.spawn(function()
        while true do
            stealStatusLabel:UpdateText("Status: " .. State.AnimalStealing.Status)
            stealStatsLabel:UpdateText("Animals Stolen: " .. tostring(State.AnimalStealing.AnimalsStolen))
            stealPhaseLabel:UpdateText("Phase: " .. State.AnimalStealing.Phase)
            task.wait(1)
        end
    end)

    -- ========================================
    -- TAB: SETTINGS
    -- ========================================
    local SettingsTab = Window:CreateTab({
        Name = "Settings",
        Icon = "rbxassetid://10734949856",
    })

    local SettingsSection = SettingsTab:CreateSection("System Information")

    SettingsSection:CreateLabel("Game: Pet Collection Simulator")
    SettingsSection:CreateLabel("PlaceId: 114326934417838")
    SettingsSection:CreateLabel("Version: 1.0.0")
    SettingsSection:CreateLabel("Author: DEVIL HUB")

    local remoteSection = SettingsTab:CreateSection("Remote Status")

    -- Check remotes status
    local function checkRemotes()
        local status = {}
        status.EggHitRequest = Remotes.EggHitRequest ~= nil
        status.PlaceAnimalRemote = Remotes.PlaceAnimalRemote ~= nil
        status.AnimalBankedRemote = Remotes.AnimalBankedRemote ~= nil
        return status
    end

    local remoteStatus = checkRemotes()
    for name, exists in pairs(remoteStatus) do
        local statusText = exists and "✓ Connected" or "✗ Not Found"
        remoteSection:CreateLabel(name .. ": " .. statusText)
    end

    -- Destroy GUI Button
    SettingsSection:CreateButton({
        Name = "Destroy GUI",
        Callback = function()
            Window:Destroy()
        end,
    })

    return Window
end

-- ========================================
-- INITIALIZE
-- ========================================
local function Main()
    -- Wait for game to load
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end

    -- Wait for character
    LocalPlayer.CharacterAdded:Wait()
    task.wait(2)

    -- Validate remotes
    local missingRemotes = {}
    for name, remote in pairs(Remotes) do
        if not remote then
            table.insert(missingRemotes, name)
        end
    end

    if #missingRemotes > 0 then
        warn("Missing remotes: " .. table.concat(missingRemotes, ", "))
        warn("Some features may not work properly")
    end

    -- Initialize GUI
    local success, err = pcall(GUI.Initialize)
    if not success then
        warn("Failed to initialize GUI: " .. tostring(err))
    end
end

-- Run
Main()

return {
    EggBreaker = EggBreaker,
    AnimalStealer = AnimalStealer,
    Utils = Utils,
    State = State,
}
