-- shared/WorldPvP/WorldSeed.lua
-- Original stylized world seed. Replace with a properly licensed geographic
-- dataset in W1; this is intentionally not copied from RoWorld/OpenFront.

local WorldMap = require(script.Parent.WorldMap)

local Seed = {}

local NATION_NAMES = {
    "Aurelia","Borealis","Caledon","Dravik","Eldoria","Faron","Gallia",
    "Helios","Iberon","Jorvik","Kastor","Lunaria","Meridia","Norland",
    "Orion","Pannonia","Qadira","Rivermark","Solaria","Tartessia",
    "Utopia","Valoria","Westreach","Xandria","Yamato","Zephyria",
    "Arkania","Belvar","Cyrenia","Doria","Estara","Freya","Gondara",
    "Haven","Illyria","Jutland","Korinth","Lydria","Montara","Navara",
    "Ostria","Pelagos","Rhenia","Sylvania","Taurica","Umbra","Vesper",
    "Westeros","Yalara","Zoravia","Altair","Bravura","Caspia","Demeria",
    "Erevia","Fjordia",
}

local COLORS = {
    {0.85,0.20,0.20},{0.20,0.45,0.90},{0.20,0.70,0.40},{0.90,0.60,0.15},
    {0.65,0.30,0.85},{0.10,0.70,0.75},{0.95,0.35,0.55},{0.45,0.55,0.20},
}

local function buildRows(width, height)
    local rows = {}
    for y = 1, height do
        local row = {}
        for x = 1, width do
            local nx = x / width
            local ny = y / height
            local land = false

            local continents = {
                {0.18,0.38,0.22,0.32},
                {0.48,0.34,0.27,0.24},
                {0.78,0.35,0.18,0.28},
                {0.35,0.72,0.18,0.16},
                {0.67,0.72,0.23,0.14},
            }

            for _, c in ipairs(continents) do
                local dx = (nx - c[1]) / c[3]
                local dy = (ny - c[2]) / c[4]
                if dx * dx + dy * dy <= 1 then
                    land = true
                    break
                end
            end

            row[x] = land and "#" or "."
        end
        rows[y] = table.concat(row)
    end
    return rows
end

function Seed.create()
    local rows = buildRows(40, 20)
    local map = WorldMap.fromRows(rows)

    local landCells = {}
    for _, cell in ipairs(map.cells) do
        if cell.isLand then
            landCells[#landCells + 1] = cell
        end
    end

    local seeds = {}
    local minDistance = 3

    for index, name in ipairs(NATION_NAMES) do
        local best = nil
        local bestScore = -math.huge

        for _, cell in ipairs(landCells) do
            local valid = true
            local nearest = math.huge
            for _, used in ipairs(seeds) do
                local d = math.abs(cell.x - used.x) + math.abs(cell.y - used.y)
                nearest = math.min(nearest, d)
                if d < minDistance then
                    valid = false
                    break
                end
            end

            if valid then
                local score = nearest + math.sin(index * 17 + cell.x * 3 + cell.y) * 0.25
                if score > bestScore then
                    bestScore = score
                    best = cell
                end
            end
        end

        if not best then
            best = landCells[((index - 1) % #landCells) + 1]
        end

        seeds[#seeds + 1] = best
    end

    return map, NATION_NAMES, seeds, COLORS
end

return Seed
