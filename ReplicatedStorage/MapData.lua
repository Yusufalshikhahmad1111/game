-- ReplicatedStorage/MapData.lua (ModuleScript)
local MapData = {}

MapData.DefaultGridSize = 10
MapData.AvailableSizes = {10, 15, 20}
MapData.Colors = {"Red", "Blue", "Green", "Yellow", "Purple", "Orange"}
MapData.PlayerTeamColor = "Blue"

-- Resource types
MapData.ResourceTypes = {"Gold", "Food", "Wood"}
MapData.BaseResourcePerCell = 10   -- base resources per cell when captured

function MapData.GenerateMap(gridSize)
    gridSize = gridSize or MapData.DefaultGridSize
    local grid = {}
    for x = 1, gridSize do
        grid[x] = {}
        for y = 1, gridSize do
            local color = MapData.Colors[math.random(1, #MapData.Colors)]
            local owner = "Neutral"

            -- Starting positions
            if x == 1 and y == 1 then owner = "Player" end
            if x == gridSize and y == gridSize then owner = "AI1" end
            if x == 1 and y == gridSize then owner = "AI2" end

            -- Assign random resources to each cell
            local resources = {}
            for _, resType in ipairs(MapData.ResourceTypes) do
                resources[resType] = math.random(0, MapData.BaseResourcePerCell)
            end

            grid[x][y] = {
                x = x,
                y = y,
                color = color,
                owner = owner,
                id = tostring(x) .. "," .. tostring(y),
                neighbors = {},
                resources = resources,
                totalResources = 0
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

    -- Pre-calculate total resources per cell (sum of all types)
    for x = 1, gridSize do
        for y = 1, gridSize do
            local cell = grid[x][y]
            local total = 0
            for _, amount in pairs(cell.resources) do
                total = total + amount
            end
            cell.totalResources = total
        end
    end

    return grid
end

return MapData