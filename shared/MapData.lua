-- ReplicatedStorage/MapData.lua (ModuleScript)
local MapData = {}

MapData.DefaultGridSize = 10
MapData.AvailableSizes = {10, 15, 20}
MapData.Colors = {"Red", "Blue", "Green", "Yellow", "Purple", "Orange"}
MapData.PlayerTeamColor = "Blue"

-- Terrain types and their properties
MapData.TerrainTypes = {
    Plains = {
        color = "Green", -- This will be overridden by actual terrain color, but used for generation
        baseYield = {Food = 8}, -- Resources gained when captured
        productionPerTurn = {Food = 2}, -- Resources generated each turn
        strategicValue = 1,
        defenseModifier = 0, -- No defensive bonus
        isCommon = true
    },
    Forest = {
        color = "DarkGreen",
        baseYield = {Wood = 8},
        productionPerTurn = {Wood = 2},
        strategicValue = 2,
        defenseModifier = 0,
        isCommon = true
    },
    Mine = {
        color = "Gray",
        baseYield = {Gold = 10},
        productionPerTurn = {Gold = 3},
        strategicValue = 3,
        defenseModifier = 0,
        isCommon = false
    },
    Ruins = {
        color = "Brown",
        baseYield = {Relic = 1}, -- Relic is special
        productionPerTurn = {}, -- No regular production, but chance for relic?
        strategicValue = 4,
        defenseModifier = 0,
        isCommon = false
    },
    Fortress = {
        color = "Red",
        baseYield = {Gold = 5, Wood = 5},
        productionPerTurn = {Gold = 1, Wood = 1},
        strategicValue = 5,
        defenseModifier = 0.3, -- 30% defense bonus (affects future capture cost?)
        isCommon = false
    },
    Capital = {
        color = "Yellow",
        baseYield = {Gold = 15, Food = 10, Wood = 10},
        productionPerTurn = {Gold = 3, Food = 2, Wood = 2},
        strategicValue = 10,
        defenseModifier = 0.5, -- 50% defense bonus
        isCommon = false -- Only one per map
    },
    Harbor = {
        color = "Blue",
        baseYield = {Gold = 7},
        productionPerTurn = {Gold = 2},
        strategicValue = 3,
        defenseModifier = 0,
        isCommon = false
    }
}

MapData.ResourceTypes = {"Gold", "Food", "Wood", "Relic"} -- Added Relic
MapData.BaseResourcePerCell = 10 -- Kept for backward compatibility but not used directly

-- Map Themes (M7 Content)
MapData.MapThemes = {
    Classic = {
        name = "كلاسيكي",
        nameAr = "كلاسيكي",
        description = "أرض متوازنة مع تضاريس متنوعة",
        icon = "🌍",
        terrainWeights = {
            Plains = 40, Forest = 20, Mine = 10, Ruins = 5, Fortress = 8, Capital = 2, Harbor = 5
        },
        colors = {
            Plains = Color3.fromRGB(34, 139, 34),
            Forest = Color3.fromRGB(0, 100, 0),
            Mine = Color3.fromRGB(169, 169, 169),
            Ruins = Color3.fromRGB(139, 69, 19),
            Fortress = Color3.fromRGB(128, 0, 128),
            Capital = Color3.fromRGB(255, 215, 0),
            Harbor = Color3.fromRGB(0, 191, 255)
        }
    },
    AshenIsles = {
        name = "جزر الرماد",
        nameAr = "جزر الرماد",
        description = "أرض بركانية صعبة مع موارد نادرة",
        icon = "🌋",
        terrainWeights = {
            Plains = 20, Forest = 10, Mine = 25, Ruins = 15, Fortress = 15, Capital = 2, Harbor = 5
        },
        colors = {
            Plains = Color3.fromRGB(80, 60, 50),
            Forest = Color3.fromRGB(40, 40, 30),
            Mine = Color3.fromRGB(100, 80, 60),
            Ruins = Color3.fromRGB(80, 40, 30),
            Fortress = Color3.fromRGB(100, 30, 30),
            Capital = Color3.fromRGB(150, 50, 50),
            Harbor = Color3.fromRGB(50, 40, 60)
        }
    },
    EmeraldBasin = {
        name = "حوض الزمرد",
        nameAr = "حوض الزمرد",
        description = "غابات كثيفة وإنتاج غذاء عالٍ",
        icon = "🌲",
        terrainWeights = {
            Plains = 30, Forest = 40, Mine = 5, Ruins = 5, Fortress = 5, Capital = 2, Harbor = 5
        },
        colors = {
            Plains = Color3.fromRGB(60, 160, 60),
            Forest = Color3.fromRGB(0, 120, 0),
            Mine = Color3.fromRGB(140, 140, 140),
            Ruins = Color3.fromRGB(120, 80, 40),
            Fortress = Color3.fromRGB(80, 100, 80),
            Capital = Color3.fromRGB(200, 220, 100),
            Harbor = Color3.fromRGB(40, 160, 220)
        }
    },
    IronCoast = {
        name = "ساحل الحديد",
        nameAr = "ساحل الحديد",
        description = "ساحل صخري مع مناجم كثيرة وموانئ استراتيجية",
        icon = "⚓",
        terrainWeights = {
            Plains = 25, Forest = 10, Mine = 20, Ruins = 5, Fortress = 10, Capital = 2, Harbor = 20
        },
        colors = {
            Plains = Color3.fromRGB(100, 100, 80),
            Forest = Color3.fromRGB(50, 80, 50),
            Mine = Color3.fromRGB(120, 120, 120),
            Ruins = Color3.fromRGB(100, 80, 60),
            Fortress = Color3.fromRGB(100, 80, 80),
            Capital = Color3.fromRGB(180, 160, 100),
            Harbor = Color3.fromRGB(30, 120, 180)
        }
    },
    StormArchipelago = {
        name = "جزر العواصف",
        nameAr = "جزر العواصف",
        description = "جزر معزولة مع أحداث مناخية متكررة",
        icon = "🌪️",
        terrainWeights = {
            Plains = 20, Forest = 15, Mine = 15, Ruins = 10, Fortress = 10, Capital = 2, Harbor = 20
        },
        colors = {
            Plains = Color3.fromRGB(120, 120, 100),
            Forest = Color3.fromRGB(60, 80, 60),
            Mine = Color3.fromRGB(140, 140, 120),
            Ruins = Color3.fromRGB(100, 100, 80),
            Fortress = Color3.fromRGB(120, 80, 80),
            Capital = Color3.fromRGB(200, 150, 100),
            Harbor = Color3.fromRGB(40, 100, 160)
        }
    }
}

-- Get theme config
function MapData:getTheme(themeName)
    return MapData.MapThemes[themeName] or MapData.MapThemes.Classic
end

-- Get all themes
function MapData:getAllThemes()
    return MapData.MapThemes
end

-- Default theme
MapData.DefaultTheme = "Classic"

-- Helper to get terrain properties
function MapData.getTerrainProperties(terrainType)
    return MapData.TerrainTypes[terrainType] or MapData.TerrainTypes.Plains
end

function MapData.GenerateMap(gridSize)
    gridSize = gridSize or MapData.DefaultGridSize
    local grid = {}
    for x = 1, gridSize do
        grid[x] = {}
        for y = 1, gridSize do
            local owner = "Neutral"

            -- Starting positions
            if x == 1 and y == 1 then owner = "Player" end
            if x == gridSize and y == gridSize then owner = "AI1" end
            if x == 1 and y == gridSize then owner = "AI2" end

            grid[x][y] = {
                x = x,
                y = y,
                owner = owner,
                id = tostring(x) .. "," .. tostring(y),
                neighbors = {},
                -- Terrain and resources will be set in Board generation
                terrainType = "Plains", -- Default
                resources = {}, -- Current resources in stockpile
                baseYield = {}, -- One-time yield on capture
                productionPerTurn = {}, -- Per turn generation
                strategicValue = 1,
                defenseModifier = 0
            }
        end
    end

    -- Calculate neighbors for each cell (up, down, left, right)
    for x = 1, gridSize do
        for y = 1, gridSize do
            local cell = grid[x][y]
            local n = {}
            if x > 1 then table.insert(n, grid[x-1][y]) end
            if x < gridSize then table.insert(n, grid[x+1][y]) end
            if y > 1 then table.insert(n, grid[x][y-1]) end
            if y < gridSize then table.insert(n, grid[x][y+1]) end
            cell.neighbors = n
        end
    end

    return grid
end

return MapData