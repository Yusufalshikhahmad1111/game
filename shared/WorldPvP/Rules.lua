-- shared/WorldPvP/Rules.lua
-- Original Roblox-native World PvP balance. Tune after server load tests.

local Rules = {}

Rules.MaxPlayers = 55
Rules.TargetWorldShare = 0.80
Rules.TickSeconds = 1
Rules.SnapshotSeconds = 2

Rules.StartingGold = 100000
Rules.StartingTroops = 12000
Rules.StartingPopulation = 10000
Rules.TribeStartingGold = 18000
Rules.TribeStartingTroops = 2800
Rules.TribeStartingPopulation = 1200

Rules.BaseGoldPerTick = 250
Rules.BaseTroopsPerTick = 90
Rules.BasePopulationPerTick = 50

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
        DefenseMultiplier = 1.65,
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
        DefenseMultiplier = 1.0,
        RequiresCoast = false,
    },
}

Rules.Attack = {
    MinimumTroops = 500,
    TravelSeconds = 3,
    NavalTravelSeconds = 8,
    NavalGoldCost = 2500,
    WinRatio = 1.15,
    AttackerLossOnWin = 0.30,
    AttackerLossOnFail = 0.70,
    NeutralDefense = 200,
    DefenderTroopFactor = 0.04,
}

Rules.Nuke = {
    Cost = 250000,
    CooldownSeconds = 90,
    Radius = 2,
    TroopLoss = 0.25,
    SAMInterceptionRadius = 1,
}

Rules.Alliance = {
    OfferLifetimeSeconds = 60,
}

Rules.AI = {
    ThinkMinSeconds = 4,
    ThinkMaxSeconds = 8,
    AttackReserveRatio = 0.35,
    MinimumAttackTroops = 700,
    CityReserveGold = 30000,
    FactoryReserveGold = 90000,
    DefenseReserveGold = 50000,
    PortReserveGold = 60000,
    NuclearReserveGold = 300000,
}

return Rules
