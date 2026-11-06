-- tests/CoreTests.lua (ModuleScript)
-- M7: Regression tests for core game systems
-- Run these tests to verify core rules work correctly before release

local TestFramework = {}
TestFramework.__index = TestFramework

local testsPassed = 0
local testsFailed = 0
local testResults = {}

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

function TestFramework:assertNotNil(value, message)
    self:assert(value ~= nil, message or "value should not be nil")
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

    local T = TestFramework.new()

    print("=== Running Core Tests ===\n")

    -- ============================================================
    -- BOARD TESTS
    -- ============================================================
    print("--- Board Tests ---")

    local board = Board.new(10, MapData)
    T:assertNotNil(board, "Board should be created")
    T:assertEqual(board.gridSize, 10, "Board gridSize should be 10")

    -- Test getCell bounds
    T:assertNotNil(board:getCell(1, 1), "Cell (1,1) should exist")
    T:assertNotNil(board:getCell(10, 10), "Cell (10,10) should exist")
    T:assertEqual(board:getCell(0, 1), nil, "Cell (0,1) should be nil (out of bounds)")
    T:assertEqual(board:getCell(11, 1), nil, "Cell (11,1) should be nil (out of bounds)")

    -- Test neighbors
    local cell11 = board:getCell(1, 1)
    local neighbors = board:getNeighbors(cell11)
    T:assertEqual(#neighbors, 2, "Corner cell should have 2 neighbors")

    local cell55 = board:getCell(5, 5)
    local neighbors55 = board:getNeighbors(cell55)
    T:assertEqual(#neighbors55, 4, "Center cell should have 4 neighbors")

    -- Test board clone isolation
    local boardClone = board:clone()
    T:assertNotNil(boardClone, "Board clone should exist")
    T:assertEqual(boardClone.gridSize, 10, "Clone gridSize should match")

    -- Modify original, clone should be unaffected
    local originalOwner = board:getCell(1, 1).owner
    board:getCell(1, 1).owner = "TestOwner"
    T:assertNotEqual(boardClone:getCell(1, 1).owner, "TestOwner", "Clone should not reflect original changes")
    board:getCell(1, 1).owner = originalOwner -- Restore

    -- Test serialize
    local serialized = board:serialize()
    T:assertEqual(#serialized, 100, "Serialized board should have 100 cells")
    T:assertNotNil(serialized[1].id, "Serialized cell should have id")
    T:assertNotNil(serialized[1].terrainType, "Serialized cell should have terrainType")

    -- ============================================================
    -- CAPTURE SYSTEM TESTS
    -- ============================================================
    print("\n--- Capture System Tests ---")

    local captureBoard = Board.new(10, MapData)
    -- Set up a simple scenario: Player owns (1,1), neighbor (1,2) has same color
    local cell11 = captureBoard:getCell(1, 1)
    local cell12 = captureBoard:getCell(1, 2)
    cell11.owner = "Player"
    cell12.owner = "Neutral"
    cell12.color = "Red"

    local captured, gained = CaptureSystem:capture(captureBoard, "Player", "Red", MapData)
    T:assertEqual(#captured, 1, "Should capture 1 cell")
    T:assertEqual(cell12.owner, "Player", "Cell (1,2) should be owned by Player after capture")
    T:assertNotNil(gained, "Gained resources should not be nil")

    -- Test invalid color
    local captured2, gained2 = CaptureSystem:capture(captureBoard, "Player", "InvalidColor", MapData)
    T:assertEqual(#captured2, 0, "Invalid color should capture 0 cells")

    -- Test capture on clone doesn't affect original
    local simBoard = captureBoard:clone()
    local simCell11 = simBoard:getCell(1, 1)
    local simCell12 = simBoard:getCell(1, 2)
    simCell11.owner = "Player"
    simCell12.owner = "Neutral"
    simCell12.color = "Blue"
    CaptureSystem:capture(simBoard, "Player", "Blue", MapData)
    -- Original should be unchanged
    T:assertEqual(captureBoard:getCell(1, 2).owner, "Player", "Original should still have (1,2) as Player from previous capture")
    T:assertEqual(simBoard:getCell(1, 2).owner, "Player", "Sim should have (1,2) as Player")

    -- ============================================================
    -- WIN SYSTEM TESTS
    -- ============================================================
    print("\n--- Win System Tests ---")

    local winBoard = Board.new(10, MapData)
    -- All cells owned by Player
    for x = 1, 10 do
        for y = 1, 10 do
            winBoard:getCell(x, y).owner = "Player"
        end
    end
    local won, winner = WinSystem.checkWin(winBoard)
    T:assertEqual(won, true, "Win should be detected when one team owns all cells")
    T:assertEqual(winner, "Player", "Winner should be Player")

    -- Not all cells owned
    winBoard:getCell(5, 5).owner = "AI1"
    local won2, winner2 = WinSystem.checkWin(winBoard)
    T:assertEqual(won2, false, "Win should not be detected when multiple owners exist")

    -- Neutral start cell
    winBoard:getCell(5, 5).owner = "Neutral"
    winBoard:getCell(1, 1).owner = "Neutral"
    local won3, winner3 = WinSystem.checkWin(winBoard)
    T:assertEqual(won3, false, "Win should not be detected when start cell is Neutral")

    -- ============================================================
    -- VALIDATION SYSTEM TESTS
    -- ============================================================
    print("\n--- Validation System Tests ---")

    T:assertEqual(ValidationSystem.validateColor("Red", MapData), true, "Red should be valid color")
    T:assertEqual(ValidationSystem.validateColor("Invalid", MapData), false, "Invalid should not be valid color")
    T:assertEqual(ValidationSystem.validateColor(nil, MapData), false, "Nil should not be valid color")

    T:assertEqual(ValidationSystem.validateMapSize(10, MapData), true, "10 should be valid size")
    T:assertEqual(ValidationSystem.validateMapSize(15, MapData), true, "15 should be valid size")
    T:assertEqual(ValidationSystem.validateMapSize(99, MapData), false, "99 should not be valid size")
    T:assertEqual(ValidationSystem.validateMapSize("10", MapData), false, "String '10' should not be valid size")

    T:assertEqual(ValidationSystem.validateTurn("Player", "Player"), true, "Turn should match")
    T:assertEqual(ValidationSystem.validateTurn("AI1", "Player"), false, "Turn should not match")

    T:assertEqual(ValidationSystem.validateGameActive(true), true, "Active game should be valid")
    T:assertEqual(ValidationSystem.validateGameActive(false), false, "Inactive game should not be valid")

    -- ============================================================
    -- AI SYSTEM TESTS
    -- ============================================================
    print("\n--- AI System Tests ---")

    local gameState = GameState.new(MapData, 10)
    local ai = AIPlayer.new("AI1", "Warlord", "Normal")
    T:assertNotNil(ai, "AI player should be created")
    T:assertEqual(ai.team, "AI1", "AI team should be AI1")

    local color, err = ai:chooseColor(gameState, MapData)
    T:assertNotNil(color, "AI should choose a color: " .. tostring(err))
    T:assertEqual(ValidationSystem.validateColor(color, MapData), true, "AI chosen color should be valid")

    -- Test AI doesn't modify real state during simulation
    local beforeOwner = gameState.board:getCell(1, 1).owner
    ai:chooseColor(gameState, MapData)
    local afterOwner = gameState.board:getCell(1, 1).owner
    T:assertEqual(beforeOwner, afterOwner, "AI simulation should not modify real state")

    -- Test all personalities
    for _, personality in ipairs({"Warlord", "Merchant", "Guardian", "Trickster"}) do
        local aiTest = AIPlayer.new("AI1", personality, "Normal")
        local c, e = aiTest:chooseColor(gameState, MapData)
        T:assertNotNil(c, personality .. " should choose a color: " .. tostring(e))
    end

    -- Test all difficulties
    for _, difficulty in ipairs({"Easy", "Normal", "Hard"}) do
        local aiTest = AIPlayer.new("AI1", "Warlord", difficulty)
        local c, e = aiTest:chooseColor(gameState, MapData)
        T:assertNotNil(c, difficulty .. " should choose a color: " .. tostring(e))
    end

    -- ============================================================
    -- POWER SYSTEM TESTS
    -- ============================================================
    print("\n--- Power System Tests ---")

    local powers = PowerSystem:getAllPowers()
    T:assertEqual(#powers, 6, "Should have 6 powers")
    T:assertNotNil(PowerSystem:getPower("Scout"), "Scout power should exist")
    T:assertEqual(PowerSystem:getPower("Invalid"), nil, "Invalid power should return nil")

    local resources = {Gold = 100, Food = 50, Wood = 50}
    T:assertEqual(PowerSystem:canAfford(resources, "Scout"), true, "Should afford Scout (50 Gold)")
    T:assertEqual(PowerSystem:canAfford(resources, "Shockwave"), false, "Should not afford Shockwave (100 Gold + 50 Food + 50 Wood)")

    local affordable = PowerSystem:applyCost(resources, "Scout")
    T:assertEqual(affordable, true, "Should be able to apply Scout cost")
    T:assertEqual(resources.Gold, 50, "Gold should be 50 after Scout cost")

    T:assertEqual(PowerSystem:isOnCooldown("Scout"), false, "Scout should not be on cooldown initially")
    PowerSystem:activatePower("Scout", nil, {})
    T:assertEqual(PowerSystem:isOnCooldown("Scout"), true, "Scout should be on cooldown after activation")
    T:assertEqual(PowerSystem:getCooldownRemaining("Scout"), 3, "Scout cooldown should be 3 turns")

    PowerSystem:tickCooldowns()
    T:assertEqual(PowerSystem:getCooldownRemaining("Scout"), 2, "Scout cooldown should be 2 after one tick")
    PowerSystem:tickCooldowns()
    PowerSystem:tickCooldowns()
    T:assertEqual(PowerSystem:isOnCooldown("Scout"), false, "Scout cooldown should be expired after 3 ticks")

    -- ============================================================
    -- EVENT SYSTEM TESTS
    -- ============================================================
    print("\n--- Event System Tests ---")

    local events = EventSystem:getAllEvents()
    T:assertEqual(#events, 5, "Should have 5 events")
    T:assertNotNil(EventSystem:getEvent("MeteorShower"), "MeteorShower should exist")

    T:assertEqual(EventSystem:isActive("MeteorShower"), false, "MeteorShower should not be active initially")
    EventSystem:activateEvent("MeteorShower")
    T:assertEqual(EventSystem:isActive("MeteorShower"), true, "MeteorShower should be active")
    T:assertEqual(EventSystem:getRemainingTurns("MeteorShower"), 2, "MeteorShower duration should be 2")

    EventSystem:tickDurations()
    T:assertEqual(EventSystem:getRemainingTurns("MeteorShower"), 1, "MeteorShower should have 1 turn remaining")
    EventSystem:tickDurations()
    T:assertEqual(EventSystem:isActive("MeteorShower"), false, "MeteorShower should be expired")

    -- Test production modifier
    local mod = EventSystem:getProductionModifier("Plains", "Food")
    T:assertEqual(mod, 1.0, "No event should give 1.0 modifier")

    EventSystem:activateEvent("GreatRain")
    local mod2 = EventSystem:getProductionModifier("Plains", "Food")
    T:assertEqual(mod2, 1.3, "GreatRain should give 1.3 modifier for Plains")

    -- ============================================================
    -- MATCH MODIFIER SYSTEM TESTS
    -- ============================================================
    print("\n--- Match Modifier System Tests ---")

    local modifiers = MatchModifierSystem:getAllModifiers()
    T:assertEqual(#modifiers, 5, "Should have 5 modifiers")
    T:assertNotNil(MatchModifierSystem:getModifier("Classic"), "Classic should exist")
    T:assertEqual(MatchModifierSystem:getModifier("Invalid"), nil, "Invalid modifier should return nil")

    MatchModifierSystem:setModifier("RichIslands")
    local current = MatchModifierSystem:getCurrentModifier()
    T:assertEqual(current.name, "RichIslands", "Current modifier should be RichIslands")
    local startingRes = MatchModifierSystem:getStartingResources()
    T:assertEqual(startingRes.Gold, 200, "RichIslands starting Gold should be 200")

    MatchModifierSystem:setModifier("Classic")
    local classicRes = MatchModifierSystem:getStartingResources()
    T:assertEqual(classicRes.Gold, 100, "Classic starting Gold should be 100")

    -- ============================================================
    -- PROGRESSION SYSTEM TESTS
    -- ============================================================
    print("\n--- Progression System Tests ---")

    -- Reset progression data for clean test
    ProgressionSystem.PlayerData.xp = 0
    ProgressionSystem.PlayerData.matchesPlayed = 0
    ProgressionSystem.PlayerData.matchesWon = 0
    ProgressionSystem.PlayerData.achievementsUnlocked = {}
    ProgressionSystem.PlayerData.stats = {
        totalCaptures = 0,
        totalPowersUsed = 0,
        favoritePower = nil,
        longestWinStreak = 0,
        currentWinStreak = 0
    }

    local result = ProgressionSystem:recordMatch(true, 1.0)
    T:assertEqual(result.xpGained, 100, "Win should give 100 XP")
    T:assertEqual(ProgressionSystem.PlayerData.matchesPlayed, 1, "Matches played should be 1")
    T:assertEqual(ProgressionSystem.PlayerData.matchesWon, 1, "Matches won should be 1")

    local rank = ProgressionSystem:getRankForXP(100)
    T:assertEqual(rank.name, "Bronze", "100 XP should be Bronze rank")

    local rank8000 = ProgressionSystem:getRankForXP(8000)
    T:assertEqual(rank8000.name, "Dominion", "8000 XP should be Dominion rank")

    -- Test achievements
    local achievements = ProgressionSystem:checkAchievements()
    T:assertEqual(#achievements >= 0, true, "Achievements check should return a table")

    -- Test addGoldEarned
    ProgressionSystem:addGoldEarned(500)
    T:assertEqual(ProgressionSystem.PlayerData.totalGoldEarned, 500, "Total gold earned should be 500")

    ProgressionSystem:addRelicCollected(3)
    T:assertEqual(ProgressionSystem.PlayerData.totalRelicsCollected, 3, "Total relics collected should be 3")

    ProgressionSystem:recordPowerUsed("Harvest")
    T:assertEqual(ProgressionSystem.PlayerData.stats.totalPowersUsed, 1, "Total powers used should be 1")
    T:assertEqual(ProgressionSystem.PlayerData.stats.favoritePower, "Harvest", "Favorite power should be Harvest")

    -- ============================================================
    -- GAMESTATE CLONE TEST (Critical for AI safety)
    -- ============================================================
    print("\n--- GameState Clone Isolation Tests ---")

    local gs = GameState.new(MapData, 10)
    local gsClone = gs:clone()

    -- Modify original
    gs.teamResources.Player.Gold = 999
    gs.board:getCell(5, 5).owner = "Modified"
    gs.turnManager:advance()

    -- Clone should be unchanged
    T:assertEqual(gsClone.teamResources.Player.Gold, 0, "Clone resources should not reflect original changes")
    T:assertEqual(gsClone.board:getCell(5, 5).owner, "Neutral", "Clone board should not reflect original changes")
    T:assertEqual(gsClone.turnManager.currentTurnIndex, 1, "Clone turn index should not reflect original changes")

    -- ============================================================
    -- FINAL REPORT
    -- ============================================================
    print("\n")
    local allPassed = T:report()

    if allPassed then
        print("✅ ALL TESTS PASSED")
    else
        print("❌ SOME TESTS FAILED - Review before release")
    end

    return allPassed
end

return {
    run = runTests
}