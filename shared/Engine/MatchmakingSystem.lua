-- shared/Engine/MatchmakingSystem.lua (ModuleScript)
-- M6: Multiplayer matchmaking, lobby, and match state
local MatchmakingSystem = {}

-- Match states
MatchmakingSystem.States = {
    Lobby = "Lobby",
    Ready = "Ready",
    Countdown = "Countdown",
    Match = "Match",
    Victory = "Victory",
    Results = "Results"
}

-- Player session data
MatchmakingSystem.Sessions = {} -- [playerUserId] = sessionData
MatchmakingSystem.PlayerToTeam = {} -- [playerUserId] = teamName
MatchmakingSystem.TeamToPlayer = {} -- [teamName] = playerUserId or nil (for AI)

-- Match configuration
MatchmakingSystem.CurrentState = MatchmakingSystem.States.Lobby
MatchmakingSystem.MatchSettings = {
    mapSize = 10,
    modifier = "Classic",
    maxPlayers = 3,
    aiFill = true
}

-- Teams available
MatchmakingSystem.Teams = {"Player", "AI1", "AI2"}

-- Create a player session
function MatchmakingSystem.createSession(player)
    local userId = player.UserId
    if MatchmakingSystem.Sessions[userId] then
        return MatchmakingSystem.Sessions[userId]
    end

    local session = {
        player = player,
        userId = userId,
        team = nil,
        isReady = false,
        joinedAt = tick(),
        lastActionTime = 0,
        actionCount = 0 -- for rate limiting
    }

    MatchmakingSystem.Sessions[userId] = session
    return session
end

-- Remove a player session
function MatchmakingSystem.removeSession(player)
    local userId = player.UserId
    local session = MatchmakingSystem.Sessions[userId]
    if not session then return end

    -- Free the team if this player was assigned one
    if session.team then
        MatchmakingSystem.TeamToPlayer[session.team] = nil
        -- Convert to AI if match is active
        if MatchmakingSystem.CurrentState == MatchmakingSystem.States.Match then
            MatchmakingSystem.PlayerToTeam[userId] = nil
        end
    end

    MatchmakingSystem.Sessions[userId] = nil
end

-- Assign a team to a player
function MatchmakingSystem.assignTeam(player, teamName)
    local userId = player.UserId
    local session = MatchmakingSystem.Sessions[userId]
    if not session then return false end

    -- Check if team is available
    if MatchmakingSystem.TeamToPlayer[teamName] and MatchmakingSystem.TeamToPlayer[teamName] ~= userId then
        return false -- Team taken
    end

    -- Free previous team if any
    if session.team then
        MatchmakingSystem.TeamToPlayer[session.team] = nil
    end

    session.team = teamName
    MatchmakingSystem.TeamToPlayer[teamName] = userId
    MatchmakingSystem.PlayerToTeam[userId] = teamName
    return true
end

-- Get player's team
function MatchmakingSystem:getPlayerTeam(player)
    local userId = player.UserId
    local session = MatchmakingSystem.Sessions[userId]
    if not session then return nil end
    return session.team
end

-- Set player ready status
function MatchmakingSystem:setReady(player, ready)
    local userId = player.UserId
    local session = MatchmakingSystem.Sessions[userId]
    if not session then return false end
    session.isReady = ready
    return true
end

-- Check if all human players are ready
function MatchmakingSystem:allReady()
    local readyCount = 0
    local humanCount = 0
    for _, session in pairs(MatchmakingSystem.Sessions) do
        if session.team and session.team ~= "AI1" and session.team ~= "AI2" then
            humanCount = humanCount + 1
            if session.isReady then
                readyCount = readyCount + 1
            end
        end
    end
    return humanCount > 0 and readyCount == humanCount
end

-- Get all human players
function MatchmakingSystem:getHumanPlayers()
    local players = {}
    for _, session in pairs(MatchmakingSystem.Sessions) do
        if session.team and session.team ~= "AI1" and session.team ~= "AI2" then
            table.insert(players, session.player)
        end
    end
    return players
end

-- Get all sessions
function MatchmakingSystem:getAllSessions()
    return MatchmakingSystem.Sessions
end

-- Get team for a userId
function MatchmakingSystem:getTeamForUserId(userId)
    local session = MatchmakingSystem.Sessions[userId]
    if not session then return nil end
    return session.team
end

-- Set match state
function MatchmakingSystem:setState(state)
    MatchmakingSystem.CurrentState = state
end

-- Get match state
function MatchmakingSystem:getState()
    return MatchmakingSystem.CurrentState
end

-- Get match settings
function MatchmakingSystem:getSettings()
    return MatchmakingSystem.MatchSettings
end

-- Set match settings
function MatchmakingSystem:setSettings(settings)
    for k, v in pairs(settings) do
        MatchmakingSystem.MatchSettings[k] = v
    end
end

-- Auto-fill AI teams if needed
function MatchmakingSystem:autoFillAI()
    for _, team in ipairs(MatchmakingSystem.Teams) do
        if not MatchmakingSystem.TeamToPlayer[team] then
            MatchmakingSystem.TeamToPlayer[team] = nil -- Mark as AI-controlled
        end
    end
end

-- Check if a team is AI-controlled (no human player)
function MatchmakingSystem:isAITeam(teamName)
    local userId = MatchmakingSystem.TeamToPlayer[teamName]
    if not userId then return true end -- No player = AI
    local session = MatchmakingSystem.Sessions[userId]
    return session == nil or session.team == nil
end

return MatchmakingSystem