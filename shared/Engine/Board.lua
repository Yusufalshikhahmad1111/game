-- shared/Engine/Board.lua (ModuleScript)
local Cell = require(script.Parent.Cell)

local Board = {}
Board.__index = Board

function Board.new(gridSize, MapData)
    local self = setmetatable({}, Board)
    self.gridSize = gridSize
    self.MapData = MapData
    self.cells = {} -- 2D array [x][y]
    self:generate()
    return self
end

function Board:generate()
    -- Create empty grid
    for x = 1, self.gridSize do
        self.cells[x] = {}
        for y = 1, self.gridSize do
            self.cells[x][y] = Cell.new(x, y, "Neutral", "Neutral")
        end
    end

    -- Assign random terrain colors and resources
    for x = 1, self.gridSize do
        for y = 1, self.gridSize do
            local cell = self.cells[x][y]
            local color = self.MapData.Colors[math.random(1, #self.MapData.Colors)]
            cell.color = color

            -- Starting positions
            if x == 1 and y == 1 then
                cell.owner = "Player"
            elseif x == self.gridSize and y == self.gridSize then
                cell.owner = "AI1"
            elseif x == 1 and y == self.gridSize then
                cell.owner = "AI2"
            end

            -- Assign resources
            for _, resType in ipairs(self.MapData.ResourceTypes) do
                cell.resources[resType] = math.random(0, self.MapData.BaseResourcePerCell)
            end

            -- Compute total
            local total = 0
            for _, amount in pairs(cell.resources) do
                total = total + amount
            end
            cell.totalResources = total
        end
    end

    -- No neighbor references stored; compute on demand
end

function Board:getCell(x, y)
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize then
        return nil
    end
    return self.cells[x][y]
end

function Board:getNeighbors(cell)
    local x, y = cell.x, cell.y
    local neighbors = {}
    if x > 1 then table.insert(neighbors, self:getCell(x-1, y)) end
    if x < self.gridSize then table.insert(neighbors, self:getCell(x+1, y)) end
    if y > 1 then table.insert(neighbors, self:getCell(x, y-1)) end
    if y < self.gridSize then table.insert(neighbors, self:getCell(x, y+1)) end
    return neighbors
end

function Board:clone()
    local newBoard = Board.new(self.gridSize, self.MapData)
    for x = 1, self.gridSize do
        for y = 1, self.gridSize do
            local src = self.cells[x][y]
            local dst = newBoard.cells[x][y]
            dst.owner = src.owner
            dst.color = src.color
            dst.resources = {}
            for k, v in pairs(src.resources) do
                dst.resources[k] = v
            end
            dst.totalResources = src.totalResources
        end
    end
    return newBoard
end

function Board:serialize()
    local data = {}
    for x = 1, self.gridSize do
        for y = 1, self.gridSize do
            local c = self.cells[x][y]
            table.insert(data, {
                id = c.id,
                x = c.x,
                y = c.y,
                owner = c.owner,
                color = c.color,
                resources = c.resources,
                totalResources = c.totalResources
            })
        end
    end
    return data
end

return Board