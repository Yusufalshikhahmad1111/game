-- shared/Engine/PlayerSession.lua (ModuleScript)
-- M6: Per-player session state for multiplayer
local PlayerSession = {}

local sessions = {} -- [playerUserId] = data

function PlayerSession.create(player)
    local userId = player.UserId
    if sessions[userId] then return sessions[userId] end

    sessions[userId] = {
        player = player,
        userId = userId,
        team = nil,
        resources = {Gold = 0, Food = 0, Wood = 0, Relic = 0},
        lastTurnTime = 0,
        turnTimeout = 30, -- seconds
        isConnected = true,
        stats = {
            captures = 0,
            powersUsed = 0,
            matchesPlayed = 0,
            matchesWon = 0
        }
    }
    return sessions[userId]
end

function PlayerSession.get(player)
    local userId = player.UserId
    return sessions[userId]
end

function PlayerSession.remove(player)
    local userId = player.UserId
    sessions[userId] = nil
end

function PlayerSession.setTeam(player, team)
    local session = PlayerSession.get(player)
    if session then session.team = team end
end

function PlayerSession.getTeam(player)
    local session = PlayerSession.get(player)
    return session and session.team or nil
end

function PlayerSession.setResources(player, resources)
    local session = PlayerSession.get(player)
    if session then
        session.resources = resources
    end
end

function PlayerSession.getResources(player)
    local session = PlayerSession.get(player)
    return session and session.resources or {Gold = 0, Food = 0, Wood = 0, Relic = 0}
end

function PlayerSession.setConnected(player, connected)
    local session = PlayerSession.get(player)
    if session then session.isConnected = connected end
end

function PlayerSession.isConnected(player)
    local session = PlayerSession.get(player)
    return session and session.isConnected or false
end

function PlayerSession.getAll()
    return sessions
end

return PlayerSession