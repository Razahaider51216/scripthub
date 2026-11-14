-- ========================================
-- DEVIL HUB - Auto Farm Core Module
-- Egg Breaker & Animal Stealer (WORKING VERSION)
-- PlaceId: 114326934417838
-- ========================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ========================================
-- CONFIGURATION
-- ========================================
local Config = {
    ZONE_DATA = {
        {Id = "Zone1", Name = "Zone 1 - Common", Rarity = "Common"},
        {Id = "Zone2", Name = "Zone 2 - Uncommon", Rarity = "Uncommon"},
        {Id = "Zone3", Name = "Zone 3 - Rare", Rarity = "Rare"},
        {Id = "Zone4", Name = "Zone 4 - Epic", Rarity = "Epic"},
        {Id = "Zone5", Name = "Zone 5 - Legendary", Rarity = "Legendary"},
        {Id = "Zone6", Name = "Zone 6 - Mythic", Rarity = "Mythic"},
        {Id = "Zone7", Name = "Zone 7 - Divine", Rarity = "Divine"},
        {Id = "Zone8", Name = "Zone 8 - Cosmic", Rarity = "Cosmic"},
        {Id = "Zone9", Name = "Zone 9 - Secret", Rarity = "Secret"},
        {Id = "Zone10", Name = "Zone 10 - Celestial", Rarity = "Celestial"},
        {Id = "Zone11", Name = "Zone 11 - Inferno", Rarity = "Inferno"},
        {Id = "Zone12", Name = "Zone 12 - Void", Rarity = "Void"},
        {Id = "Zone13", Name = "Zone 13 - Omega", Rarity = "Omega"},
    },

    EGG_LIST = {
        "Basic Egg", "Forest Egg", "Rock Egg", "Swamp Egg", "Cactus Egg", "Bones Egg",
        "Scorpion Egg", "Frozen Egg", "Frosty Egg", "Yeti Egg", "Rainbow Egg",
        "Easter Bunny Egg", "Candy Egg", "Gooey Egg", "Tree Egg", "Lake Egg",
        "Sea Stones Egg", "Sea Egg", "Water Egg", "Angel Egg", "Fallen Angel Egg",
        "Volcanic Egg", "Bamboo Egg", "Blossom Egg", "Fortune Egg", "Starry Egg",
        "Sun Egg", "BlackHole Egg", "Plasma Egg", "Nebula Egg", "Supernova Egg",
        "Skull Egg", "LockedEgg", "Phantom Egg", "LunaEgg", "FairyEgg", "PhoenixEgg",
        "CrystalEgg", "RoyalDragonEgg", "Castle Egg", "Cracked Egg", "Lion Egg"
    },

    RARITY_LIST = {
        "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
        "Divine", "Cosmic", "Secret", "Celestial", "Inferno", "Void", "Omega"
    },
}

-- ========================================
-- REMOTES
-- ========================================
local Remotes = {
    EggHitRequest = ReplicatedStorage:WaitForChild("EggHitRequest", 5),
    PlaceAnimalRemote = ReplicatedStorage:WaitForChild("PlaceAnimalRemote", 5),
    AnimalBankedRemote = ReplicatedStorage:WaitForChild("AnimalBankedRemote", 5),
    BackpackSellRemote = ReplicatedStorage:WaitForChild("BackpackSellRemote", 5),
}

-- ========================================
-- STATE
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
        Mode = "All",
        SelectedRarities = {},
        Status = "Ready",
        AnimalsStolen = 0,
        CurrentTarget = nil,
        Phase = "Idle",
    },
}

-- ========================================
-- UTILITIES
-- ========================================
local Utils = {}

function Utils.GetHumanoidRootPart()
    local char = LocalPlayer.Character
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
        position = nil,
    }

    local hrp = animalModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        info.position = hrp.Position
        local overhead = hrp:FindFirstChild("AnimalOverhead")
        if overhead and overhead:IsA("BillboardGui") then
            local rarityFrame = overhead:FindFirstChild("Rarity")
            if rarityFrame then
                local rarityLabel = rarityFrame:FindFirstChild("RarityLabel")
                if rarityLabel and rarityLabel:IsA("TextLabel") then
                    info.rarity = rarityLabel.Text or "Unknown"
                end
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
-- EGG BREAKER
-- ========================================
local EggBreaker = {}

function EggBreaker.Start(zoneId, selectedEggs)
    if State.EggBreaking.Active then
        return false, "Already running"
    end

    State.EggBreaking.Active = true
    State.EggBreaking.SelectedZone = zoneId
    State.EggBreaking.SelectedEggs = selectedEggs or {}
    State.EggBreaking.Status = "Starting..."
    State.EggBreaking.EggsHit = 0

    task.spawn(EggBreaker.Loop)
    return true, "Started"
end

function EggBreaker.Stop()
    State.EggBreaking.Active = false
    State.EggBreaking.Status = "Stopped"
end

function EggBreaker.Loop()
    while State.EggBreaking.Active do
        local eggs = Utils.FindEggsInZone(State.EggBreaking.SelectedZone)

        if #eggs == 0 then
            State.EggBreaking.Status = "No eggs in zone"
            task.wait(2)
        else
            local targetEggs = {}
            if #State.EggBreaking.SelectedEggs > 0 then
                for _, egg in ipairs(eggs) do
                    for _, selected in ipairs(State.EggBreaking.SelectedEggs) do
                        if egg.Name:find(selected) then
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
                        Utils.TeleportTo(eggPart.Position, Vector3.new(0, 3, 0))
                        task.wait(0.1)

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
-- ANIMAL STEALER
-- ========================================
local AnimalStealer = {}

function AnimalStealer.Start(mode, selectedRarities)
    if State.AnimalStealing.Active then
        return false, "Already running"
    end

    State.AnimalStealing.Active = true
    State.AnimalStealing.Mode = mode or "All"
    State.AnimalStealing.SelectedRarities = selectedRarities or {}
    State.AnimalStealing.Status = "Starting..."
    State.AnimalStealing.AnimalsStolen = 0
    State.AnimalStealing.Phase = "Idle"

    task.spawn(AnimalStealer.Loop)
    return true, "Started"
end

function AnimalStealer.Stop()
    State.AnimalStealing.Active = false
    State.AnimalStealing.Status = "Stopped"
    State.AnimalStealing.Phase = "Idle"
end

function AnimalStealer.StealOne(animalModel)
    if not State.AnimalStealing.Active then return false end

    State.AnimalStealing.CurrentTarget = animalModel.Name
    local animalHRP = animalModel:FindFirstChild("HumanoidRootPart")
    if not animalHRP then return false end

    local playerHRP = Utils.GetHumanoidRootPart()
    if not playerHRP then return false end

    local spawnPosition = playerHRP.Position

    -- Approach
    State.AnimalStealing.Phase = "Approach"
    Utils.TeleportTo(animalHRP.Position, Vector3.new(0, 3, 0))
    task.wait(0.2)

    -- Steal
    State.AnimalStealing.Phase = "Steal"
    if Remotes.PlaceAnimalRemote then
        Remotes.PlaceAnimalRemote:FireServer(animalModel)
        task.wait(0.3)
    end

    -- Return
    State.AnimalStealing.Phase = "Return"
    Utils.TeleportTo(spawnPosition, Vector3.new(0, 0, 0))
    task.wait(0.2)

    -- Bank
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
            task.wait(2)
        else
            local targetAnimals = animals
            if State.AnimalStealing.Mode == "ByRarity" and #State.AnimalStealing.SelectedRarities > 0 then
                targetAnimals = Utils.FilterAnimalsByRarity(animals, State.AnimalStealing.SelectedRarities)
            end

            if #targetAnimals > 0 then
                local success = AnimalStealer.StealOne(targetAnimals[1])
                task.wait(success and 0.5 or 1)
            else
                State.AnimalStealing.Status = "No matching animals"
                task.wait(2)
            end
        end

        task.wait(0.3)
    end
end

-- ========================================
-- API EXPORT
-- ========================================
local API = {
    EggBreaker = EggBreaker,
    AnimalStealer = AnimalStealer,
    Utils = Utils,
    State = State,
    Config = Config,
    Remotes = Remotes,
}

function API.GetStatus()
    return {
        EggBreaking = {
            Active = State.EggBreaking.Active,
            Zone = State.EggBreaking.SelectedZone,
            Status = State.EggBreaking.Status,
            EggsHit = State.EggBreaking.EggsHit,
        },
        AnimalStealing = {
            Active = State.AnimalStealing.Active,
            Status = State.AnimalStealing.Status,
            AnimalsStolen = State.AnimalStealing.AnimalsStolen,
            Phase = State.AnimalStealing.Phase,
        },
    }
end

function API.StopAll()
    EggBreaker.Stop()
    AnimalStealer.Stop()
end

-- ========================================
-- INIT & TEST
-- ========================================
print("====================================")
print("DEVIL HUB - Auto Farm Module")
print("PlaceId: 114326934417838")
print("====================================")
print("\nRemote Status:")
for name, remote in pairs(Remotes) do
    print("  " .. name .. ": " .. (remote and "✓" or "✗"))
end
print("\nAPI Ready. Usage:")
print('  API.EggBreaker.Start("Zone1", {})')
print('  API.AnimalStealer.Start("All", {})')
print('  API.StopAll()')
print("====================================\n")

return API
