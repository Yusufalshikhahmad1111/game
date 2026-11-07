-- tests/WorldPvPTests.lua
-- Run in Roblox Studio from a server context:
-- require(game.ServerStorage.Tests.WorldPvPTests):run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldMap = require(ReplicatedStorage.Shared.WorldPvP.WorldMap)
local WorldState = require(ReplicatedStorage.Shared.WorldPvP.WorldState)

local Tests = {}

local function expect(condition, message)
    if not condition then
        error("WorldPvP test failed: " .. message, 2)
    end
end

function Tests:run()
    local map = WorldMap.fromRows({
        "#######",
        "#######",
        "#######",
        "#######",
        "#######",
    })

    local state = WorldState.new(map)
    state:addNation("A", "North", { "02_02" }, { r = 0.1, g = 0.5, b = 1 })
    state:addNation("B", "South", { "02_03" }, { r = 1, g = 0.2, b = 0.2 })

    local joinedA, errA = state:assignPlayer(101, "A")
    expect(joinedA, "player A should be assigned: " .. tostring(errA))

    local joinedB, errB = state:assignPlayer(202, "B")
    expect(joinedB, "player B should be assigned: " .. tostring(errB))

    local occupied, occupiedError = state:assignPlayer(303, "A")
    expect(not occupied and occupiedError == "Nation already occupied", "occupied nation must reject another player")

    local attackOk, attackId = state:attack(101, "02_03", 5000)
    expect(attackOk and attackId == 1, "adjacent attack should be accepted")

    local events = state:tick(4)
    expect(#events > 0, "attack resolution should emit an event")
    expect(map.cellsById["02_03"].ownerId == "A", "successful attack should transfer target land")

    local buildOk, building = state:build(101, "02_02", "City")
    expect(buildOk and building.kind == "City", "city should be buildable on owned land")

    local invalidPort, portError = state:build(101, "03_02", "Port")
    expect(not invalidPort and portError == "You do not own this land", "building on foreign land must fail")

    local snapshot = state:getSnapshot()
    expect(snapshot.width == 7 and snapshot.height == 5, "snapshot should preserve map dimensions")
    expect(#snapshot.cells == 35, "snapshot should include every map cell")

    return {
        passed = 8,
        failed = 0,
        message = "World PvP simulation smoke tests passed",
    }
end

return Tests
