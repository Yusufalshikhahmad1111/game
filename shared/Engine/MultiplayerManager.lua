-- shared/Engine/MultiplayerManager.lua (ModuleScript)
-- M6: Multiplayer - lobby, team mapping, ready state, match flow
local Players = game:GetService("Players")

local MultiplayerManager = {}
MultiplayerManager.__index = MultiplayerManager

-- Lobby states
local LOBBY_WAITING = "Waiting"
local LOBBY_READY = "Ready"
local LOBBY_IN_MATCH = "InMatch"

-- Maximum players (including AI slots)
local MAX_PLAYERS = 3

-- Team colors available for players
local AVAILABLE_TEAMS = {"Player", "AI1", "AI2"}

function MultiplayerManager.new()
    local self = setmetatable({}, MultiplayerManager)
    
    -- Player → team mapping
    self.playerTeams = {}      -- [Player] = teamName
    self.teamPlayers = {}      -- [teamName] = Player or nil
    
    -- Lobby state
    self.lobbyState = LOBBY_WAITING
    self.readyPlayers = {}     -- [Player] = boolean
    
    -- Match state
    self.matchActive = false
    self.currentMatchId = nil
    
    -- Turn timeout
    self.turnTimeoutDuration = 30 -- seconds
    self.turnStartTime = nil
    self.turnTimeoutConnection = nil
    
    -- Rate limiting per player
    self.playerRequestTimes = {} -- [Player] = {lastRequestTime, requestCount}
    self.rateLimitMaxRequests = 10 -- per minute
    self.rateLimitWindow = 60 -- seconds
    
    -- AI replacement tracking
    self.aiControlledTeams = {"AI1", "AI2"} -- teams controlled by AI by default
    
    return self
end

-- ============================================================
-- PLAYER / TEAM MAPPING
-- ============================================================

function MultiplayerManager:assignTeam(player)
    -- Check if player already has a team
    if self.playerTeams[player] then
        return self.playerTeams[player]
    end
    
    -- Find first available team
    for _, teamName in ipairs(AVAILABLE_TEAMS) do
        if not self.teamPlayers[teamName] then
            self.playerTeams[player] = teamName
            self.teamPlayers[teamName] = player
            self.readyPlayers[player] = false
            return teamName
        end
    end
    
    -- No available teams
    return nil
end

function MultiplayerManager:releaseTeam(player)
    local teamName = self.playerTeams[player]
    if not teamName then return end
    
    self.playerTeams[player] = nil
    self.teamPlayers[teamName] = nil
    self.readyPlayers[player] = nil
    
    -- Mark team as AI-controlled again
    if not table.find(self.aiControlledTeams, teamName) then
        table.insert(self.aiControlledTeams, teamName)
    end
end

function MultiplayerManager:getPlayerTeam(player)
    return self.playerTeams[player]
end

function MultiplayerManager:getTeamPlayer(teamName)
    return self.teamPlayers[teamName]
end

function MultiplayerManager:getTeamForPlayerId(userId)
    for player, teamName in pairs(self.playerTeams) do
        if player.UserId == userId then
            return teamName
        end
    end
    return nil
end

function MultiplayerManager:getAllPlayerTeams()
    local result = {}
    for player, teamName in pairs(self.playerTeams) do
        table.insert(result, {
            player = player,
            userId = player.UserId,
            playerName = player.Name,
            team = teamName,
            ready = self.readyPlayers[player] or false
        })
    end
    return result
end

-- ============================================================
-- LOBBY STATE
-- ============================================================

function MultiplayerManager:setReady(player, ready)
    local teamName = self.playerTeams[player]
    if not teamName then return false end
    
    self.readyPlayers[player] = ready
    
    -- Check if all human players are ready
    local allReady = true
    local humanCount = 0
    for p, _ in pairs(self.playerTeams) do
        humanCount = humanCount + 1
        if not self.readyPlayers[p] then
            allReady = false
        end
    end
    
    if humanCount > 0 and allReady then
        self.lobbyState = LOBBY_READY
    else
        self.lobbyState = LOBBY_WAITING
    end
    
    return true
end

function MultiplayerManager:canStartMatch()
    if self.lobbyState ~= LOBBY_READY then return false end
    local humanCount = 0
    for _ in pairs(self.playerTeams) do
        humanCount = humanCount + 1
    end
    return humanCount >= 1
end

function MultiplayerManager:startMatch(matchId)
    if not self:canStartMatch() then return false end
    
    self.matchActive = true
    self.currentMatchId = matchId
    self.lobbyState = LOBBY_IN_MATCH
    self.turnStartTime = tick()
    
    -- AI fills remaining teams
    for teamName, player in pairs(self.teamPlayers) do
        if not player then
            -- This team is AI-controlled
        end
    end
    
    return true
end

function MultiplayerManager:endMatch()
    self.matchActive = false
    self.currentMatchId = nil
    self.lobbyState = LOBBY_WAITING
    self.readyPlayers = {}
    
    -- Reset ready states
    for player, _ in pairs(self.playerTeams) do
        self.readyPlayers[player] = false
    end
    
    if self.turnTimeoutConnection then
        self.turnTimeoutConnection:Disconnect()
        self.turnTimeoutConnection = nil
    end
end

-- ============================================================
-- TURN TIMEOUT
-- ============================================================

function MultiplayerManager:startTurnTimeout(onTimeoutCallback)
    self:stopTurnTimeout()
    self.turnStartTime = tick()
    
    self.turnTimeoutConnection = task.delay(self.turnTimeoutDuration, function()
        self.turnTimeoutConnection = nil
        if onTimeoutCallback then
            onTimeoutCallback()
        end
    end)
end

function MultiplayerManager:stopTurnTimeout()
    if self.turnTimeoutConnection then
        self.turnTimeoutConnection:Disconnect()
        self.turnTimeoutConnection = nil
    end
    self.turnStartTime = nil
end

function MultiplayerManager:getTimeRemaining()
    if not self.turnStartTime then return self.turnTimeoutDuration end
    local elapsed = tick() - self.turnStartTime
    return math.max(0, self.turnTimeoutDuration - elapsed)
end

function MultiplayerManager:setTurnTimeoutDuration(duration)
    self.turnTimeoutDuration = duration
end

-- ============================================================
-- RATE LIMITING
-- ============================================================

function MultiplayerManager:checkRateLimit(player)
    local now = tick()
    local data = self.playerRequestTimes[player]
    
    if not data then
        self.playerRequestTimes[player] = {lastRequestTime = now, requestCount = 1}
        return true
    end
    
    -- Reset window if expired
    if now - data.lastRequestTime > self.rateLimitWindow then
        self.playerRequestTimes[player] = {lastRequestTime = now, requestCount = 1}
        return true
    end
    
    data.requestCount = data.requestCount + 1
    data.lastRequestTime = now
    
    return data.requestCount <= self.rateLimitMaxRequests
end

function MultiplayerManager:resetRateLimit(player)
    self.playerRequestTimes[player] = nil
end

-- ============================================================
-- DISCONNECT / RECONNECT
-- ============================================================

function MultiplayerManager:onPlayerDisconnected(player)
    local teamName = self.playerTeams[player]
    if not teamName then return end
    
    -- Release the team
    self:releaseTeam(player)
    
    -- Mark team for AI replacement
    if not table.find(self.aiControlledTeams, teamName) then
        table.insert(self.aiControlledTeams, teamName)
    end
    
    -- If match was active, end it (or could continue with AI)
    if self.matchActive then
        -- Match continues with AI replacing the disconnected player
    end
end

function MultiplayerManager:onPlayerReconnected(player, oldTeamName)
    -- Try to reassign same team
    if oldTeamName and not self.teamPlayers[oldTeamName] then
        self.playerTeams[player] = oldTeamName
        self.teamPlayers[oldTeamName] = player
        self.readyPlayers[player] = false
        return oldTeamName
    end
    
    -- Otherwise assign new team
    return self:assignTeam(player)
end

-- ============================================================
-- AI REPLACEMENT
-- ============================================================

function MultiplayerManager:isAIControlled(teamName)
    return not self.teamPlayers[teamName]
end

function MultiplayerManager:getHumanPlayers()
    local humans = {}
    for player, _ in pairs(self.playerTeams) do
        table.insert(humans, player)
    end
    return humans
end

function MultiplayerManager:getAIControlledTeams()
    local aiTeams = {}
    for teamName, player in pairs(self.teamPlayers) do
        if not player then
            table.insert(aiTeams, teamName)
        end
    end
    return aiTeams
end

-- ============================================================
-- SERIALIZATION FOR CLIENT
-- ============================================================

function MultiplayerManager:getLobbyData()
    local players = {}
    for _, info in ipairs(self:getAllPlayerTeams()) do
        table.insert(players, {
            userId = info.userId,
            playerName = info.playerName,
            team = info.team,
            ready = info.ready
        })
    end
    
    return {
        state = self.lobbyState,
        players = players,
        maxPlayers = MAX_PLAYERS,
        canStart = self:canStartMatch()
    }
end

function MultiplayerManager:getMatchData()
    return {
        matchId = self.currentMatchId,
        active = self.matchActive,
        playerTeams = {},
        timeRemaining = self:getTimeRemaining()
    }
end

return MultiplayerManager