-- shared/WorldPvP/WorldSeed.lua
-- Original stylized world silhouette and fictional nation roster.
-- Not copied from RoWorld/OpenFront map or private game data.
-- Replace/upgrade with a licensed geographic dataset in a later map milestone.

local WorldMap = require(script.Parent.WorldMap)

local Seed = {}

local NATION_NAMES = {
    "Aurelia","Borealis","Caledon","Dravik","Eldoria","Faron","Gallia","Helios",
    "Iberon","Jorvik","Kastor","Lunaria","Meridia","Norland","Orion","Pannonia",
    "Qadira","Rivermark","Solaria","Tartessia","Utopia","Valoria","Westreach","Xandria",
    "Yamato","Zephyria","Arkania","Belvar","Cyrenia","Doria","Estara","Freya",
    "Gondara","Haven","Illyria","Jutland","Korinth","Lydria","Montara","Navara",
    "Ostria","Pelagos","Rhenia","Sylvania","Taurica","Umbra","Vesper","Westeros",
    "Yalara","Zoravia","Altair","Bravura","Caspia","Demeria","Erevia","Fjordia",
    "Galvorn","Halcyra","Iskand","Jadewind","Kharos","Lumeria","Mystral","Nerath",
    "Ostara","Pyrrhos","Quillon","Ravaryn","Sorelia","Thalor","Umbria","Varent",
    "Wyrmholt","Xerath","Yvenna","Zafira","Asteron","Brightfall","Corvane","Duskholm",
    "Evermere","Frostmark","Goldhaven","Highmoor","Ironvale","Jade Coast","Kingsreach","Stormhold",
}

local COLORS = {
    {0.86,0.25,0.22},{0.22,0.48,0.88},{0.20,0.68,0.40},{0.93,0.62,0.18},
    {0.64,0.34,0.84},{0.13,0.70,0.76},{0.90,0.36,0.57},{0.48,0.59,0.24},
    {0.20,0.72,0.62},{0.82,0.47,0.19},{0.38,0.53,0.75},
}

local CONTINENTS = {
    -- North America
    {
        {0.035,0.20},{0.075,0.10},{0.16,0.06},{0.25,0.09},{0.34,0.13},
        {0.40,0.22},{0.36,0.30},{0.32,0.37},{0.28,0.46},{0.23,0.51},
        {0.19,0.43},{0.15,0.38},{0.10,0.36},{0.06,0.29},
    },
    -- Greenland
    {
        {0.34,0.04},{0.42,0.05},{0.46,0.13},{0.42,0.20},{0.36,0.17},
    },
    -- South America
    {
        {0.25,0.49},{0.32,0.47},{0.39,0.53},{0.42,0.62},{0.40,0.72},
        {0.37,0.82},{0.34,0.96},{0.29,0.88},{0.27,0.76},{0.25,0.62},
    },
    -- Europe
    {
        {0.45,0.20},{0.51,0.16},{0.58,0.18},{0.63,0.24},{0.61,0.32},
        {0.55,0.37},{0.49,0.34},{0.45,0.28},
    },
    -- Africa
    {
        {0.47,0.36},{0.56,0.34},{0.64,0.40},{0.67,0.49},{0.63,0.64},
        {0.59,0.78},{0.54,0.84},{0.50,0.75},{0.47,0.59},{0.45,0.46},
    },
    -- Asia
    {
        {0.59,0.09},{0.69,0.06},{0.82,0.08},{0.94,0.13},{0.99,0.22},
        {0.96,0.33},{0.91,0.40},{0.84,0.45},{0.77,0.43},{0.70,0.38},
        {0.65,0.34},{0.61,0.27},{0.57,0.19},
    },
    -- Arabian peninsula
    {
        {0.61,0.42},{0.69,0.41},{0.74,0.49},{0.70,0.58},{0.65,0.56},{0.61,0.49},
    },
    -- India
    {
        {0.71,0.43},{0.77,0.45},{0.78,0.55},{0.74,0.66},{0.70,0.57},
    },
    -- South-East Asia
    {
        {0.78,0.49},{0.86,0.49},{0.92,0.57},{0.90,0.66},{0.84,0.68},{0.79,0.60},
    },
    -- Japan / island arc
    {
        {0.94,0.37},{0.97,0.39},{0.97,0.47},{0.94,0.49},{0.92,0.43},
    },
    -- Australia
    {
        {0.80,0.77},{0.87,0.73},{0.95,0.78},{0.98,0.87},{0.94,0.95},{0.85,0.94},{0.79,0.87},
    },
    -- Madagascar
    {
        {0.64,0.72},{0.66,0.74},{0.65,0.84},{0.63,0.82},
    },
    -- British / Indonesian island specks
    {
        {0.50,0.30},{0.52,0.31},{0.515,0.35},{0.495,0.34},
    },
}

local function pointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]
        local intersects = ((yi > y) ~= (yj > y))
            and (x < (xj - xi) * (y - yi) / ((yj - yi) + 1e-9) + xi)
        if intersects then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function buildRows(width, height)
    local rows = {}
    for y = 1, height do
        local chars = {}
        for x = 1, width do
            local nx = (x - 0.5) / width
            local ny = (y - 0.5) / height
            local land = false

            for _, polygon in ipairs(CONTINENTS) do
                if pointInPolygon(nx, ny, polygon) then
                    land = true
                    break
                end
            end

            chars[x] = land and "#" or "."
        end
        rows[y] = table.concat(chars)
    end
    return rows
end

local function farthestUnused(landCells, used, usedCells, iteration)
    local bestCell = nil
    local bestScore = -math.huge

    for _, cell in ipairs(landCells) do
        if not used[cell.id] then
            local nearest = math.huge
            for _, other in ipairs(usedCells) do
                local distance = math.abs(cell.x - other.x) + math.abs(cell.y - other.y)
                if distance < nearest then
                    nearest = distance
                end
            end

            local score
            if nearest == math.huge then
                score = -math.abs(cell.x - 28) - math.abs(cell.y - 14)
            else
                score = nearest
            end
            score += math.sin(iteration * 13 + cell.x * 7 + cell.y * 3) * 0.01

            if score > bestScore then
                bestScore = score
                bestCell = cell
            end
        end
    end

    if bestCell then
        used[bestCell.id] = true
        usedCells[#usedCells + 1] = bestCell
    end
    return bestCell
end

function Seed.create()
    local map = WorldMap.fromRows(buildRows(56, 28))
    local landCells = {}
    for _, cell in ipairs(map.cells) do
        if cell.isLand then
            landCells[#landCells + 1] = cell
        end
    end

    assert(#landCells >= #NATION_NAMES, "world map does not contain enough land for nation spawns")

    local used = {}
    local usedCells = {}
    local entities = {}

    for index, name in ipairs(NATION_NAMES) do
        local seed = farthestUnused(landCells, used, usedCells, index)
        assert(seed, "failed to allocate a unique nation spawn")
        local color = COLORS[((index - 1) % #COLORS) + 1]
        entities[#entities + 1] = {
            id = "N" .. index,
            name = name,
            category = "Nation",
            cellId = seed.id,
            color = { r = color[1], g = color[2], b = color[3] },
        }
    end

    local tribeCount = math.min(100, #landCells - #NATION_NAMES)
    for index = 1, tribeCount do
        local seed = farthestUnused(landCells, used, usedCells, index + #NATION_NAMES)
        if not seed then
            break
        end

        local shade = 0.34 + (index % 5) * 0.045
        entities[#entities + 1] = {
            id = "T" .. index,
            name = "Tribe " .. string.format("%03d", index),
            category = "Tribe",
            cellId = seed.id,
            color = { r = shade, g = shade * 0.82, b = shade * 0.54 },
        }
    end

    return map, entities
end

return Seed
