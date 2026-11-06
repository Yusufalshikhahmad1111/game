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

    -- First, assign terrain types strategically
    self:assignTerrainTypes()
    
    -- Then, set colors, owners, and resources based on terrain
    self:applyTerrainProperties()
    
    -- Set starting positions (override terrain for start points)
    self:setStartingPositions()
end

function Board:assignTerrainTypes()
    local gridSize = self.gridSize
    
    -- We'll create a simple strategic placement:
    -- Some clusters of same terrain
    -- Fortresses near edges or in clusters
    -- Mines in certain areas
    -- Only one Capital
    -- etc.

    -- For now, use weighted random with some strategy
    -- In future, we can make this more sophisticated
    
    local capitalPlaced = false
    
    for x = 1, gridSize do
        for y = 1, gridSize do
            -- Skip if this will be a starting position (we'll override later)
            local isStartPos = 
                (x == 1 and y == 1) or 
                (x == gridSize and y == gridSize) or 
                (x == 1 and y == gridSize)
            
            if not isStartPos then
                local terrainType = self:chooseTerrainType(x, y, gridSize, capitalPlaced)
                if terrainType == "Capital" then
                    capitalPlaced = true
                end
                self.cells[x][y]:setTerrainType(terrainType)
            end
        end
    end
end

function Board:chooseTerrainType(x, y, gridSize, capitalPlaced)
    -- Simple strategy: 
    - Avoid placing too many rares in corners
    - Create some clusters
    - Place capital somewhere central-ish
    
    local rand = math.random()
    
    -- Capital: only one, prefer center
    if not capitalPlaced and x > gridSize*0.3 and x < gridSize*0.7 and y > gridSize*0.3 and y < gridSize*0.7 then
        if rand < 0.02 then -- 2% chance in center area
            return "Capital"
        end
    end
    
    -- Fortress: place near edges or in defensive positions
    local edgeWeight = 0
    if x <= 2 or x >= gridSize-1 or y <= 2 or y >= gridSize-1 then
        edgeWeight = 0.3
    end
    
    -- Mine: prefer not too crowded
    -- Ruins: rare
    
    local terrainRoll = rand
    
    if terrainRoll < 0.01 then -- 1%
        return "Capital"
    elseif terrainRoll < 0.01 + 0.05 then -- 5% total for Fortress
        return "Fortress"
    elseif terrainRoll < 0.06 + 0.08 then -- 8% for Mine
        return "Mine"
    elseif terrainRoll < 0.14 + 0.06 then -- 6% for Ruins
        return "Ruins"
    elseif terrainRoll < 0.20 + 0.10 then -- 10% for Harbor
        return "Harbor"
    elseif terrainRoll < 0.30 + 0.20 then -- 20% for Forest
        return "Forest"
    else -- Remaining 50% for Plains
        return "Plains"
    end
end

function Board:applyTerrainProperties()
    for x = 1, self.gridSize do
        for y = 1, self.gridSize do
            local cell = self.cells[x][y]
            local terrainType = cell.terrainType
            local props = self.MapData.getTerrainProperties(terrainType)
            
            -- Set color based on terrain (can be overridden by owner later for display)
            cell.color = props.color
            
            -- Set base yield and production
            cell.baseYield = {}
            for resType, amount in pairs(props.baseYield) do
                cell.baseYield[resType] = amount
            end
            
            cell.productionPerTurn = {}
            for resType, amount in pairs(props.productionPerTurn) do
                cell.productionPerTurn[resType] = amount
            end
            
            cell.strategicValue = props.strategicValue
            cell.defenseModifier = props.defenseModifier
            
            -- Initialize resources (stockpile) to zero
            cell.resources = {}
            for _, resType in ipairs(self.MapData.ResourceTypes) do
                cell.resources[resType] = 0
            end
        end
    end
end

function Board:setStartingPositions()
    -- Override terrain for starting positions but keep strategic value etc?
    -- Actually, starting positions should have special terrain? Or just keep what was assigned?
    -- For simplicity, keep the terrain but set owner
    
    local startPositions = {
        {1, 1, "Player"},
        {self.gridSize, self.gridSize, "AI1"},
        {1, self.gridSize, "AI2"}
    }
    
    for _, pos in ipairs(startPositions) do
        local x, y, owner = pos[1], pos[2], pos[3]
        if x >= 1 and x <= self.gridSize and y >= 1 and y <= self.gridSize then
            local cell = self.cells[x][y]
            cell.owner = owner
            -- Note: we keep the terrain type, color, etc. from assignment
            -- The displayed color will be based on owner in the client
        end
    end
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
            -- Copy all relevant properties
            dst.owner = src.owner
            dst.terrainType = src.terrainType
            dst.color = src.color
            dst.baseYield = {}
            for k, v in pairs(src.baseYield) do
                dst.baseYield[k] = v
            end
            dst.productionPerTurn = {}
            for k, v in pairs(src.productionPerTurn) do
                dst.productionPerTurn[k] = v
            end
            dst.strategicValue = src.strategicValue
            dst.defenseModifier = src.defenseModifier
            dst.resources = {}
            for k, v in pairs(src.resources) do
                dst.resources[k] = v
            end
            dst.id = src.id
            dst.x = src.x
            dst.y = src.y
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
                terrainType = c.terrainType,
                color = c.color,
                baseYield = c.baseYield,
                productionPerTurn = c.productionPerTurn,
                strategicValue = c.strategicValue,
                defenseModifier = c.defenseModifier,
                resources = c.resources
            })
        end
    end
    return data
end

return Board