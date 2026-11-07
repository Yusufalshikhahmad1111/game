-- shared/WorldPvP/WorldState.lua
-- Server-authoritative simulation for the World PvP pivot.

local Rules = require(script.Parent.Rules)
local CountryMapData = require(script.Parent.CountryMapData)

local WorldState = {}
WorldState.__index = WorldState

local function allianceKey(a, b)
    a, b = tostring(a), tostring(b)
    return a < b and a .. ":" .. b or b .. ":" .. a
end

local function removeValue(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function countBuildings(self, nation, kind)
    local count = 0
    for _, cellId in ipairs(nation.cellIds) do
        local cell = self.map.cellsById[cellId]
        if cell and cell.building and cell.building.kind == kind then
            count += 1
        end
    end
    return count
end

function WorldState.new(map)
    assert(map and map.cellsById and map.totalLand > 0, "valid map required")
    local self = setmetatable({}, WorldState)
    self.map = map
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
    self.countryMode = true
    self.countryById = {}
    self.countryOwners = {}
    return self
end

function WorldState:addNation(id, name, cellIds, color, category)
    assert(not self.nations[id], "nation already exists")
    local isTribe = category == "Tribe"
    local nation = {
        id = id, name = name or id, category = category or "Nation",
        color = color or {r=.3,g=.6,b=.9}, ownerUserId = nil, isAI = true,
        gold = isTribe and Rules.TribeStartingGold or Rules.StartingGold,
        troops = isTribe and Rules.TribeStartingTroops or Rules.StartingTroops,
        population = isTribe and Rules.TribeStartingPopulation or Rules.StartingPopulation,
        cellIds = {}, eliminated = false, score = 0,
    }
    for _, idValue in ipairs(cellIds) do
        local cell = self.map.cellsById[idValue]
        assert(cell and cell.isLand and not cell.ownerId, "invalid/occupied starting cell")
        cell.ownerId = id
        nation.cellIds[#nation.cellIds+1] = idValue
    end
    self.nations[id] = nation
    return nation
end

function WorldState:assignPlayer(userId, nationId)
    if self.matchOver then return false, "Match has ended" end
    if self.playerNation[userId] then return false, "Player already owns a nation" end
    local nation = self.nations[nationId]
    if not nation then return false, "Unknown nation" end
    if nation.ownerUserId then return false, "Nation already occupied" end
    if nation.category ~= "Nation" then return false, "Tribes cannot be selected" end
    nation.ownerUserId, nation.isAI = userId, false
    self.playerNation[userId] = nationId
    return true, nation
end


function WorldState:addCountryNation(countryId, color, category)
    local country = CountryMapData.get(countryId)
    assert(country, "unknown country")
    local nation = self.nations[countryId]
    if nation then return nation end
    local isTribe = category == "Tribe"
    nation = {
        id=countryId, name=country.name, category=category or "Nation",
        color=color or {r=.3,g=.6,b=.9}, ownerUserId=nil, isAI=true,
        gold=isTribe and Rules.TribeStartingGold or Rules.StartingGold,
        troops=isTribe and Rules.TribeStartingTroops or Rules.StartingTroops,
        population=isTribe and Rules.TribeStartingPopulation or Rules.StartingPopulation,
        cellIds={}, countryId=countryId, neighbors=country.neighbors, eliminated=false, score=0,
    }
    self.nations[countryId]=nation
    self.countryById[countryId]=nation
    self.countryOwners[countryId]=countryId
    return nation
end

function WorldState:assignPlayerCountry(userId, countryId)
    if self.matchOver then return false, "Match has ended" end
    if self.playerNation[userId] then return false, "Player already owns a country" end
    local nation=self.nations[countryId]
    if not nation then return false, "Unknown country" end
    if nation.ownerUserId then return false, "Country already occupied" end
    if nation.category~="Nation" then return false, "This territory is AI controlled" end
    nation.ownerUserId=userId
    nation.isAI=false
    nation.displayName = nil
    self.playerNation[userId]=countryId
    return true,nation
end

function WorldState:countryIsAdjacent(attackerId,targetId)
    local target=CountryMapData.get(targetId)
    if not target then return false end
    for _,neighborId in ipairs(target.neighbors or {}) do
        if self.countryOwners[neighborId]==attackerId then return true end
    end
    return false
end

function WorldState:attackCountry(userId,targetId,troopCount)
    local attacker=self:getNationForPlayer(userId)
    if not attacker then return false,"Player does not own a country" end
    local target=self.nations[targetId]
    if not target then return false,"Unknown target country" end
    if self.countryOwners[targetId]==attacker.id then return false,"That is already your territory" end
    if not self:countryIsAdjacent(attacker.id,targetId) then return false,"You can only attack a neighboring country" end
    local defenderOwner=self.countryOwners[targetId]
    if defenderOwner and self:isAllied(attacker.id,defenderOwner) then return false,"You cannot attack an ally" end
    local amount=math.floor(tonumber(troopCount) or 0)
    if amount<Rules.Attack.MinimumTroops or amount>attacker.troops then return false,"Invalid troop amount" end
    attacker.troops-=amount
    self.nextAttackId+=1
    self.attacks[#self.attacks+1]={id=self.nextAttackId,attackerNationId=attacker.id,defenderNationId=self.countryOwners[targetId],targetCountryId=target.id,troopCount=amount,naval=false,resolvesAt=self.clock+Rules.Attack.TravelSeconds}
    return true,self.nextAttackId
end

function WorldState:_resolveCountryAttack(a)
    local attacker=self.nations[a.attackerNationId]
    local defenderOwner=a.defenderNationId and self.nations[a.defenderNationId] or nil
    local targetId=a.targetCountryId
    if not attacker or not targetId or not self.nations[targetId] then
        return {type="AttackCancelled",attackId=a.id}
    end
    local defender=defenderOwner
    local defense=defender and math.max(250,defender.troops*Rules.Attack.DefenderTroopFactor) or Rules.Attack.NeutralDefense
    local won=a.troopCount>=defense*Rules.Attack.WinRatio
    if not won then
        attacker.troops+=math.floor(a.troopCount*(1-Rules.Attack.AttackerLossOnFail))
        if defender then defender.troops=math.max(0,defender.troops-math.floor(a.troopCount*.1)) end
        return {type="AttackRepelled",attackId=a.id,countryId=targetId}
    end
    self.countryOwners[targetId]=attacker.id
    if defender and defender.id~=attacker.id then
        defender.score=math.max(0,defender.score)
    end
    attacker.troops+=math.floor(a.troopCount*(1-Rules.Attack.AttackerLossOnWin))
    attacker.score+=1
    attacker.gold+=25000
    return {type="CountryCaptured",attackId=a.id,countryId=targetId,nationId=attacker.id}
end

function WorldState:getNationForPlayer(userId)
    local id = self.playerNation[userId]
    return id and self.nations[id] or nil
end

function WorldState:getNationLand(id)
    local count=0
    for _,ownerId in pairs(self.countryOwners) do if ownerId==id then count+=1 end end
    return count
end

function WorldState:getWorldShare(id)
    local total=0
    local owned=0
    for countryId,ownerId in pairs(self.countryOwners) do
        local country=CountryMapData.get(countryId)
        if country then
            total+=math.max(1,country.area)
            if ownerId==id then owned+=math.max(1,country.area) end
        end
    end
    return total>0 and owned/total or 0
end

function WorldState:isAllied(a,b)
    return a and b and a ~= b and self.alliances[allianceKey(a,b)] == true
end

function WorldState:isAdjacentToNation(cell, nationId)
    for _, neighborId in ipairs(cell.neighbors) do
        local neighbor = self.map.cellsById[neighborId]
        if neighbor and neighbor.ownerId == nationId then return true end
    end
    return false
end

function WorldState:findAttackTargets(nationId)
    local result, seen = {}, {}
    local nation = self.nations[nationId]
    if not nation then return result end
    for _, cellId in ipairs(nation.cellIds) do
        local cell = self.map.cellsById[cellId]
        for _, neighborId in ipairs(cell.neighbors) do
            local target = self.map.cellsById[neighborId]
            if target and target.isLand and target.ownerId ~= nationId
                and not self:isAllied(nationId, target.ownerId)
                and not seen[target.id] then
                seen[target.id] = true
                result[#result+1] = target.id
            end
        end
    end
    return result
end

function WorldState:attack(userId, targetCellId, troopCount)
    local attacker = self:getNationForPlayer(userId)
    if not attacker then return false, "Player does not own a nation" end
    return self:queueAttack(attacker.id, targetCellId, troopCount, false)
end

function WorldState:queueAttack(nationId, targetCellId, troopCount, naval)
    if self.matchOver then return false, "Match has ended" end
    local attacker = self.nations[nationId]
    local target = self.map.cellsById[targetCellId]
    if not attacker or #attacker.cellIds == 0 then return false, "Nation is eliminated" end
    if not target or not target.isLand then return false, "Invalid land target" end
    if target.ownerId == nationId then return false, "Target already belongs to you" end
    if target.ownerId and self:isAllied(nationId, target.ownerId) then return false, "Cannot attack an ally" end

    local adjacent = self:isAdjacentToNation(target, nationId)
    if not adjacent and not naval then return false, "Target is not adjacent to your territory" end
    if naval and countBuildings(self, attacker, "Port") < 1 then return false, "A port is required for naval attacks" end

    local amount = math.floor(tonumber(troopCount) or 0)
    if amount < Rules.Attack.MinimumTroops or amount > attacker.troops then
        return false, "Invalid troop amount"
    end

    if naval then
        if attacker.gold < Rules.Attack.NavalGoldCost then return false, "Insufficient gold for naval transport" end
        attacker.gold -= Rules.Attack.NavalGoldCost
    end

    attacker.troops -= amount
    self.nextAttackId += 1
    self.attacks[#self.attacks+1] = {
        id=self.nextAttackId, attackerNationId=nationId,
        defenderNationId=target.ownerId, targetCellId=target.id,
        troopCount=amount, naval=naval,
        resolvesAt=self.clock + (naval and Rules.Attack.NavalTravelSeconds or Rules.Attack.TravelSeconds)
    }
    return true, self.nextAttackId
end

function WorldState:build(userId, cellId, kind)
    local nation = self:getNationForPlayer(userId)
    if not nation then return false, "Player does not own a nation" end
    local cell, def = self.map.cellsById[cellId], Rules.Buildings[kind]
    if not cell or not cell.isLand then return false, "Invalid building location" end
    if cell.ownerId ~= nation.id then return false, "You do not own this land" end
    if cell.building then return false, "A building already exists here" end
    if not def then return false, "Unknown building" end
    if def.RequiresCoast and not cell.isCoastal then return false, "This building requires a coast" end
    if nation.gold < def.Cost then return false, "Insufficient gold" end
    nation.gold -= def.Cost
    cell.building = {kind=kind, level=1, health=100}
    return true, cell.building
end

function WorldState:proposeAlliance(fromUserId, toUserId)
    local a,b=self:getNationForPlayer(fromUserId),self:getNationForPlayer(toUserId)
    if not a or not b or a.id==b.id then return false,"Invalid alliance target" end
    if self:isAllied(a.id,b.id) then return false,"Already allied" end
    self.allianceOffers[allianceKey(a.id,b.id)]={fromNationId=a.id,toNationId=b.id,expiresAt=self.clock+Rules.Alliance.OfferLifetimeSeconds}
    return true
end

function WorldState:respondAlliance(userId, accept)
    local n=self:getNationForPlayer(userId)
    if not n then return false,"Player does not own a nation" end
    for key,offer in pairs(self.allianceOffers) do
        if offer.toNationId==n.id and offer.expiresAt>=self.clock then
            if accept then self.alliances[key]=true end
            self.allianceOffers[key]=nil
            return true
        end
    end
    return false,"No pending alliance offer"
end

function WorldState:launchNuke(userId,targetCellId)
    local n=self:getNationForPlayer(userId)
    local target=self.map.cellsById[targetCellId]
    if not n then return false,"Player does not own a nation" end
    if not target or not target.isLand then return false,"Invalid strike location" end
    if countBuildings(self,n,"MissileSilo")<1 then return false,"A missile silo is required" end
    if self.nukeCooldowns[n.id] and self.nukeCooldowns[n.id]>self.clock then return false,"Nuclear launch is on cooldown" end
    if n.gold<Rules.Nuke.Cost then return false,"Insufficient gold" end
    n.gold-=Rules.Nuke.Cost
    self.nukeCooldowns[n.id]=self.clock+Rules.Nuke.CooldownSeconds
    local affected={}
    for _,cell in ipairs(self.map.cells) do
        local distance=math.abs(cell.x-target.x)+math.abs(cell.y-target.y)
        if cell.isLand and distance<=Rules.Nuke.Radius then
            local victim=cell.ownerId and self.nations[cell.ownerId]
            if victim then
                removeValue(victim.cellIds,cell.id)
                victim.troops=math.max(0,math.floor(victim.troops*(1-Rules.Nuke.TroopLoss)))
                if #victim.cellIds==0 then victim.eliminated=true end
            end
            cell.ownerId=nil
            cell.building=nil
            affected[#affected+1]=cell.id
        end
    end
    return true,affected
end

function WorldState:_resolveAttack(a)
    if a.targetCountryId then return self:_resolveCountryAttack(a) end
    local attacker=self.nations[a.attackerNationId]
    local defender=a.defenderNationId and self.nations[a.defenderNationId] or nil
    local target=self.map.cellsById[a.targetCellId]
    if not attacker or not target then return {type="AttackCancelled",attackId=a.id} end
    if target.ownerId~=a.defenderNationId then
        attacker.troops+=math.floor(a.troopCount*.8)
        return {type="AttackCancelled",attackId=a.id}
    end
    local defense=defender and defender.troops*Rules.Attack.DefenderTroopFactor or Rules.Attack.NeutralDefense
    if target.building and target.building.kind=="DefensePost" then defense*=Rules.Buildings.DefensePost.DefenseMultiplier end
    if a.naval and target.building and target.building.kind=="SAM" then
        defense*=1.45
    end
    local won=a.troopCount>=math.max(250,defense)*Rules.Attack.WinRatio
    if not won then
        attacker.troops+=math.floor(a.troopCount*(1-Rules.Attack.AttackerLossOnFail))
        return {type="AttackRepelled",attackId=a.id,cellId=target.id}
    end
    if defender then
        removeValue(defender.cellIds,target.id)
        defender.eliminated=#defender.cellIds==0
    end
    target.ownerId=attacker.id
    target.building=nil
    attacker.cellIds[#attacker.cellIds+1]=target.id
    attacker.troops+=math.floor(a.troopCount*(1-Rules.Attack.AttackerLossOnWin))
    attacker.score+=1
    return {type="TerritoryCaptured",attackId=a.id,cellId=target.id,nationId=attacker.id}
end

function WorldState:getWinner()
    for id,n in pairs(self.nations) do
        if n.category=="Nation" and self:getNationLand(id)>0 and self:getWorldShare(id)>=Rules.TargetWorldShare then return id end
    end
end

function WorldState:tick(dt)
    dt=math.clamp(tonumber(dt) or 1,0,2)
    self.clock+=dt
    local events={}
    for _,n in pairs(self.nations) do
        local active = self.countryMode and self:getNationLand(n.id)>0 or #n.cellIds>0
        if active then
            local cities=self.countryMode and 0 or countBuildings(self,n,"City")
            local factories=self.countryMode and 0 or countBuildings(self,n,"Factory")
            local ports=self.countryMode and 0 or countBuildings(self,n,"Port")
            n.gold+=math.floor((Rules.BaseGoldPerTick+cities*Rules.Buildings.City.GoldPerTick+factories*Rules.Buildings.Factory.GoldPerTick+ports*Rules.Buildings.Port.GoldPerTick)*dt)
            local cap=Rules.StartingTroops+cities*Rules.Buildings.City.PopulationCapacity
            n.troops=math.min(cap,n.troops+math.floor((Rules.BaseTroopsPerTick+cities*Rules.Buildings.City.TroopsPerTick)*dt))
            n.population+=math.floor((Rules.BasePopulationPerTick+cities*100)*dt)
        end
    end
    for key,o in pairs(self.allianceOffers) do
        if o.expiresAt<self.clock then self.allianceOffers[key]=nil end
    end
    for i=#self.attacks,1,-1 do
        if self.attacks[i].resolvesAt<=self.clock then
            events[#events+1]=self:_resolveAttack(self.attacks[i])
            table.remove(self.attacks,i)
        end
    end
    local winner=self:getWinner()
    if winner then
        self.matchOver=true
        self.winnerNationId=winner
        events[#events+1]={type="MatchWon",nationId=winner}
    end
    return events
end

function WorldState:getCountrySnapshot()
    local countries={}
    for _,country in ipairs(CountryMapData.Countries) do
        local n=self.nations[country.id]
        local ownerId=self.countryOwners[country.id]
        local owner=self.nations[ownerId]
        countries[#countries+1]={id=country.id,name=country.name,continent=country.continent,center=country.center,bbox=country.bbox,neighbors=country.neighbors,ownerNationId=ownerId,ownerUserId=owner and owner.ownerUserId or nil,ownerName=owner and (owner.displayName or owner.name) or nil,isAI=owner and owner.isAI or true,category=owner and owner.category or "Nation",color=owner and owner.color or {r=.22,g=.32,b=.40},gold=owner and owner.gold or 0,troops=owner and owner.troops or 0,population=owner and owner.population or 0,score=owner and owner.score or 0}
    end
    return {countries=countries,matchOver=self.matchOver,winnerNationId=self.winnerNationId,serverTime=self.clock}
end

function WorldState:getSnapshot()
    local cells={}
    for _,c in ipairs(self.map.cells) do
        cells[#cells+1]={id=c.id,x=c.x,y=c.y,isLand=c.isLand,isCoastal=c.isCoastal,ownerId=c.ownerId,building=c.building and {kind=c.building.kind,level=c.building.level,health=c.building.health} or nil}
    end
    local nations={}
    for id,n in pairs(self.nations) do
        nations[#nations+1]={id=id,name=n.name,category=n.category,color=n.color,ownerUserId=n.ownerUserId,isAI=n.isAI,gold=n.gold,troops=n.troops,population=n.population,land=#n.cellIds,worldShare=self:getWorldShare(id),eliminated=n.eliminated,score=n.score}
    end
    return {width=self.map.width,height=self.map.height,cells=cells,nations=nations,matchOver=self.matchOver,winnerNationId=self.winnerNationId,serverTime=self.clock}
end

return WorldState