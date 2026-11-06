-- ServerScriptService/GameManager.server.lua (Script)
-- M5: World Events + Powers + Progression integrated
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UsePower = Remotes:WaitForChild("UsePower")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")
local EventNotify = Remotes:WaitForChild("EventNotify")

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

-- Initialize game state
local gameState = GameState.new(MapData, MapData.DefaultGridSize)

-- Create AI players
local aiPlayers = {}
for team, config in pairs(AIConfig.DefaultAIs) do
    aiPlayers[team] = AIPlayer.new(team, config.personality, config.difficulty)
end

-- Match settings
local currentModifier = "Classic"
local eventChancePerTurn = MatchModifierSystem:getEventFrequency()

-- Initialize team resources from modifier
local startingRes = MatchModifierSystem:getStartingResources()
for team, res in pairs(gameState.teamResources) do
    res.Gold = startingRes.Gold
    res.Food = startingRes.Food
    res.Wood = startingRes.Wood
end

local function broadcastMap()
    local data = gameState.board:serialize()
    UpdateMap:FireAllClients(data, gameState.turnManager:getCurrentTeam(), gameState:isActive())
end

local function broadcastResources()
    ResourceUpdate:FireAllClients(gameState.teamResources)
end

local function broadcastPowerState()
    local cooldowns = PowerSystem:getAllCooldowns()
    EventNotify:FireAllClients({
        type = "PowerState",
        cooldowns = cooldowns,
        powers = PowerSystem:getAllPowers()
    })
end

local function broadcastEvents()
    local activeEvents = EventSystem:getAllActiveEvents()
    EventNotify:FireAllClients({
        type = "Events",
        active = activeEvents
    })
end

local function tryRandomEvent()
    local roll = math.random()
    if roll < (eventChancePerTurn * 0.15) then -- ~15% base chance per turn
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

local function handlePlayerTurn(colorName)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateTurn(gameState:getCurrentTeam(), "Player") then return end
    if not ValidationSystem.validateColor(colorName, MapData) then return end

    local capturedCount, gainedResources = gameState:applyCapture("Player", colorName, CaptureSystem)
    ProgressionSystem:addGoldEarned(gainedResources.Gold or 0)

    local won, winner = gameState:checkWin()
    if won then
        gameState:setGameOver(winner)
        GameOver:FireAllClients(winner)
        ProgressionSystem:recordMatch(true, 1.0)
        return
    end
    gameState:advanceTurn()
    broadcastMap()
    broadcastResources()
    PowerSystem:tickCooldowns()
    EventSystem:tickDurations()
    broadcastPowerState()
    broadcastEvents()
    tryRandomEvent()

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
        gameState:advanceTurn()
        broadcastMap()
        broadcastResources()
        return
    end

    local chosenColor, err = aiPlayer:chooseColor(gameState, MapData)
    if not chosenColor then
        warn("AI " .. team .. " failed: " .. tostring(err))
        gameState:advanceTurn()
        broadcastMap()
        broadcastResources()
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
        ProgressionSystem:recordMatch(false, 1.0) -- AI won, player lost
        return
    end
    gameState:advanceTurn()
    broadcastMap()
    broadcastResources()
    PowerSystem:tickCooldowns()
    EventSystem:tickDurations()
    broadcastPowerState()
    broadcastEvents()
    tryRandomEvent()
end

-- Power usage handler
UsePower.OnServerEvent:Connect(function(_player, powerName)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if gameState:getCurrentTeam() ~= "Player" then return end

    local power = PowerSystem:getPower(powerName)
    if not power then return end
    if PowerSystem:isOnCooldown(powerName) then return end
    if not PowerSystem:canAfford(gameState.teamResources.Player, powerName) then return end

    -- Apply cost
    PowerSystem:applyCost(gameState.teamResources.Player, powerName)
    PowerSystem:activatePower(powerName, nil, {})
    ProgressionSystem:recordPowerUsed(powerName)

    broadcastResources()
    broadcastPowerState()

    -- Apply power effect (simplified - future expansion can add specific effects)
    if powerName == "Harvest" then
        -- Double production next 2 turns (handled by cooldown system)
        print("[Power] Harvest activated for Player")
    elseif powerName == "Fortify" then
        print("[Power] Fortify activated for Player")
    end
end)

SelectColor.OnServerEvent:Connect(function(_player, colorName)
    handlePlayerTurn(colorName)
end)

SetMapSize.OnServerEvent:Connect(function(_player, size)
    if not ValidationSystem.validateGameActive(gameState:isActive()) then return end
    if not ValidationSystem.validateMapSize(size, MapData) then return end
    gameState = GameState.new(MapData, size)
    aiPlayers = {}
    for team, config in pairs(AIConfig.DefaultAIs) do
        aiPlayers[team] = AIPlayer.new(team, config.personality, config.difficulty)
    end
    -- Reset resources from modifier
    local startingRes = MatchModifierSystem:getStartingResources()
    for team, res in pairs(gameState.teamResources) do
        res.Gold = startingRes.Gold
        res.Food = startingRes.Food
        res.Wood = startingRes.Wood
    end
    broadcastMap()
    broadcastResources()
    broadcastPowerState()
end)

-- Initial broadcast
broadcastMap()
broadcastResources()
broadcastPowerState()
broadcastEvents()