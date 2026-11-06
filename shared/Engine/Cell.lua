-- shared/Engine/Cell.lua (ModuleScript)
local Cell = {}
Cell.__index = Cell

function Cell.new(x, y, color, owner)
    local self = setmetatable({}, Cell)
    self.x = x
    self.y = y
    self.id = tostring(x) .. "," .. tostring(y)
    self.color = color          -- terrain color (string)
    self.owner = owner          -- "Player", "AI1", "AI2", "Neutral"
    self.resources = {}         -- e.g., {Gold = 5, Food = 3, Wood = 2}
    self.totalResources = 0
    return self
end

function Cell:clone()
    local clone = Cell.new(self.x, self.y, self.color, self.owner)
    clone.resources = {}
    for k, v in pairs(self.resources) do
        clone.resources[k] = v
    end
    clone.totalResources = self.totalResources
    return clone
end

return Cell