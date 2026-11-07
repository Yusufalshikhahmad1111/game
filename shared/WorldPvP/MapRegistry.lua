-- Data-driven geographic map registry for WorldDominion.
-- All geometry uses public-domain Natural Earth country polygons.
local Registry = {
    Default = "World",
    Maps = {
        World = {
            id = "World",
            title = "WORLD",
            description = "Global territory conquest",
            bounds = { west = -180, north = 85, east = 180, south = -60 },
            wrapX = true,
            maxPlayers = 55,
            victoryShare = 0.80,
        },
        Europe = {
            id = "Europe",
            title = "EUROPE",
            description = "A dense continental front",
            bounds = { west = -15, north = 72, east = 45, south = 30 },
            wrapX = false,
            maxPlayers = 40,
            victoryShare = 0.80,
        },
        Asia = {
            id = "Asia",
            title = "ASIA",
            description = "A vast continental theatre",
            bounds = { west = 25, north = 82, east = 180, south = -12 },
            wrapX = false,
            maxPlayers = 55,
            victoryShare = 0.80,
        },
        MENA = {
            id = "MENA",
            title = "MIDDLE EAST",
            description = "Mediterranean, Levant and Gulf",
            bounds = { west = -20, north = 48, east = 68, south = 5 },
            wrapX = false,
            maxPlayers = 40,
            victoryShare = 0.80,
        },
    },
}

function Registry.get(mapId)
    return Registry.Maps[tostring(mapId or Registry.Default)]
end

function Registry.list()
    local result = {}
    for _, map in pairs(Registry.Maps) do
        result[#result + 1] = map
    end
    table.sort(result, function(a, b)
        return a.id < b.id
    end)
    return result
end

return Registry
