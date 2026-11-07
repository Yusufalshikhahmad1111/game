-- shared/WorldPvP/WorldState.lua
-- Server-independent simulation state for the World PvP pivot.
-- All mutations must be called by the server after validating the player request.

local Rules = require(script.Parent.Rules)

local WorldState = {}
WorldState.__index = WorldState

local function allianceKey(a, b)
    if a < b then
        return tostring(a) .. ":" .. tostring(b)
    end
    return tostring(b) .. ":" .. tostring(a)
end

local function countBuildings(nation, kind)
    local count = 0
    for _, cellId in ipairs(nation.cellIds) do
        local cell = nation.map.cellsById[cellId]
        if cell and cell.building and cell.building.kind == kind then
            count += 1
        end
    end
    return count
end

function WorldState.new(map, options)
    assert(map and type(map.cellsById) == "table", "valid world map required")
    assert((map.totalLand or 0) > 0, "world map needs land")

    local self = setmetatable({}, WorldState)
    self.map = map
    self.options = options or {}
    self.nations = {}
    self.playerNation = {}
    self.attacks = {}
    self.alliances = {}
    self.allianceOffers = {}
    self.nukeCooldowns = {}
    self.clock = 0
    self.nextAttackId = 0
    self.matchOver = false
    self.winnerNationId = nil
    self.totalLand = map.totalLand
    return self
end

function WorldState:addNation(nationId, displayName, cellIds, color)
    assert(type(nationId) == "string" and nationId ~= "", "nationId required")
    assert(not self.nations[nationId], "nation already exists")
    assert(type(cellIds) == "table" and #cellIds > 0, "nation needs starting land")

    local nation = {
        id = nationId,
        name = displayName or nationId,
        color = color or { r = 0.3, g = 0.6, b = 0.9 },
        ownerUserId = nil,
        isAI = true,
        gold = Rules.StartingGold,
        troops = Rules.StartingTroops,
        population = Rules.StartingPopulation,
        cellIds = {},
        eliminated = false,
        score = 0,
    }

    for _, id in ipairs(cellIds) do
        local cell = self.map.cellsById[id]
        assert(cell and cell.isLand, "starting cell must be land: " .. tostring(id))
        assert(cell.ownerId == nil, "starting cell already owned: " .. tostring(id))
        cell.ownerId = nationId
        nation.cellIds[#nation.cellIds + 1] = id
    end

    self.nations[nationId] = nation
    return nation
end

function WorldState:assignPlayer(userId, nationId)
    assert(userId ~= nil, "userId required")
    local nation = self.nations[nationId]
    if not nation then
        return false, "Unknown nation"
    end

    local occupiedBy = self.playerNation[userId]
    if occupiedBy then
        return false, "Player already owns a nation"
    end
    if nation.ownerUserId and nation.ownerUserId ~= userId then
        return false, "Nation already occupied"
    end
    if self.matchOver then
        return false, "Match has ended"
    end

    nation.ownerUserId = userId
    nation.isAI = false
    self.playerNation[userId] = nationId
    return true, nationId
end

function WorldState:getNationForPlayer(userId)
    local nationId = self.playerNation[userId]
    return nationId and self.nations[nationId] or nil
end

function WorldState:getNationLand(nationId)
    local nation = self.nations[nationId]
    return nation and #nation.cellIds or 0
end

function WorldState:getWorldShare(nationId)
    if self.totalLand <= 0 then
        return 0
    end
    return self:getNationLand(nationId) / self.totalLand
end

function WorldState:isAllied(nationA, nationB)
    if not nationA or not nationB or nationA == nationB then
        return false
    end
    return self.alliances[allianceKey(nationA, nationB)] == true
end

function WorldState:isAdjacentToNation(cell, nationId)
    for _, neighborId in ipairs(cell.neighbors) do
        local neighbor = self.map.cellsById[neighborId]
        if neighbor and neighbor.ownerId == nationId then
            return true
        end
    end
    return false
end

function WorldState:attack(userId, targetCellId, troopCount)
    if self.matchOver then
        return false, "Match has ended"
    end

    local attacker = self:getNationForPlayer(userId)
    if not attacker then
        return false, "Player does not own a nation"
    end

    local target = self.map.cellsById[targetCellId]
    if not target or not target.isLand then
        return false, "Invalid land target"
    end
    if target.ownerId == attacker.id then
        return false, "Target already belongs to you"
    end
    if target.ownerId and self:isAllied(attacker.id, target.ownerId) then
        return false, "Cannot attack an ally"
    end
    if not self:isAdjacentToNation(target, attacker.id) then
        return false, "Target is not adjacent to your territory"
    end

    local amount = math.floor(tonumber(troopCount) or 0)
    if amount < Rules.Attack.MinimumTroops then
        return false, "Not enough troops committed"
    end
    if amount > attacker.troops then
        return false, "Not enough reserve troops"
    end

    attacker.troops -= amount
    self.nextAttackId += 1
    local attack = {
        id = self.nextAttackId,
        attackerNationId = attacker.id,
        defenderNationId = target.ownerId,
        targetCellId = target.id,
        troopCount = amount,
        resolvesAt = self.clock + Rules.Attack.TravelSeconds,
    }
    self.attacks[#self.attacks + 1] = attack
    return true, attack.id
end

function WorldState:build(userId, cellId, buildingKind)
    if self.matchOver then
        return false, "Match has ended"
    end

    local nation = self:getNationForPlayer(userId)
    if not nation then
        return false, "Player does not own a nation"
    end

    local cell = self.map.cellsById[cellId]
    local definition = Rules.Buildings[buildingKind]
    if not cell or not cell.isLand then
        return false, "Invalid building location"
    end
    if cell.ownerId ~= nation.id then
        return false, "You do not own this land"
    end
    if cell.building then
        return false, "A building already exists here"
    end
    if not definition then
        return false, "Unknown building"
    end
    if definition.RequiresCoast and not cell.isCoastal then
        return false, "This building requires a coastal tile"
    end
    if nation.gold < definition.Cost then
        return false, "Insufficient gold"
    end

    nation.gold -= definition.Cost
    cell.building = {
        kind = buildingKind,
        level = 1,
        health = 100,
    }
    return true, cell.building
end

function WorldState:proposeAlliance(fromUserId, toUserId)
    local fromNation = self:getNationForPlayer(fromUserId)
    local toNation = self:getNationForPlayer(toUserId)
    if not fromNation or not toNation or fromNation.id == toNation.id then
        return false, "Invalid alliance target"
    end
    if self:isAllied(fromNation.id, toNation.id) then
        return false, "Already allied"
    end

    local key = allianceKey(fromNation.id, toNation.id)
    self.allianceOffers[key] = {
        fromNationId = fromNation.id,
        toNationId = toNation.id,
        expiresAt = self.clock + Rules.Alliance.OfferLifetimeSeconds,
    }
    return true
end

function WorldState:respondAlliance(userId, accept)
    local nation = self:getNationForPlayer(userId)
    if not nation then
        return false, "Player does not own a nation"
    end

    for key, offer in pairs(self.allianceOffers) do
        if offer.toNationId == nation.id and offer.expiresAt >= self.clock then
            if accept == true then
                self.alliances[key] = true
            end
            self.allianceOffers[key] = nil
            return true
        end
    end
    return false, "No pending alliance offer"
end

function WorldState:launchNuke(userId, targetCellId)
    if self.matchOver then
        return false, "Match has ended"
    end

    local nation = self:getNationForPlayer(userId)
    local target = self.map.cellsById[targetCellId]
    if not nation then
        return false, "Player does not own a nation"
    end
    if not target or not target.isLand then
        return false, "Invalid strike location"
    end
    if countBuildings(nation, "MissileSilo") < 1 then
        return false, "A missile silo is required"
    end
    if self.nukeCooldowns[nation.id] and self.nukeCooldowns[nation.id] > self.clock then
        return false, "Nuclear launch is on cooldown"
    end
    if nation.gold < Rules.Nuke.Cost then
        return false, "Insufficient gold"
    end

    nation.gold -= Rules.Nuke.Cost
    self.nukeCooldowns[nation.id] = self.clock + Rules.Nuke.CooldownSeconds

    local affected = {}
    for _, cell in ipairs(self.map.cells) do
        local distance = math.abs(cell.x - target.x) + math.abs(cell.y - target.y)
        if cell.isLand and distance <= Rules.Nuke.Radius then
            if cell.ownerId then
                local victim = self.nations[cell.ownerId]
                if victim then
                    for index = #victim.cellIds, 1, -1 do
                        if victim.cellIds[index] == cell.id then
                            table.remove(victim.cellIds, index)
                            break
                        end
                    end
                    victim.troops = math.max(0, math.floor(victim.troops * (1 - Rules.Nuke.TroopLoss)))
                end
            end
            cell.ownerId = nil
            cell.building = nil
            affected[#affected + 1] = cell.id
        end
    end

    return true, affected
end

function WorldState:_resolveAttack(attack)
    local attacker = self.nations[attack.attackerNationId]
    local defender = attack.defenderNationId and self.nations[attack.defenderNationId] or nil
    local target = self.map.cellsById[attack.targetCellId]

    if not attacker or not target or not target.isLand then
        return { type = "AttackCancelled", attackId = attack.id }
    end
    if target.ownerId ~= attack.defenderNationId then
        attacker.troops += math.floor(attack.troopCount * 0.8)
        return { type = "AttackCancelled", attackId = attack.id }
    end
    if defender and self:isAllied(attacker.id, defender.id) then
        attacker.troops += attack.troopCount
        return { type = "AttackCancelled", attackId = attack.id }
    end
    if not self:isAdjacentToNation(target, attacker.id) then
        attacker.troops += math.floor(attack.troopCount * 0.8)
        return { type = "AttackCancelled", attackId = attack.id }
    end

    local defenseMultiplier = 1
    if target.building and target.building.kind == "DefensePost" then
        defenseMultiplier = Rules.Buildings.DefensePost.DefenseMultiplier
    end
    local defense = defender and defender.troops * 0.08 or 0
    local attackPower = attack.troopCount
    local won = attackPower >= math.max(250, defense * defenseMultiplier) * Rules.Attack.WinRatio

    if won then
        if defender then
            for index = #defender.cellIds, 1, -1 do
                if defender.cellIds[index] == target.id then
                    table.remove(defender.cellIds, index)
                    break
                end
            end
            defender.eliminated = #defender.cellIds == 0
        end

        target.ownerId = attacker.id
        target.building = nil
        attacker.cellIds[#attacker.cellIds + 1] = target.id
        attacker.troops += math.floor(attack.troopCount * (1 - Rules.Attack.AttackerLossOnWin))
        attacker.score += 1
        return { type = "TerritoryCaptured", attackId = attack.id, cellId = target.id, nationId = attacker.id }
    end

    attacker.troops += math.floor(attack.troopCount * (1 - Rules.Attack.AttackerLossOnFail))
    return { type = "AttackRepelled", attackId = attack.id, cellId = target.id }
end

function WorldState:getWinner()
    for nationId, nation in pairs(self.nations) do
        if #nation.cellIds > 0 and self:getWorldShare(nationId) >= Rules.TargetWorldShare then
            return nationId
        end
    end
    return nil
end

function WorldState:tick(deltaSeconds)
    local dt = math.max(0, tonumber(deltaSeconds) or Rules.TickSeconds)
    self.clock += dt
    local events = {}

    for _, nation in pairs(self.nations) do
        if #nation.cellIds > 0 then
            local cities = countBuildings(nation, "City")
            local factories = countBuildings(nation, "Factory")
            nation.gold += math.floor((Rules.BaseGoldPerTick + cities * Rules.Buildings.City.GoldPerTick + factories * Rules.Buildings.Factory.GoldPerTick) * dt)
            local troopIncome = (Rules.BaseTroopsPerTick + cities * Rules.Buildings.City.TroopsPerTick) * dt
            local troopCap = Rules.StartingTroops + cities * Rules.Buildings.City.PopulationCapacity
            nation.troops = math.min(troopCap, nation.troops + math.floor(troopIncome))
            nation.population += math.floor((50 + cities * 100) * dt)
        end
    end

    for key, offer in pairs(self.allianceOffers) do
        if offer.expiresAt < self.clock then
            self.allianceOffers[key] = nil
            events[#events + 1] = { type = "AllianceOfferExpired", key = key }
        end
    end

    for index = #self.attacks, 1, -1 do
        local attack = self.attacks[index]
        if attack.resolvesAt <= self.clock then
            events[#events + 1] = self:_resolveAttack(attack)
            table.remove(self.attacks, index)
        end
    end

    local winner = self:getWinner()
    if winner then
        self.matchOver = true
        self.winnerNationId = winner
        events[#events + 1] = { type = "MatchWon", nationId = winner }
    end

    return events
end

function WorldState:getSnapshot()
    local cells = {}
    for _, cell in ipairs(self.map.cells) do
        cells[#cells + 1] = {
            id = cell.id,
            x = cell.x,
            y = cell.y,
            isLand = cell.isLand,
            isCoastal = cell.isCoastal,
            ownerId = cell.ownerId,
            building = cell.building and {
                kind = cell.building.kind,
                level = cell.building.level,
                health = cell.building.health,
            } or nil,
        }
    end

    local nations = {}
    for nationId, nation in pairs(self.nations) do
        nations[#nations + 1] = {
            id = nationId,
            name = nation.name,
            color = nation.color,
            ownerUserId = nation.ownerUserId,
            isAI = nation.isAI,
            gold = nation.gold,
            troops = nation.troops,
            population = nation.population,
            land = #nation.cellIds,
            worldShare = self:getWorldShare(nationId),
            eliminated = nation.eliminated,
            score = nation.score,
        }
    end

    return {
        width = self.map.width,
        height = self.map.height,
        cells = cells,
        nations = nations,
        matchOver = self.matchOver,
        winnerNationId = self.winnerNationId,
        serverTime = self.clock,
    }
end

return WorldState
