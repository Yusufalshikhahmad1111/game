-- shared/Engine/Cell.lua (ModuleScript)
local Cell = {}
Cell.__index = Cell

function Cell.new(x, y, color, owner)
    local self = setmetatable({}, Cell)
    self.x = x
    self.y = y
    self.id = tostring(x) .. "," .. tostring(y)
    self.color = color          -- base terrain color (will be overridden by owner color in display)
    self.owner = owner          -- "Player", "AI1", "AI2", "Neutral"
    self.terrainType = "Plains" -- Type of terrain
    
    -- Resource properties
    self.baseYield = {}         -- Resources gained when captured (one-time)
    self.productionPerTurn = {} -- Resources generated each turn
    self.resources = {}         -- Current stockpile/resources available
    
    -- Strategic properties
    self.strategicValue = 1     -- How valuable this territory is strategically
    self.defenseModifier = 0    -- Defensive bonus (0-1, reduces capture cost?)
    
    return self
end

function Cell:setTerrainType(terrainType)
    self.terrainType = terrainType
    -- Note: actual properties like baseYield etc. are set elsewhere when applying terrain
    -- This method is just for tracking the type
end

function Cell:clone()
    local clone = Cell.new(self.x, self.y, self.color, self.owner)
    clone.terrainType = self.terrainType
    
    -- Clone resource tables
    clone.baseYield = {}
    for k, v in pairs(self.baseYield) do
        clone.baseYield[k] = v
    end
    
    clone.productionPerTurn = {}
    for k, v in pairs(self.productionPerTurn) do
        clone.productionPerTurn[k] = v
    end
    
    clone.resources = {}
    for k, v in pairs(self.resources) do
        clone.resources[k] = v
    end
    
    clone.strategicValue = self.strategicValue
    clone.defenseModifier = self.defenseModifier
    
    return clone
end

return Cell