-- shared/WorldPvP/WorldMap.lua
-- Converts an authored land/water raster into deterministic cells and neighbors.
-- The production world map must come from a properly licensed geographic dataset.

local WorldMap = {}

local DIRECTIONS = {
    { 1, 0 },
    { -1, 0 },
    { 0, 1 },
    { 0, -1 },
}

local function cellId(x, y)
    return string.format("%02d_%02d", y, x)
end

function WorldMap.fromRows(rows)
    assert(type(rows) == "table" and #rows > 0, "rows must be a non-empty array")

    local height = #rows
    local width = #rows[1]
    assert(width > 0, "map rows cannot be empty")

    local cells = {}
    local cellsById = {}
    local totalLand = 0

    for y, row in ipairs(rows) do
        assert(type(row) == "string" and #row == width, "all map rows must have equal width")
        for x = 1, width do
            local symbol = row:sub(x, x)
            local isLand = symbol == "#" or symbol == "L"
            local id = cellId(x, y)

            local cell = {
                id = id,
                x = x,
                y = y,
                isLand = isLand,
                isCoastal = false,
                ownerId = nil,
                building = nil,
                neighbors = {},
            }

            if isLand then
                totalLand += 1
            end

            cells[#cells + 1] = cell
            cellsById[id] = cell
        end
    end

    for _, cell in ipairs(cells) do
        local touchesWater = false

        for _, direction in ipairs(DIRECTIONS) do
            local nx = cell.x + direction[1]
            local ny = cell.y + direction[2]

            if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
                local neighbor = cellsById[cellId(nx, ny)]
                if neighbor.isLand then
                    cell.neighbors[#cell.neighbors + 1] = neighbor.id
                else
                    touchesWater = true
                end
            else
                touchesWater = true
            end
        end

        cell.isCoastal = cell.isLand and touchesWater
    end

    return {
        width = width,
        height = height,
        cells = cells,
        cellsById = cellsById,
        totalLand = totalLand,
    }
end

function WorldMap.countLand(map)
    return map and map.totalLand or 0
end

return WorldMap
