-- World PvP rules and compact map encodings.
local Rules = {}

-- EditableImage maximum side is 1024; 2:1 world raster with four times
-- the previous map's pixel count (512x256 -> 1024x512).
Rules.MapWidth = 1024
Rules.MapHeight = 512
Rules.MaxPlayers = 55
Rules.ProtectionSeconds = 15

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
Rules.GoldPerSecond = 1000

-- Around a dozen pixels to start, with a noisy edge instead of a square blob.
Rules.SpawnRadius = 1
Rules.NationSpawnRadius = 1
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
    MaxConcurrentPerNation = 1,
}

Rules.Naval = {
    MinimumTravelSeconds = 2.5,
    SecondsPerPixel = 0.025,
    WarshipDefenseMultiplier = 1.8,
}

Rules.Buildings = {
    City = {
        Cost = 125000,
        GoldPerSecond = 100,
        TroopCapacity = 250000,
    },
    Factory = {
        Cost = 125000,
        GoldPerSecond = 400,
    },
    Port = {
        Cost = 125000,
        GoldPerSecond = 100,
        BoatSpeedMultiplier = 1.5,
        RequiresCoast = true,
    },
    DefensePost = {
        Cost = 50000,
        DefenseMultiplier = 2.5,
    },
    MissileSilo = {
        Cost = 1000000,
        MissileCost = 750000,
    },
    SAM = {
        Cost = 1500000,
        DefenseMultiplier = 1.6,
    },
    Warship = {
        Cost = 250000,
        RequiresCoast = true,
        DefenseMultiplier = 1.8,
    },
}

Rules.AI = {
    NationCount = 88,
    TribeCount = 140,
    NationThinkMin = 9,
    NationThinkMax = 16,
    TribeThinkMin = 13,
    TribeThinkMax = 22,
    NationAttackRatio = 0.02,
    TribeAttackRatio = 0.01,
    MinimumAttackTroops = 3500,
    BuildThinkSeconds = 30,
}

Rules.Alliance = {
    Enabled = true,
    MaxPendingPerNation = 8,
}

Rules.Nuclear = {
    Enabled = true,
    Weapons = {
        Atom = {Cost = 750000, CooldownSeconds = 90, Radius = 5, TroopLoss = 0.35},
        Hydrogen = {Cost = 5000000, CooldownSeconds = 120, Radius = 9, TroopLoss = 0.55},
        MIRV = {Cost = 25000000, CooldownSeconds = 180, Radius = 6, TroopLoss = 0.40, Warheads = 5},
    },
}

Rules.Render = {
    ChunkSize = 64,
    ChunksPerBurst = 4,
}

return Rules
