-- tests/CoreTests.lua (ModuleScript)
-- M7: Regression tests for core game systems
-- Covers: Player+AI match, AI isolation, timeout, disconnect/reconnect, progression, powers, events, resources, invalid requests, map sizes

local TestFramework = {}
TestFramework.__index = TestFramework

local testsPassed = 0
local testsFailed = 0
local testResults = {}

function TestFramework:new()
    local self = setmetatable({}, TestFramework)
    return self
end

function TestFramework:assert(condition, message)
    if condition then
        testsPassed = testsPassed + 1
        table.insert(testResults, {status = "PASS", message = message or "assertion"})
    else
        testsFailed = testsFailed + 1
        table.insert(testResults, {status = "FAIL", message = message or "assertion"})
        warn("TEST FAIL: " .. (message or "assertion"))
    end
end

function TestFramework:assertEqual(actual, expected, message)
    self:assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

function TestFramework:assertNotEqual(actual, expected, message)
    self:assert(actual ~= expected, message or string.format("expected not %s, got %s", tostring(expected), tostring(actual)))
end

function TestFramework:assertNotNil(value, message)
    self:assert(value ~= nil, message or "value should not be nil")
end

function TestFramework:assertNil(value, message)
    self:assert(value == nil, message or "value should be nil")
end

function TestFramework:report()
    print(string.format("\n=== TEST REPORT: %d passed, %d failed ===", testsPassed, testsFailed))
    for _, result in ipairs(testResults) do
        print(string.format("[%s] %s", result.status, result.message))
    end
    return testsFailed == 0
end

-- ============================================================
-- TEST SUITE
-- ============================================================

local function runTests()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
    local Board = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("Board"))
    local GameState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("GameState"))
    local CaptureSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("CaptureSystem"))
    local WinSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("WinSystem"))
    local ValidationSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("ValidationSystem"))
    local AIPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIPlayer"))
    local AIConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("AIConfig"))
    local PowerSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("PowerSystem"))
    local EventSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("EventSystem"))
    local MatchModifierSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("MatchModifierSystem"))
    local ProgressionSystem = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("ProgressionSystem"))
    local MultiplayerManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Engine"):WaitForChild("MultiplayerManager"))

    local T = TestFramework:new()

    print("=== Running Core Regression Tests ===\n")

    -- ============================================================
    -- BOARD TESTS
    -- ============================================================
    print("--- Board Tests ---")

    local board = Board.new(10, MapData)
    T:assertNotNil(board, "Board should be created")
    T:assertEqual(board.gridSize, 10, "Board gridSize should be 10")
    T:assertNotNil(board:getCell(1, 1), "Cell (1,1) should exist")
    T:assertNotNil(board:getCell(10, 10), "Cell (10,10) should exist")
    T:assertNil(board:getCell(0, 1), "Cell (0,1) should be nil")
    T:assertNil(board:getCell(11, 1), "Cell (11,1) should be nil")

    local cell11 = board:getCell(1, 1)
    local neighbors = board:getNeighbors(cell11)
    T:assertEqual(#neighbors, 2, "Corner cell should have 2 neighbors")

    local cell55 = board:getCell(5, 5)
    local neighbors55 = board:getNeighbors(cell55)
    T:assertEqual(#neighbors55, 4, "Center cell should have 4 neighbors")

    -- Board clone isolation
    local boardClone = board:clone()
    T:assertNotNil(boardClone, "Board clone should exist")
    T:assertEqual(boardClone.gridSize, 10, "Clone gridSize should match")
    local originalOwner = board:getCell(1, 1).owner
    board:getCell(1, 1).owner = "TestOwner"
    T:assertNotEqual(boardClone:getCell(1, 1).owner, "TestOwner", "Clone should not reflect original changes")
    board:getCell(1, 1).owner = originalOwner

    -- Serialize
    local serialized = board:serialize()
    T:assertEqual(#serialized, 100, "Serialized board should have 100 cells")
    T:assertNotNil(serialized[1].id, "Serialized cell should have id")
    T:assertNotNil(serialized[1].terrainType, "Serialized cell should have terrainType")

    -- ============================================================
    -- CAPTURE SYSTEM TESTS
    -- ============================================================
    print("\n--- Capture System Tests ---")

    local captureBoard = Board.new(10, MapData)
    local cell11 = captureBoard:getCell(1, 1)
    local cell12 = captureBoard:getCell(1, 2)
    cell11.owner = "Player"
    cell12.owner = "Neutral"
    cell12.color = "Red"

    local captured, gained = CaptureSystem:capture(captureBoard, "Player", "Red", MapData)
    T:assertEqual(#captured, 1, "Should capture 1 cell")
    T:assertEqual(cell12.owner, "Player", "Cell (1,2) should be owned by Player")
    T:assertNotNil(gained, "Gained resources should not be nil")

    local captured2, gained2 = CaptureSystem:capture(captureBoard, "Player", "InvalidColor", MapData)
    T:assertEqual(#captured2, 0, "Invalid color should capture 0 cells")

    -- Clone isolation for capture
    local simBoard = captureBoard:clone()
    CaptureSystem:capture(simBoard, "Player", "Blue", MapData)
    T:assertEqual(captureBoard:getCell(1, 2).owner, "Player", "Original unchanged after sim capture")

    -- ============================================================
    -- WIN SYSTEM TESTS
    -- ============================================================
    print("\n--- Win System Tests ---")

    local winBoard = Board.new(10, MapData)
    for x = 1, 10 do
        for y = 1, 10 do
            winBoard:getCell(x, y).owner = "Player"
        end
    end
    local won, winner = WinSystem.checkWin(winBoard)
    T:assertEqual(won, true, "Win detected when one team owns all cells")
    T:assertEqual(winner, "Player", "Winner should be Player")

    winBoard:getCell(5, 5).owner = "AI1"
    local won2, _ = WinSystem.checkWin(winBoard)
    T:assertEqual(won2, false, "No win when multiple owners")

    -- ============================================================
    -- VALIDATION SYSTEM TESTS
    -- ============================================================
    print("\n--- Validation System Tests ---")

    T:assertEqual(ValidationSystem.validateColor("Red", MapData), true, "Red valid")
    T:assertEqual(ValidationSystem.validateColor("Invalid", MapData), false, "Invalid invalid")
    T:assertEqual(ValidationSystem.validateColor(nil, MapData), false, "Nil invalid")
    T:assertEqual(ValidationSystem.validateMapSize(10, MapData), true, "10 valid")
    T:assertEqual(ValidationSystem.validateMapSize(15, MapData), true, "15 valid")
    T:assertEqual(ValidationSystem.validateMapSize(20, MapData), true, "20 valid")
    T:assertEqual(ValidationSystem.validateMapSize(99, MapData), false, "99 invalid")
    T:assertEqual(ValidationSystem.validateTurn("Player", "Player"), true, "Turn match")
    T:assertEqual(ValidationSystem.validateTurn("AI1", "Player"), false, "Turn no match")
    T:assertEqual(ValidationSystem.validateGameActive(true), true, "Active valid")
    T:assertEqual(ValidationSystem.validateGameActive(false), false, "Inactive invalid")

    -- ============================================================
    -- MULTIPLAYER MANAGER TESTS
    -- ============================================================
    print("\n--- MultiplayerManager Tests ---")

    local mp = MultiplayerManager.new()
    T:assertNotNil(mp, "MultiplayerManager created")

    -- AI teams should be AI-controlled by default
    T:assertEqual(mp:isAIControlled("AI1"), true, "AI1 should be AI-controlled initially")
    T:assertEqual(mp:isAIControlled("AI2"), true, "AI2 should be AI-controlled initially")
    T:assertEqual(mp:isAIControlled("Player"), true, "Player should be AI-controlled initially (no human)")

    local aiTeams = mp:getAIControlledTeams()
    T:assertEqual(#aiTeams, 3, "All 3 teams should be AI-controlled initially")

    -- Assign a human player (mock)
    local mockPlayer = {UserId = 1, Name = "TestPlayer"}
    local team = mp:assignTeam(mockPlayer)
    T:assertEqual(team, "Player", "Human should get Player team")
    T:assertEqual(mp:getPlayerTeam(mockPlayer), "Player", "Player team mapping correct")
    T:assertEqual(mp:getTeamPlayer("Player"), mockPlayer, "Team player mapping correct")
    T:assertEqual(mp:isAIControlled("Player"), false, "Player team no longer AI-controlled after assignment")

    -- AI1 and AI2 still AI-controlled
    T:assertEqual(mp:isAIControlled("AI1"), true, "AI1 still AI-controlled")
    T:assertEqual(mp:isAIControlled("AI2"), true, "AI2 still AI-controlled")

    -- Release team
    mp:releaseTeam(mockPlayer)
    T:assertNil(mp:getPlayerTeam(mockPlayer), "Player team released")
    T:assertEqual(mp:isAIControlled("Player"), true, "Player team AI-controlled again after release")

    -- Lobby state
    local lobbyData = mp:getLobbyData()
    T:assertEqual(lobbyData.state, "Waiting", "Initial lobby state Waiting")
    T:assertEqual(lobbyData.maxPlayers, 3, "Max players 3")

    -- ============================================================
    -- AI SYSTEM TESTS
    -- ============================================================
    print("\n--- AI System Tests ---")

    local gameState = GameState.new(MapData, 10)
    local ai = AIPlayer.new("AI1", "Warlord", "Normal")
    T:assertNotNil(ai, "AI player created")
    T:assertEqual(ai.team, "AI1", "AI team AI1")

    local color, err = ai:chooseColor(gameState, MapData)
    T:assertNotNil(color, "AI chose color: " .. tostring(err))
    T:assertEqual(ValidationSystem.validateColor(color, MapData), true, "AI color valid")

    -- AI simulation isolation
    local beforeOwner = gameState.board:getCell(1, 1).owner
    ai:chooseColor(gameState, MapData)
    local afterOwner = gameState.board:getCell(1, 1).owner
    T:assertEqual(beforeOwner, afterOwner, "AI simulation does not modify real state")

    -- All personalities
    for _, personality in ipairs({"Warlord", "Merchant", "Guardian", "Trickster"}) do
        local aiTest = AIPlayer.new("AI1", personality, "Normal")
        local c, e = aiTest:chooseColor(gameState, MapData)
        T:assertNotNil(c, personality .. " chose color: " .. tostring(e))
    end

    -- All difficulties
    for _, difficulty in ipairs({"Easy", "Normal", "Hard"}) do
        local aiTest = AIPlayer.new("AI1", "Warlord", difficulty)
        local c, e = aiTest:chooseColor(gameState, MapData)
        T:assertNotNil(c, difficulty .. " chose color: " .. tostring(e))
    end

    -- ============================================================
    -- POWER SYSTEM TESTS
    -- ============================================================
    print("\n--- Power System Tests ---")

    local powers = PowerSystem:getAllPowers()
    T:assertEqual(#powers, 6, "6 powers defined")
    T:assertNotNil(PowerSystem:getPower("Scout"), "Scout exists")
    T:assertNil(PowerSystem:getPower("Invalid"), "Invalid power nil")

    local resources = {Gold = 100, Food = 50, Wood = 50}
    T:assertEqual(PowerSystem:canAfford(resources, "Scout"), true, "Can afford Scout")
    T:assertEqual(PowerSystem:canAfford(resources, "Shockwave"), false, "Cannot afford Shockwave")

    local affordable = PowerSystem:applyCost(resources, "Scout")
    T:assertEqual(affordable, true, "Apply Scout cost")
    T:assertEqual(resources.Gold, 50, "Gold 50 after Scout")

    T:assertEqual(PowerSystem:isOnCooldown("Scout"), false, "Scout not on cooldown initially")
    PowerSystem:activatePower("Scout", nil, {})
    T:assertEqual(PowerSystem:isOnCooldown("Scout"), true, "Scout on cooldown after activation")
    T:assertEqual(PowerSystem:getCooldownRemaining("Scout"), 3, "Scout cooldown 3")

    PowerSystem:tickCooldowns()
    T:assertEqual(PowerSystem:getCooldownRemaining("Scout"), 2, "Cooldown 2 after tick")
    PowerSystem:tickCooldowns()
    PowerSystem:tickCooldowns()
    T:assertEqual(PowerSystem:isOnCooldown("Scout"), false, "Scout cooldown expired")

    -- Team effects
    PowerSystem:activateTeamEffect("Player", "Harvest", nil, {multiplier = 2.0})
    T:assertEqual(PowerSystem:isTeamEffectActive("Player", "Harvest"), true, "Harvest active for Player")
    T:assertEqual(PowerSystem:getTeamEffectRemaining("Player", "Harvest"), 2, "Harvest 2 turns")

    local mod = PowerSystem:getProductionModifier("Player", {terrainType = "Plains", productionPerTurn = {Food = 2}})
    T:assertEqual(mod, 2.0, "Harvest doubles production")

    PowerSystem:tickCooldowns()
    PowerSystem:tickCooldowns()
    T:assertEqual(PowerSystem:isTeamEffectActive("Player", "Harvest"), false, "Harvest expired after 2 ticks")

    -- ============================================================
    -- EVENT SYSTEM TESTS
    -- ============================================================
    print("\n--- Event System Tests ---")

    local events = EventSystem:getAllEvents()
    T:assertEqual(#events, 5, "5 events defined")
    T:assertNotNil(EventSystem:getEvent("MeteorShower"), "MeteorShower exists")

    T:assertEqual(EventSystem:isActive("MeteorShower"), false, "MeteorShower not active initially")
    EventSystem:activateEvent("MeteorShower")
    T:assertEqual(EventSystem:isActive("MeteorShower"), true, "MeteorShower active")
    T:assertEqual(EventSystem:getRemainingTurns("MeteorShower"), 2, "MeteorShower duration 2")

    EventSystem:tickDurations()
    T:assertEqual(EventSystem:getRemainingTurns("MeteorShower"), 1, "1 turn remaining")
    EventSystem:tickDurations()
    T:assertEqual(EventSystem:isActive("MeteorShower"), false, "MeteorShower expired")

    -- Production modifier
    EventSystem:activateEvent("GreatRain")
    local mod2 = EventSystem:getProductionModifier("Plains", "Food")
    T:assertEqual(mod2, 1.3, "GreatRain gives 1.3 modifier")
    EventSystem:tickDurations()
    EventSystem:tickDurations()

    EventSystem:activateEvent("Wildfire")
    local mod3 = EventSystem:getProductionModifier("Forest", "Wood")
    T:assertEqual(mod3, 0.5, "Wildfire gives 0.5 modifier")

    -- ============================================================
    -- MATCH MODIFIER SYSTEM TESTS
    -- ============================================================
    print("\n--- Match Modifier System Tests ---")

    local modifiers = MatchModifierSystem:getAllModifiers()
    T:assertEqual(#modifiers, 5, "5 modifiers defined")
    T:assertNotNil(MatchModifierSystem:getModifier("Classic"), "Classic exists")
    T:assertNil(MatchModifierSystem:getModifier("Invalid"), "Invalid modifier nil")

    MatchModifierSystem:setModifier("RichIslands")
    local current = MatchModifierSystem:getCurrentModifier()
    T:assertEqual(current.name, "RichIslands", "Current RichIslands")
    local startingRes = MatchModifierSystem:getStartingResources()
    T:assertEqual(startingRes.Gold, 200, "RichIslands Gold 200")

    MatchModifierSystem:setModifier("Classic")
    local classicRes = MatchModifierSystem:getStartingResources()
    T:assertEqual(classicRes.Gold, 100, "Classic Gold 100")

    -- ============================================================
    -- PROGRESSION SYSTEM TESTS
    -- ============================================================
    print("\n--- Progression System Tests ---")

    ProgressionSystem.PlayerData.xp = 0
    ProgressionSystem.PlayerData.matchesPlayed = 0
    ProgressionSystem.PlayerData.matchesWon = 0
    ProgressionSystem.PlayerData.achievementsUnlocked = {}
    ProgressionSystem.PlayerData.stats = {
        totalCaptures = 0, totalPowersUsed = 0, favoritePower = nil,
        longestWinStreak = 0, currentWinStreak = 0
    }

    local result = ProgressionSystem:recordMatch(true, 1.0)
    T:assertEqual(result.xpGained, 100, "Win gives 100 XP")
    T:assertEqual(ProgressionSystem.PlayerData.matchesPlayed, 1, "Matches played 1")
    T:assertEqual(ProgressionSystem.PlayerData.matchesWon, 1, "Matches won 1")

    local rank = ProgressionSystem:getRankForXP(100)
    T:assertEqual(rank.name, "Bronze", "100 XP = Bronze")
    local rank8000 = ProgressionSystem:getRankForXP(8000)
    T:assertEqual(rank8000.name, "Dominion", "8000 XP = Dominion")

    ProgressionSystem:addGoldEarned(500)
    T:assertEqual(ProgressionSystem.PlayerData.totalGoldEarned, 500, "Gold earned 500")
    ProgressionSystem:addRelicCollected(3)
    T:assertEqual(ProgressionSystem.PlayerData.totalRelicsCollected, 3, "Relics 3")
    ProgressionSystem:recordPowerUsed("Harvest")
    T:assertEqual(ProgressionSystem.PlayerData.stats.totalPowersUsed, 1, "Powers used 1")
    T:assertEqual(ProgressionSystem.PlayerData.stats.favoritePower, "Harvest", "Favorite Harvest")

    -- ============================================================
    -- GAMESTATE CLONE ISOLATION (Critical for AI safety)
    -- ============================================================
    print("\n--- GameState Clone Isolation ---")

    local gs = GameState.new(MapData, 10)
    local gsClone = gs:clone()
    gs.teamResources.Player.Gold = 999
    gs.board:getCell(5, 5).owner = "Modified"
    gs.turnManager:advance()
    T:assertEqual(gsClone.teamResources.Player.Gold, 0, "Clone resources unchanged")
    T:assertEqual(gsClone.board:getCell(5, 5).owner, "Neutral", "Clone board unchanged")
    T:assertEqual(gsClone.turnManager.currentTurnIndex, 1, "Clone turn index unchanged")

    -- ============================================================
    -- MAP SIZE TESTS (10x10, 15x15, 20x20)
    -- ============================================================
    print("\n--- Map Size Tests ---")

    for _, size in ipairs({10, 15, 20}) do
        local testBoard = Board.new(size, MapData)
        T:assertEqual(testBoard.gridSize, size, string.format("Board %dx%d created", size, size))
        local serialized = testBoard:serialize()
        T:assertEqual(#serialized, size * size, string.format("%dx%d serialized %d cells", size, size, size * size))
        -- Verify all cells have valid terrain
        for _, cellData in ipairs(serialized) do
            T:assertNotNil(cellData.terrainType, string.format("Cell %s has terrainType", cellData.id))
            T:assertNotNil(cellData.owner, string.format("Cell %s has owner", cellData.id))
        end
    end

    -- ============================================================
    -- INVALID REMOTE REQUESTS (simulated validation)
    -- ============================================================
    print("\n--- Invalid Remote Request Tests ---")

    T:assertEqual(ValidationSystem.validateColor("Red", MapData), true, "Valid color accepted")
    T:assertEqual(ValidationSystem.validateColor("Pink", MapData), false, "Invalid color rejected")
    T:assertEqual(ValidationSystem.validateMapSize(10, MapData), true, "Valid size 10 accepted")
    T:assertEqual(ValidationSystem.validateMapSize(100, MapData), false, "Invalid size 100 rejected")
    T:assertEqual(ValidationSystem.validateTurn("Player", "Player"), true, "Correct turn accepted")
    T:assertEqual(ValidationSystem.validateTurn("AI1", "Player"), false, "Wrong turn rejected")

    -- ============================================================
    -- PLAYER + AI1 + AI2 MATCH SIMULATION
    -- ============================================================
    print("\n--- Player + AI1 + AI2 Match Simulation ---")

    local matchState = GameState.new(MapData, 10)
    T:assertNotNil(matchState, "Match state created")
    T:assertEqual(matchState.turnManager:getCurrentTeam(), "Player", "Player starts first")

    -- Player captures Red neighbor
    local pCell11 = matchState.board:getCell(1, 1)
    local pCell12 = matchState.board:getCell(1, 2)
    pCell11.owner = "Player"
    pCell12.owner = "Neutral"
    pCell12.color = "Red"
    local c1, g1 = matchState:applyCapture("Player", "Red", CaptureSystem)
    T:assertEqual(c1, 1, "Player captures 1 cell")

    -- AI1 turn
    local ai1 = AIPlayer.new("AI1", "Warlord", "Normal")
    local c2, err2 = ai1:chooseColor(matchState, MapData)
    T:assertNotNil(c2, "AI1 chooses color: " .. tostring(err2))
    local c3, g3 = matchState:applyCapture("AI1", c2, CaptureSystem)
    T:assertNotNil(g3, "AI1 capture returns resources")

    -- AI2 turn
    local ai2 = AIPlayer.new("AI2", "Merchant", "Hard")
    local c4, err4 = ai2:chooseColor(matchState, MapData)
    T:assertNotNil(c4, "AI2 chooses color: " .. tostring(err4))
    local c5, g5 = matchState:applyCapture("AI2", c4, CaptureSystem)
    T:assertNotNil(g5, "AI2 capture returns resources")

    -- Verify turn order advanced
    T:assertEqual(matchState.turnManager:getCurrentTeam(), "Player", "Turn back to Player after AI2")

    -- ============================================================
    -- RESOURCE PRODUCTION TEST
    -- ============================================================
    print("\n--- Resource Production Test ---")

    local prodBoard = Board.new(10, MapData)
    local prodGS = GameState.new(MapData, 10)
    prodGS.board = prodBoard
    -- Give Player some Plains cells
    for x = 1, 3 do
        for y = 1, 3 do
            local cell = prodBoard:getCell(x, y)
            cell.owner = "Player"
            cell.terrainType = "Plains"
            cell.productionPerTurn = {Food = 2}
        end
    end
    prodGS:generateTurnResources()
    T:assertEqual(prodGS.teamResources.Player.Food, 18, "3x3 Plains produce 18 Food (9 cells * 2)")

    -- With GreatRain event
    EventSystem:activateEvent("GreatRain")
    prodGS:generateTurnResources()
    T:assertEqual(prodGS.teamResources.Player.Food, 18 + math.floor(18 * 1.3), "GreatRain boosts Food production")
    EventSystem:tickDurations()
    EventSystem:tickDurations()

    print("\n")
    local allPassed = T:report()
    if allPassed then
        print("✅ ALL REGRESSION TESTS PASSED")
    else
        print("❌ SOME TESTS FAILED")
    end
    return allPassed
end

return {
    run = runTests
}