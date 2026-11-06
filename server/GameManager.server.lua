-- ServerScriptService/GameManager.server.lua (Script)
-- M6: Multiplayer + Fairness integrated
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UsePower = Remotes:WaitForChild("UsePower")
local JoinLobby = Remotes:WaitForChild("JoinLobby")
local LeaveLobby = Remotes:WaitForChild("LeaveLobby")
local SetReady = Remotes:WaitForChild("SetReady")
local StartMatch = Remotes:WaitForChild("StartMatch")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")
local EventNotify = Remotes:WaitForChild("EventNotify")
local LobbyState = Remotes:WaitForChild("LobbyState")
local MatchState = Remotes:WaitForChild("MatchState")
local TurnTimeout = Remotes:WaitForChild("TurnTimeout")

local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("GameState"))
local ValidationSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("ValidationSystem"))
local CaptureSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("CaptureSystem"))
local AIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIConfig"))
local AIPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIPlayer"))
local PowerSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("PowerSystem"))
local EventSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("EventSystem"))
local MatchModifierSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("MatchModifierSystem"))
local ProgressionSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("ProgressionSystem"))
local MultiplayerManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("MultiplayerManager"))

-- Initialize managers
local mpManager = MultiplayerManager.new()
local gameState = nil
local aiPlayers = {}

-- Match settings
local currentModifier = "Classic"
local eventChancePerTurn = MatchModifierSystem:getEventFrequency()

-- ============================================================
-- HELPER: BROADCAST FUNCTIONS (PER-PLAYER VISIBILITY)
-- ============================================================

local function broadcastMapToAll()
    if not gameState then return end
    local data = gameState.board:serialize()
    local currentTeam = gameState.turnManager:getCurrentTeam()
    UpdateMap:FireAllClients(data, currentTeam, gameState:isActive())
end

local function broadcastResourcesToPlayer(player)
    if not gameState then return end
    local teamName = mpManager:getPlayerTeam(player)
    if not teamName then return end
    -- Send only this player's team resources (per-player visibility)
    local teamRes = gameState.teamResources[teamName]
    if teamRes then
        ResourceUpdate:FireClient(player, teamRes)
    end
end

local function broadcastResourcesToAll()
    if not gameState then return end
    for player, _ in pairs(mpManager.playerTeams) do
        broadcastResourcesToPlayer(player)
    end
end

local function broadcastPowerState()
    if not gameState then return end
    local cooldowns = PowerSystem:getAllCooldowns()
    EventNotify:FireAllClients({
        type = "PowerState",
        cooldowns = cooldowns,
        powers = PowerSystem:getAllPowers()
    })
end

local function broadcastEvents()
    if not gameState then return end
    local activeEvents = EventSystem:getAllActiveEvents()
    EventNotify:FireAllClients({
        type = "Events",
        active = activeEvents
    })
end

local function broadcastLobbyState()
    LobbyState:FireAllClients(mpManager:getLobbyData())
end

local function broadcastMatchState()
    if not gameState then return end
    MatchState:FireAllClients(mpManager:getMatchData())
end

-- ============================================================
-- TURN TIMEOUT
-- ============================================================

local function startTurnTimeout()
    if not gameState then return end
    local currentTeam = gameState.turnManager:getCurrentTeam()
    local player = mpManager:getTeamPlayer(currentTeam)
    
    -- Only human players get timeout; AI turns are instant
    if not player then return end
    
    mpManager:startTurnTimeout(function()
        -- Turn timed out: skip this player's turn
        print("[Timeout] " .. player.Name .. " (" .. currentTeam .. ") timed out")
        TurnTimeout:FireClient(player, currentTeam)
        
        -- Advance turn automatically
        advanceTurnAndProcess()
    end)
end

local function stopTurnTimeout()
    mpManager:stopTurnTimeout()
end

-- ============================================================
-- GAME STATE MANAGEMENT
-- ============================================================

local function createGameState(gridSize)
    gameState = GameState.new(MapData, gridSize or MapData.DefaultGridSize)
    
    -- Initialize AI players for AI-controlled teams
    aiPlayers = {}
    for teamName, player in pairs(mpManager.teamPlayers) do
        if not player then
            -- AI-controlled team
            local config = AIConfig.DefaultAIs[teamName] or {personality = "Warlord", difficulty = "Normal"}
            aiPlayers[teamName] = AIPlayer.new(teamName, config.personality, config.difficulty)
        end
    end
    
    -- Initialize team resources from modifier
    local startingRes = MatchModifierSystem:getStartingResources()
    for team, res in pairs(gameState.teamResources) do
        res.Gold = startingRes.Gold
        res.Food = startingRes.Food
        res.Wood = startingRes.Wood
    end
end

local function advanceTurnAndProcess()
    if not gameState then return end
    
    stopTurnTimeout()
    
    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        ProgressionSystem:recordMatch(true, 1.0)
        mpManager:endMatch()
        broadcastMatchState()
        return
    end
    
    gameState:advanceTurn()
    broadcastMapToAll()
    broadcastResourcesToAll()
    PowerSystem:tickCooldowns()
    EventSystem:tickDurations()
    broadcastPowerState()
    broadcastEvents()
    
    local currentTeam = gameState.turnManager:getCurrentTeam()
    local player = mpManager:getTeamPlayer(currentTeam)
    
    if player then
        -- Human player's turn: start timeout
        tryRandomEvent()
        startTurnTimeout()
    else
        -- AI turn: process after delay
        task.wait(1.2)
        handleAITurn(currentTeam)
    end
    
    broadcastMatchState()
end

local function tryRandomEvent()
    local roll = math.random()
    if roll < (eventChancePerTurn * 0.15) then
        local events = EventSystem:getAllEvents()
        local eventList = {}
        for name, _ in pairs(events) do
            table.insert(eventList, name)
        end
        if #eventList > 0 then
            local randomEvent = eventList[math.random(1, #eventList)]
            EventSystem:activateEvent(randomEvent)
            broadcastEvents()
            print("[Event] Activated: " .. randomEvent)
        end
    end
end

-- ============================================================
-- TURN HANDLERS
-- ============================================================

local function handlePlayerTurn(player, colorName)
    if not gameState then return end
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    
    local teamName = mpManager:getPlayerTeam(player)
    if not teamName then return end
    if not ValidationSystem.validateTurn(gameState.turnManager:getCurrentTeam(), teamName) then return end
    if not ValidationSystem.validateColor(colorName, MapData) then return end
    
    -- Rate limit check
    if not mpManager:checkRateLimit(player) then
        warn("Rate limit exceeded for " .. player.Name)
        return
    end
    
    local capturedCount, gainedResources = gameState:applyCapture(teamName, colorName, CaptureSystem)
    ProgressionSystem:addGoldEarned(gainedResources.Gold or 0)
    
    -- Record progression for this player
    ProgressionSystem:recordMatch(false, 1.0) -- will be updated on win
    
    stopTurnTimeout()
    
    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        ProgressionSystem:recordMatch(true, 1.0)
        mpManager:endMatch()
        broadcastMatchState()
        return
    end
    
    advanceTurnAndProcess()
end

local function handleAITurn(team)
    if not gameState then return end
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateTurn(gameState.turnManager:getCurrentTeam(), team) then return end
    
    local aiPlayer = aiPlayers[team]
    if not aiPlayer then
        advanceTurnAndProcess()
        return
    end
    
    local chosenColor, err = aiPlayer:chooseColor(gameState, MapData)
    if not chosenColor then
        warn("AI " .. team .. " failed: " .. tostring(err))
        advanceTurnAndProcess()
        return
    end
    
    local capturedCount, gainedResources = gameState:applyCapture(team, chosenColor, CaptureSystem)
    
    local log = aiPlayer:getDecisionLog()
    if log then
        print(string.format("[AI %s] Color: %s | Score: %.2f | Captured: %d",
            team, chosenColor, log.bestScore or 0, capturedCount))
    end
    
    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        ProgressionSystem:recordMatch(false, 1.0)
        mpManager:endMatch()
        broadcastMatchState()
        return
    end
    
    advanceTurnAndProcess()
end

-- ============================================================
-- REMOTE EVENT HANDLERS
-- ============================================================

-- Player joins lobby
JoinLobby.OnServerEvent:Connect(function(player)
    if not mpManager:checkRateLimit(player) then return end
    
    local teamName = mpManager:assignTeam(player)
    if teamName then
        print("[Lobby] " .. player.Name .. " joined as " .. teamName)
        broadcastLobbyState()
    end
end)

-- Player leaves lobby
LeaveLobby.OnServerEvent:Connect(function(player)
    if not mpManager:checkRateLimit(player) then return end
    
    mpManager:releaseTeam(player)
    print("[Lobby] " .. player.Name .. " left lobby")
    broadcastLobbyState()
end)

-- Player sets ready state
SetReady.OnServerEvent:Connect(function(player, ready)
    if not mpManager:checkRateLimit(player) then return end
    
    if mpManager:setReady(player, ready) then
        broadcastLobbyState()
    end
end)

-- Start match (only when all ready)
StartMatch.OnServerEvent:Connect(function(player)
    if not mpManager:checkRateLimit(player) then return end
    
    -- Verify the player is in lobby and can start
    local teamName = mpManager:getPlayerTeam(player)
    if not teamName then return end
    if not mpManager:canStartMatch() then return end
    
    local matchId = "match_" .. tick()
    if mpManager:startMatch(matchId) then
        createGameState(MapData.DefaultGridSize)
        gameState.turnManager.currentTurnIndex = 1 -- Start with Player team
        
        print("[Match] Started: " .. matchId)
        broadcastMatchState()
        broadcastMapToAll()
        broadcastResourcesToAll()
        broadcastPowerState()
        broadcastEvents()
        
        -- Start first turn
        local currentTeam = gameState.turnManager:getCurrentTeam()
        local firstPlayer = mpManager:getTeamPlayer(currentTeam)
        
        if firstPlayer then
            startTurnTimeout()
        else
            task.wait(1.2)
            handleAITurn(currentTeam)
        end
    end
end)

-- Select color (player turn)
SelectColor.OnServerEvent:Connect(function(player, colorName)
    handlePlayerTurn(player, colorName)
end)

-- Set map size (lobby only)
SetMapSize.OnServerEvent:Connect(function(player, size)
    if not mpManager:checkRateLimit(player) then return end
    if gameState and gameState:isActive() then return end -- Can't change during match
    if not ValidationSystem.validateMapSize(size, MapData) then return end
    
    -- Reset game state with new size
    if gameState then
        createGameState(size)
    end
    broadcastMapToAll()
    broadcastResourcesToAll()
end)

-- Use power
UsePower.OnServerEvent:Connect(function(player, powerName)
    if not mpManager:checkRateLimit(player) then return end
    if not gameState then return end
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    
    local teamName = mpManager:getPlayerTeam(player)
    if not teamName then return end
    if gameState.turnManager:getCurrentTeam() ~= teamName then return end
    
    local power = PowerSystem:getPower(powerName)
    if not power then return end
    if PowerSystem:isOnCooldown(powerName) then return end
    if not PowerSystem:canAfford(gameState.teamResources[teamName], powerName) then return end
    
    PowerSystem:applyCost(gameState.teamResources[teamName], powerName)
    PowerSystem:activatePower(powerName, nil, {})
    ProgressionSystem:recordPowerUsed(powerName)
    
    broadcastResourcesToPlayer(player)
    broadcastPowerState()
    
    if powerName == "Harvest" then
        print("[Power] Harvest activated for " .. teamName)
    elseif powerName == "Fortify" then
        print("[Power] Fortify activated for " .. teamName)
    end
end)

-- ============================================================
-- PLAYER DISCONNECT / RECONNECT
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
    print("[Disconnect] " .. player.Name .. " left the game")
    
    local teamName = mpManager:getPlayerTeam(player)
    if teamName then
        mpManager:onPlayerDisconnected(player)
        
        -- If match is active, AI takes over this team
        if gameState and gameState:isActive() then
            print("[AI Replacement] AI taking over " .. teamName .. " for disconnected player")
            local config = AIConfig.DefaultAIs[teamName] or {personality = "Warlord", difficulty = "Normal"}
            aiPlayers[teamName] = AIPlayer.new(teamName, config.personality, config.difficulty)
        end
        
        broadcastLobbyState()
        broadcastMapToAll()
        broadcastResourcesToAll()
    end
    
    mpManager:resetRateLimit(player)
end)

-- ============================================================
-- INITIALIZATION
-- ============================================================

-- Send initial lobby state
broadcastLobbyState()

print("[GameManager] M6 Multiplayer initialized")