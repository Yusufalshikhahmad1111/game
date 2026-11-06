-- shared/Engine/TurnManager.lua (ModuleScript)
local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new(turnOrder)
    local self = setmetatable({}, TurnManager)
    self.turnOrder = turnOrder
    self.currentTurnIndex = 1
    return self
end

function TurnManager:getCurrentTeam()
    return self.turnOrder[self.currentTurnIndex]
end

function TurnManager:advance()
    self.currentTurnIndex = self.currentTurnIndex % #self.turnOrder + 1
end

function TurnManager:clone()
    local clone = TurnManager.new(self.turnOrder)
    clone.currentTurnIndex = self.currentTurnIndex
    return clone
end

return TurnManager