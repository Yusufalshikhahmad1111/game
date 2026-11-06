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

-- Initialize game state
local gameState = GameState.new(MapData, MapData.DefaultGridSize)

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
    -- resources already added inside applyCapture

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
        gameState:AITurn(currentTeam) -- we'll add method to GameState? We'll handle here.
    end
end

-- We'll add a method to GameState for AI turn? Instead we keep AI logic here but using cloned state.
local function handleAITurn(team)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateTurn(gameState:getCurrentTeam(), team) then return end

    -- AI uses cloned state for simulation
    local clonedState = gameState:clone()
    local bestColor, bestScore = nil, -1
    local bestCaptureCount = 0

    for _, color in ipairs(MapData.Colors) do
        -- Simulate capture on cloned board
        local clonedBoard = clonedState.board
        local captured = 0
        local gainedResources = {Gold = 0, Food = 0, Wood = 0}
        for x = 1, clonedBoard.gridSize do
            for y = 1, clonedBoard.gridSize do
                local cell = clonedBoard:getCell(x, y)
                if cell and cell.owner == team then
                    local neighbors = clonedBoard:getNeighbors(cell)
                    for _, nb in ipairs(neighbors) do
                        if nb and nb.owner ~= team and nb.color == color then
                            -- capture nb in simulation
                            nb.owner = team
                            captured = captured + 1
                            for resType, amount in pairs(nb.resources) do
                                gainedResources[resType] = gainedResources[resType] + amount
                            end
                        end
                    end
                end
            end
        end
        local score = captured * 2 + (gainedResources.Gold + gainedResources.Food + gainedResources.Wood) * 0.1
        if score > bestScore then
            bestScore = score
            bestColor = color
            bestCaptureCount = captured
        end
    end

    if bestColor then
        -- Apply capture on real state
        local capturedCount, gainedResources = gameState:applyCapture(team, bestColor, CaptureSystem)
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
    -- Reset game with new size
    gameState = GameState.new(MapData, size)
    broadcastMap()
    broadcastResources()
end)

-- Initial broadcast
broadcastMap()
broadcastResources()