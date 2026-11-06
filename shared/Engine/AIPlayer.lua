-- shared/Engine/AIPlayer.lua (ModuleScript)
local AIConfig = require(script.Parent.AIConfig)
local CaptureSystem = require(script.Parent.CaptureSystem)
local WinSystem = require(script.Parent.WinSystem)

local AIPlayer = {}
AIPlayer.__index = AIPlayer

function AIPlayer.new(team, personalityName, difficultyName)
    local self = setmetatable({}, AIPlayer)
    self.team = team
    self.personality = AIConfig.getPersonality(personalityName)
    self.difficulty = AIConfig.getDifficulty(difficultyName)
    self.lastDecisionLog = {}
    return self
end

-- Evaluate a board state for a given team using personality weights
function AIPlayer:evaluateState(board, team)
    local weights = self.personality.weights
    local score = 0
    local details = {
        territoryGain = 0,
        resourceGain = 0,
        strategicValue = 0,
        threatReduction = 0,
        capitalSecurity = 0,
        futureExpansion = 0,
        opponentOpportunity = 0
    }

    -- Count owned territories and their strategic value
    local ownedCount = 0
    local ownedStrategicValue = 0
    local ownedProduction = {Gold = 0, Food = 0, Wood = 0, Relic = 0}

    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x, y)
            if cell and cell.owner == team then
                ownedCount = ownedCount + 1
                ownedStrategicValue = ownedStrategicValue + (cell.strategicValue or 1)
                for resType, amount in pairs(cell.productionPerTurn or {}) do
                    ownedProduction[resType] = (ownedProduction[resType] or 0) + amount
                end
            end
        end
    end

    -- Territory gain score
    details.territoryGain = ownedCount * weights.territoryGain
    score = score + details.territoryGain

    -- Resource gain score (production per turn)
    local totalProduction = ownedProduction.Gold + ownedProduction.Food + ownedProduction.Wood + ownedProduction.Relic
    details.resourceGain = totalProduction * weights.resourceGain
    score = score + details.resourceGain

    -- Strategic value score
    details.strategicValue = ownedStrategicValue * weights.strategicValue
    score = score + details.strategicValue

    -- Capital security: check if team owns capital cells
    local capitalSecure = 0
    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x, y)
            if cell and cell.owner == team and cell.terrainType == "Capital" then
                capitalSecure = capitalSecure + 1
            end
        end
    end
    details.capitalSecurity = capitalSecure * weights.capitalSecurity * 10
    score = score + details.capitalSecurity

    -- Future expansion: count empty/neutral neighbors of owned cells
    local expansionOpportunities = 0
    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x, y)
            if cell and cell.owner == team then
                local neighbors = board:getNeighbors(cell)
                for _, nb in ipairs(neighbors) do
                    if nb and nb.owner == "Neutral" then
                        expansionOpportunities = expansionOpportunities + 1
                    end
                end
            end
        end
    end
    details.futureExpansion = expansionOpportunities * weights.futureExpansion
    score = score + details.futureExpansion

    -- Threat reduction and opponent opportunity (evaluate opponents)
    local opponentCount = 0
    local opponentExpansion = 0
    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x, y)
            if cell and cell.owner ~= team and cell.owner ~= "Neutral" then
                opponentCount = opponentCount + 1
                local neighbors = board:getNeighbors(cell)
                for _, nb in ipairs(neighbors) do
                    if nb and nb.owner == "Neutral" then
                        opponentExpansion = opponentExpansion + 1
                    end
                end
            end
        end
    end

    details.threatReduction = (100 - opponentCount) * weights.threatReduction * 0.1
    score = score + details.threatReduction

    details.opponentOpportunity = opponentExpansion * weights.opponentOpportunity * 0.1
    score = score - details.opponentOpportunity -- Penalize giving opponents opportunities

    self.lastDecisionLog = details
    return score, details
end

-- Simulate capturing a color on a cloned board and return the resulting score
function AIPlayer:simulateCapture(clonedBoard, team, chosenColor, MapData)
    -- Use CaptureSystem on the cloned board (safe, doesn't affect real state)
    local capturedCells, gainedResources = CaptureSystem:capture(clonedBoard, team, chosenColor, MapData)

    -- Count how many cells changed owner in simulation
    local captureCount = #capturedCells

    -- Evaluate the resulting state
    local score, details = self:evaluateState(clonedBoard, team)

    -- Add resource gain bonus
    local resourceBonus = (gainedResources.Gold + gainedResources.Food + gainedResources.Wood + gainedResources.Relic) * 0.1
    score = score + resourceBonus

    return score, captureCount, gainedResources, details
end

-- Choose the best color for the AI to play
function AIPlayer:chooseColor(gameState, MapData)
    local team = self.team
    local board = gameState.board
    local currentTurn = gameState.turnManager:getCurrentTeam()

    if currentTurn ~= team then
        return nil, "Not this team's turn"
    end

    local bestColor = nil
    local bestScore = -math.huge
    local bestDetails = nil
    local allScores = {}

    -- Evaluate each color option
    for _, color in ipairs(MapData.Colors) do
        -- Clone the game state for safe simulation
        local clonedState = gameState:clone()
        local clonedBoard = clonedState.board

        local score, captureCount, gainedResources, details = self:simulateCapture(
            clonedBoard, team, color, MapData
        )

        table.insert(allScores, {
            color = color,
            score = score,
            captureCount = captureCount,
            gainedResources = gainedResources,
            details = details
        })

        if score > bestScore then
            bestScore = score
            bestColor = color
            bestDetails = details
        end
    end

    -- Apply difficulty randomness
    local finalColor = bestColor
    if self.difficulty.randomness > 0 and #allScores > 1 then
        local roll = math.random()
        if roll < self.difficulty.randomness then
            -- Pick a random suboptimal move
            local sortedScores = {}
            for _, entry in ipairs(allScores) do
                if entry.color ~= bestColor then
                    table.insert(sortedScores, entry)
                end
            end
            if #sortedScores > 0 then
                local randomIdx = math.random(1, #sortedScores)
                finalColor = sortedScores[randomIdx].color
                -- Re-evaluate details for the chosen color
                for _, entry in ipairs(allScores) do
                    if entry.color == finalColor then
                        bestDetails = entry.details
                        break
                    end
                end
            end
        end
    end

    self.lastDecisionLog = bestDetails or {}
    self.lastDecisionLog.chosenColor = finalColor
    self.lastDecisionLog.bestScore = bestScore
    self.lastDecisionLog.allScores = allScores

    return finalColor, nil
end

-- Get the last decision log (for debugging/logging)
function AIPlayer:getDecisionLog()
    return self.lastDecisionLog
end

return AIPlayer