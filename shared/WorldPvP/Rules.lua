-- World PvP rules and compact map encodings.
local Rules = {}

-- EditableImage maximum side is 1024; 2:1 world raster with four times
-- the previous map's pixel count (512x256 -> 1024x512).
Rules.MapWidth = 1024
Rules.MapHeight = 512
Rules.MaxPlayers = 55
Rules.ProtectionSeconds = 300

Rules.TickSeconds = 0.1
Rules.SnapshotSeconds = 0.30
Rules.StatsSeconds = 0.60

Rules.HumanStartingTroops = 25000
Rules.NationStartingTroops = 18000
Rules.TribeStartingTroops = 9000
Rules.HumanStartingGold = 25000
Rules.BotStartingGold = 12000
Rules.TroopRegenerationBase = 10
Rules.TroopCapPerTile = 40
Rules.GoldPerSecond = 100

-- Around a dozen pixels to start, with a noisy edge instead of a square blob.
Rules.SpawnRadius = 2
Rules.NationSpawnRadius = 2
Rules.TribeSpawnRadius = 1
Rules.DefaultAttackRatio = 0.20
Rules.MinimumAttackRatio = 0.01
Rules.MaximumAttackRatio = 1.00

Rules.TerrainCodes = {
    Water = 0,
    Plains = 1,
    Forest = 2,
    Highland = 3,
    Mountain = 4,
}
Rules.BuildingCodes = {
    City = 1,
    Factory = 2,
    Port = 3,
    DefensePost = 4,
    MissileSilo = 5,
    SAM = 6,
    Warship = 7,
}

Rules.Attack = {
    Plains = { Magnitude = 80, TileCost = 20 },
    Forest = { Magnitude = 90, TileCost = 23 },
    Highland = { Magnitude = 100, TileCost = 26 },
    Mountain = { Magnitude = 120, TileCost = 32 },
    BaseAttackerLossFactor = 0.32,
    DefenderDensityFactor = 0.0039,
    MaxTilesPerStep = 5,
    TroopsPerTileStep = 420,
    RetreatRefund = 0.75,
    MinimumCommit = 100,
}

Rules.Naval = {
    MinimumTravelSeconds = 2.5,
    SecondsPerPixel = 0.025,
    WarshipDefenseMultiplier = 1.8,
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
    },
    Port = {
        Cost = 30000,
        GoldPerSecond = 80,
        BoatSpeedMultiplier = 1.5,
        RequiresCoast = true,
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
    Warship = {
        Cost = 90000,
        RequiresCoast = true,
        DefenseMultiplier = 1.8,
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
    BuildThinkSeconds = 12,
}

Rules.Alliance = {
    Enabled = true,
    MaxPendingPerNation = 8,
}

Rules.Nuclear = {
    Enabled = true,
    Cost = 200000,
    CooldownSeconds = 90,
    Radius = 5,
    TroopLoss = 0.35,
}

Rules.Render = {
    ChunkSize = 64,
    InitialChunkRows = 8,
}

return Rules
