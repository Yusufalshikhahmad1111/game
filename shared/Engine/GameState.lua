-- shared/Engine/GameState.lua (ModuleScript)
local Board = require(script.Parent.Board)
local TurnManager = require(script.Parent.TurnManager)
local ResourceSystem = require(script.Parent.ResourceSystem)
local WinSystem = require(script.Parent.WinSystem)
local CaptureSystem = require(script.Parent.CaptureSystem)

local GameState = {}
GameState.__index = GameState

function GameState.new(MapData, startingGridSize)
    local self = setmetatable({}, GameState)
    self.MapData = MapData
    self.board = Board.new(startingGridSize or MapData.DefaultGridSize, MapData)
    self.turnManager = TurnManager.new({"Player", "AI1", "AI2"})
    self.teamResources = {
        Player = {Gold = 0, Food = 0, Wood = 0, Relic = 0},
        AI1    = {Gold = 0, Food = 0, Wood = 0, Relic = 0},
        AI2    = {Gold = 0, Food = 0, Wood = 0, Relic = 0}
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
    -- Generate resources for all teams at the start of the turn
    self:generateTurnResources()
    self.turnManager:advance()
end

function GameState:generateTurnResources()
    for teamName, resources in pairs(self.teamResources) do
        -- Calculate production from all territories owned by this team
        local production = {Gold = 0, Food = 0, Wood = 0, Relic = 0}
        for x = 1, self.board.gridSize do
            for y = 1, self.board.gridSize do
                local cell = self.board:getCell(x, y)
                if cell and cell.owner == teamName then
                    for resType, amount in pairs(cell.productionPerTurn) do
                        production[resType] = (production[resType] or 0) + amount
                    end
                end
            end
        end
        -- Add production to team resources
        for resType, amount in pairs(production) do
            self.teamResources[teamName][resType] = (self.teamResources[teamName][resType] or 0) + amount
        end
    end
end

function GameState:checkWin()
    return WinSystem.checkWin(self.board)
end

function GameState:applyCapture(team, chosenColor, captureSystem)
    local capturedCells, gainedResources = captureSystem:capture(self.board, team, chosenColor, self.MapData)
    -- Update resources: add gainedResources (which includes baseYield from capture)
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