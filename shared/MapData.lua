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

-- Helper to get terrain type properties
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