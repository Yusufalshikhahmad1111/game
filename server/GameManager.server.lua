-- ServerScriptService/GameManager.server.lua (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")

local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("GameState"))
local ValidationSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("ValidationSystem"))
local CaptureSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("CaptureSystem"))
local AIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIConfig"))
local AIPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIPlayer"))

-- Initialize game state
local gameState = GameState.new(MapData, MapData.DefaultGridSize)

-- Create AI players for AI teams
local aiPlayers = {}
for team, config in pairs(AIConfig.DefaultAIs) do
    aiPlayers[team] = AIPlayer.new(team, config.personality, config.difficulty)
end

local function broadcastMap()
    local data = gameState.board:serialize()
    UpdateMap:FireAllClients(data, gameState.turnManager:getCurrentTeam(), gameState:isActive())
end

local function broadcastResources()
    ResourceUpdate:FireAllClients(gameState.teamResources)
end

local function handlePlayerTurn(colorName)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateTurn(gameState:getCurrentTeam(), "Player") then return end
    if not ValidationSystem.validateColor(colorName, MapData) then return end

    local capturedCount, gainedResources = gameState:applyCapture("Player", colorName, CaptureSystem)

    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        return
    end
    gameState:advanceTurn()
    broadcastMap()
    broadcastResources()

    -- Trigger AI turn if needed
    local currentTeam = gameState:getCurrentTeam()
    if currentTeam ~= "Player" then
        task.wait(1.2)
        handleAITurn(currentTeam)
    end
end

local function handleAITurn(team)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateTurn(gameState:getCurrentTeam(), team) then return end

    local aiPlayer = aiPlayers[team]
    if not aiPlayer then
        -- Fallback: skip turn if no AI configured
        gameState:advanceTurn()
        broadcastMap()
        broadcastResources()
        return
    end

    -- AI chooses color using its personality and difficulty (safe, uses cloned state internally)
    local chosenColor, err = aiPlayer:chooseColor(gameState, MapData)
    if not chosenColor then
        warn("AI " .. team .. " failed to choose color: " .. tostring(err))
        gameState:advanceTurn()
        broadcastMap()
        broadcastResources()
        return
    end

    -- Apply the chosen capture on the real state
    local capturedCount, gainedResources = gameState:applyCapture(team, chosenColor, CaptureSystem)

    -- Optional: log AI decision for debugging
    local log = aiPlayer:getDecisionLog()
    if log then
        print(string.format("[AI %s] Chose color: %s | Score: %.2f | Captured: %d",
            team, chosenColor, log.bestScore or 0, log.chosenColor and capturedCount or 0))
    end

    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        return
    end
    gameState:advanceTurn()
    broadcastMap()
    broadcastResources()
end

SelectColor.OnServerEvent:Connect(function(_player, colorName)
    handlePlayerTurn(colorName)
end)

SetMapSize.OnServerEvent:Connect(function(_player, size)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateMapSize(size, MapData) then return end
    gameState = GameState.new(MapData, size)
    -- Recreate AI players for new game
    aiPlayers = {}
    for team, config in pairs(AIConfig.DefaultAIs) do
        aiPlayers[team] = AIPlayer.new(team, config.personality, config.difficulty)
    end
    broadcastMap()
    broadcastResources()
end)

-- Initial broadcast
broadcastMap()
broadcastResources()