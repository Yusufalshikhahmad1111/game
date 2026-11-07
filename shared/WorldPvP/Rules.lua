-- shared/WorldPvP/Rules.lua
-- Independent Roblox-native rules for the World PvP pivot.
-- Values are initial balance placeholders and should be tuned after playtests.

local Rules = {}

Rules.MaxPlayers = 55
Rules.TargetWorldShare = 0.80
Rules.TickSeconds = 1
Rules.SnapshotSeconds = 0.5

Rules.StartingGold = 100000
Rules.StartingTroops = 12000
Rules.StartingPopulation = 10000
Rules.BaseGoldPerTick = 250
Rules.BaseTroopsPerTick = 90
Rules.MaxAttackDistance = 1

Rules.Buildings = {
    City = {
        Cost = 25000,
        GoldPerTick = 800,
        PopulationCapacity = 5000,
        TroopsPerTick = 40,
        RequiresCoast = false,
    },
    Port = {
        Cost = 50000,
        GoldPerTick = 500,
        PopulationCapacity = 0,
        TroopsPerTick = 0,
        RequiresCoast = true,
    },
    Factory = {
        Cost = 80000,
        GoldPerTick = 1800,
        PopulationCapacity = 0,
        TroopsPerTick = 0,
        RequiresCoast = false,
    },
    DefensePost = {
        Cost = 35000,
        GoldPerTick = 0,
        PopulationCapacity = 0,
        TroopsPerTick = 0,
        DefenseMultiplier = 1.35,
        RequiresCoast = false,
    },
    MissileSilo = {
        Cost = 150000,
        GoldPerTick = 0,
        PopulationCapacity = 0,
        TroopsPerTick = 0,
        RequiresCoast = false,
    },
    SAM = {
        Cost = 100000,
        GoldPerTick = 0,
        PopulationCapacity = 0,
        TroopsPerTick = 0,
        RequiresCoast = false,
    },
}

Rules.Attack = {
    MinimumTroops = 500,
    TravelSeconds = 3,
    WinRatio = 1.15,
    AttackerLossOnWin = 0.30,
    AttackerLossOnFail = 0.70,
}

Rules.Nuke = {
    Cost = 250000,
    CooldownSeconds = 90,
    Radius = 2,
    TroopLoss = 0.25,
}

Rules.Alliance = {
    OfferLifetimeSeconds = 60,
}

return Rules
