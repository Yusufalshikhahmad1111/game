-- shared/WorldPvP/Rules.lua
-- Independent Luau rules for a real-time tile-conquest World PvP game.
-- Core interaction model researched from OpenFront/RoWorld: spawn on free land,
-- attack the target owner by sending a troop fraction, expand along the frontier,
-- and launch transport attacks across water.

local Rules = {}

Rules.MapWidth = 256
Rules.MapHeight = 128
Rules.MaxPlayers = 55
Rules.TickSeconds = 0.1
Rules.SnapshotSeconds = 0.3
Rules.StatsSeconds = 0.8

Rules.HumanStartingTroops = 25000
Rules.NationStartingTroops = 18000
Rules.TribeStartingTroops = 10000
Rules.HumanStartingGold = 25000
Rules.BotStartingGold = 12000

Rules.SpawnRadius = 3
Rules.NationSpawnRadius = 2
Rules.TribeSpawnRadius = 1
Rules.DefaultAttackRatio = 0.20
Rules.MinimumAttackRatio = 0.01
Rules.MaximumAttackRatio = 1.00

Rules.TroopRegenerationBase = 10
Rules.GoldPerSecond = 100
Rules.BoatSecondsPerTile = 0.25
Rules.BoatMaxActive = 3
Rules.BoatGoldCost = 0

Rules.Attack = {
    -- OpenFront-style terrain pressure / tile speed values.
    Plains = { Magnitude = 80, TileCost = 16.5 },
    Forest = { Magnitude = 90, TileCost = 18 },
    Highland = { Magnitude = 100, TileCost = 20 },
    Mountain = { Magnitude = 120, TileCost = 25 },
    NeutralCostScale = 2000,
    NeutralMinCost = 5,
    NeutralMaxCost = 100,
    DefenderLossPerTile = 1,
    HumanTroopLossModifier = 1,
    DefenderDensityFactor = 0.0039,
    BaseAttackerLossFactor = 0.463,
    CheapestRatio = 0.6,
    SpeedRatioFloor = 0.82,
    SpeedRatioCeiling = 7.5,
    SpeedCostDivisor = 8.55,
    RetreatLossAgainstPlayers = 0.25,
    RetreatLossAgainstNeutral = 0,
}

Rules.Buildings = {
    City = {
        Cost = 25000,
        GoldPerSecond = 150,
        TroopCapacity = 250000,
    },
    Factory = {
        Cost = 40000,
        GoldPerSecond = 450,
        TroopCapacity = 0,
    },
    Port = {
        Cost = 30000,
        GoldPerSecond = 80,
        TroopCapacity = 0,
        BoatSpeedMultiplier = 1.5,
    },
    DefensePost = {
        Cost = 35000,
        DefenseMultiplier = 2.5,
    },
    MissileSilo = {
        Cost = 150000,
        MissileCost = 200000,
    },
    SAM = {
        Cost = 80000,
        DefenseMultiplier = 1.6,
    },
}

Rules.AI = {
    NationCount = 88,
    TribeCount = 140,
    NationThinkMin = 2.5,
    NationThinkMax = 5,
    TribeThinkMin = 5,
    TribeThinkMax = 10,
    NationAttackRatio = 0.06,
    TribeAttackRatio = 0.035,
    MinimumAttackTroops = 500,
    ExpansionNeutralFirst = true,
}

Rules.Nuclear = {
    Enabled = true,
    Cost = 200000,
    CooldownSeconds = 90,
    Radius = 3,
    TroopLoss = 0.35,
}

return Rules
