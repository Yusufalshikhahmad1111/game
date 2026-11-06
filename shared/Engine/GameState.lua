-- shared/Engine/GameState.lua (ModuleScript)
local Board = require(script.Parent.Board)
local TurnManager = require(script.Parent.TurnManager)
local ResourceSystem = require(script.Parent.ResourceSystem)
local WinSystem = require(script.Parent.WinSystem)

local GameState = {}
GameState.__index = GameState

function GameState.new(MapData, startingGridSize)
    local self = setmetatable({}, GameState)
    self.MapData = MapData
    self.board = Board.new(startingGridSize or MapData.DefaultGridSize, MapData)
    self.turnManager = TurnManager.new({"Player", "AI1", "AI2"})
    self.teamResources = {
        Player = {Gold = 0, Food = 0, Wood = 0},
        AI1    = {Gold = 0, Food = 0, Wood = 0},
        AI2    = {Gold = 0, Food = 0, Wood = 0}
    }
    self.gameActive = true
    self.winner = nil
    return self
end

function GameState:clone()
    local clone = GameState.new(self.MapData, self.board.gridSize)
    clone.board = self.board:clone()
    clone.turnManager = TurnManager.new(self.turnManager.turnOrder)
    clone.turnManager.currentTurnIndex = self.turnManager.currentTurnIndex
    clone.teamResources = {}
    for team, res in pairs(self.teamResources) do
        clone.teamResources[team] = {}
        for k, v in pairs(res) do
            clone.teamResources[team][k] = v
        end
    end
    clone.gameActive = self.gameActive
    clone.winner = self.winner
    return clone
end

function GameState:getCurrentTeam()
    return self.turnManager:getCurrentTeam()
end

function GameState:advanceTurn()
    self.turnManager:advance()
    if self:getCurrentTeam() ~= "Player" then
        -- AI turn will be handled externally; just advance
    end
end

function GameState:checkWin()
    return WinState.checkWin(self.board)
end

function GameState:applyCapture(team, chosenColor, captureSystem)
    local capturedCells, gainedResources = captureSystem:capture(self.board, team, chosenColor)
    -- Update resources
    for resType, amount in pairs(gainedResources) do
        self.teamResources[team][resType] = self.teamResources[team][resType] + amount
    end
    return #capturedCells, gainedResources
end

function GameState:isActive()
    return self.gameActive
end

function GameState:setGameOver(winner)
    self.gameActive = false
    self.winner = winner
end

return GameState