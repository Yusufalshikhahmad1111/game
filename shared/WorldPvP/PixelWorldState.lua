-- Server-authoritative high-resolution pixel world simulation.
local Rules=require(script.Parent.Rules)
local TileMap=require(script.Parent.TileMap)
local CountryMapData=require(script.Parent.CountryMapData)
local State={}
State.__index=State

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function allianceKey(a,b)
    a=tostring(a);b=tostring(b)
    if a<b then return a.."|"..b end
    return b.."|"..a
end
local function terrainSpec(terrain)
    if terrain=="Forest" then return Rules.Attack.Forest end
    if terrain=="Highland" then return Rules.Attack.Highland end
    if terrain=="Mountain" then return Rules.Attack.Mountain end
    return Rules.Attack.Plains
end

function State.new()
    local self=setmetatable({},State)
    self.map=TileMap.build()
    self.players={};self.byUser={};self.ownerIds={};self.ownerIndexById={}
    self.attacks={};self.nextAttack=0;self.time=0
    self.matchId="world_"..tostring(os.time())
    self.alliances={};self.allianceRequests={}
    self.dirtyTiles={};self.buildingTiles={};self.winner=nil
    self:_seedAI()
    table.clear(self.dirtyTiles)
    return self
end

function State:_newNation(id,name,isAI,kind,color)
    local kinds={}
    for key in pairs(Rules.Buildings) do kinds[key]=0 end
    local levels={}
    for key in pairs(Rules.Buildings) do levels[key]=0 end
    local n={
        id=id,name=name,isAI=isAI,kind=kind or "Nation",color=color,
        troops=isAI and (kind=="Tribe" and Rules.TribeStartingTroops or Rules.NationStartingTroops) or Rules.HumanStartingTroops,
        gold=isAI and Rules.BotStartingGold or Rules.HumanStartingGold,
        owned=0,alive=true,coast=false,userId=nil,displayName=nil,
        kills=0,attacks=0,nukes=0,tileIds={},tileIndex={},
        centerXSum=0,centerYSum=0,buildings=kinds,buildingLevels=levels,
        protectedUntil=0,
    }
    n.ownerIndex=#self.ownerIds+1
    self.ownerIds[n.ownerIndex]=id
    self.ownerIndexById[id]=n.ownerIndex
    self.players[id]=n
    return n
end

function State:_markDirty(id)
    if id then self.dirtyTiles[id]=true end
end

function State:_addTile(n,t)
    if n.tileIndex[t.id] then return end
    local index=#n.tileIds+1
    n.tileIds[index]=t.id;n.tileIndex[t.id]=index
    n.owned+=1;n.centerXSum+=t.x;n.centerYSum+=t.y
    if t.isCoastal then n.coast=true end
end

function State:_removeTile(n,t)
    local index=n.tileIndex[t.id]
    if not index then return end
    local lastIndex=#n.tileIds
    local lastId=n.tileIds[lastIndex]
    n.tileIds[index]=lastId;n.tileIds[lastIndex]=nil
    n.tileIndex[t.id]=nil
    if lastId and lastId~=t.id then n.tileIndex[lastId]=index end
    n.owned=math.max(0,n.owned-1)
    n.centerXSum-=t.x;n.centerYSum-=t.y
end

function State:_seedAI()
    local palette={
        {0.86,0.22,0.20},{0.20,0.48,0.90},{0.18,0.70,0.38},{0.92,0.60,0.16},
        {0.64,0.32,0.84},{0.12,0.66,0.76},{0.88,0.32,0.54},{0.46,0.56,0.24},
        {0.96,0.43,0.25},{0.28,0.73,0.80},
    }
    local ids={}
    for _,country in ipairs(CountryMapData.Countries) do ids[#ids+1]=country.id end
    local used={}
    for i=1,math.min(Rules.AI.NationCount,#ids) do
        local countryId=ids[((i-1)*2)%#ids+1]
        if not used[countryId] then
            used[countryId]=true
            local n=self:_newNation("AI_N"..i,countryId,true,"Nation",palette[((i-1)%#palette)+1])
            local center=self.map:countryCenterTile(countryId)
            if center then self:_claimSpawn(n,center,Rules.NationSpawnRadius) end
        end
    end
    local tribeIndex=0
    for _,country in ipairs(CountryMapData.Countries) do
        if tribeIndex>=Rules.AI.TribeCount then break end
        local center=self.map:countryCenterTile(country.id)
        local tile=center and self.map:get(center)
        if tile and tile.ownerId==0 then
            tribeIndex+=1
            local n=self:_newNation("AI_T"..tribeIndex,"Tribe "..tostring(tribeIndex),true,"Tribe",palette[((tribeIndex+4)%#palette)+1])
            self:_claimSpawn(n,center,Rules.TribeSpawnRadius)
        end
    end
end

function State:_claimSpawn(n,centerId,radius)
    local ids=self.map:findSpawnTiles(centerId,radius)
    for _,id in ipairs(ids) do
        local t=self.map:get(id)
        if t and t.isLand and t.ownerId==0 then
            t.ownerId=n.id;self:_addTile(n,t);self:_markDirty(id)
        end
    end
    return n.owned>0
end

function State:spawnHuman(userId,displayName,tileId)
    if self.byUser[userId] then return false,"You already deployed" end
    local activeHumans=0
    for _,n in pairs(self.players) do if n.userId then activeHumans+=1 end end
    if activeHumans>=Rules.MaxPlayers then return false,"World is full" end
    tileId=math.floor(tonumber(tileId) or 0)
    local tile=self.map:get(tileId)
    if not tile or not tile.isLand or tile.ownerId~=0 then return false,"Choose free land" end

    local id="P_"..tostring(userId)
    local n=self:_newNation(id,displayName,false,"Nation",{0.18,0.72,0.98})
    n.userId=userId;n.displayName=displayName
    n.protectedUntil=self.time+Rules.ProtectionSeconds
    if not self:_claimSpawn(n,tileId,Rules.SpawnRadius) then
        self.players[id]=nil;self.ownerIndexById[id]=nil
        table.remove(self.ownerIds,n.ownerIndex)
        return false,"Spawn location unavailable"
    end
    self.byUser[userId]=n
    return true,n
end

function State:_borderTiles(n)
    local result={}
    for _,id in ipairs(n.tileIds) do
        local t=self.map:get(id)
        if t and t.ownerId==n.id then
            for _,neighborId in ipairs(t.neighbors or {}) do
                local other=self.map:get(neighborId)
                if other and other.ownerId~=n.id then result[#result+1]=id;break end
            end
        end
    end
    return result
end

function State:_hasLandNeighbor(n,target)
    for _,id in ipairs(target.neighbors or {}) do
        local t=self.map:get(id)
        if t and t.ownerId==n.id then return true end
    end
    return false
end

function State:_nearestOwnedCoast(n,target)
    local best,bestDistance=nil,math.huge
    for _,id in ipairs(n.tileIds) do
        local t=self.map:get(id)
        if t and t.ownerId==n.id and t.isCoastal then
            local dx=math.abs(t.x-target.x)
            dx=math.min(dx,self.map.width-dx)
            local dy=t.y-target.y
            local d=dx*dx+dy*dy
            if d<bestDistance then best,bestDistance=t,d end
        end
    end
    return best,bestDistance
end

function State:_areAllied(a,b)
    if not a or not b or a==0 or b==0 or a==b then return false end
    return self.alliances[allianceKey(a,b)]==true
end

function State:attack(userId,targetId,amountOrRatio)
    local n=self.byUser[userId] or self.players[userId]
    if not n or not n.alive then return false,"Your nation has been eliminated" end

    -- Spawn protection protects the new nation from incoming attacks only.
    -- It must never prevent the owner from expanding during the protection window.
    targetId=math.floor(tonumber(targetId) or 0)
    local target=self.map:get(targetId)
    if not target or not target.isLand then return false,"Target must be land" end
    if target.ownerId==n.id then return false,"Already yours" end
    if self:_areAllied(n.id,target.ownerId) then return false,"Cannot attack an ally" end

    local defender=self.players[target.ownerId]
    if defender and self.time<defender.protectedUntil then return false,"Target is protected" end

    local naval=not self:_hasLandNeighbor(n,target)
    local source=target
    local travel=0
    if naval then
        if not target.isCoastal then return false,"Select land touching your frontier, or a coastal target for a sea attack" end
        local coast,distanceSquared=self:_nearestOwnedCoast(n,target)
        if not coast then return false,"Capture coastal land before launching a sea attack" end
        source=coast
        local speed=(n.buildingLevels.Port or 0)>0 and Rules.Buildings.Port.BoatSpeedMultiplier or 1
        travel=math.max(Rules.Naval.MinimumTravelSeconds,math.sqrt(distanceSquared)*Rules.Naval.SecondsPerPixel/speed)
    end

    -- Human client sends an exact troop count. AI callers may still pass a
    -- 0..1 ratio, preserving their existing decision logic.
    local requested=tonumber(amountOrRatio)
    local troops
    if requested and requested>1 then
        troops=math.floor(clamp(requested,0,n.troops))
    else
        local ratio=clamp(requested or Rules.DefaultAttackRatio,Rules.MinimumAttackRatio,Rules.MaximumAttackRatio)
        troops=math.floor(n.troops*ratio)
    end
    if troops<Rules.Attack.MinimumCommit then return false,"You need at least "..tostring(Rules.Attack.MinimumCommit).." troops to attack" end

    n.troops-=troops
    n.attacks+=1
    self.nextAttack+=1
    self.attacks[self.nextAttack]={
        id=self.nextAttack,owner=n.id,target=targetId,targetOwnerId=target.ownerId,
        source=source.id,troops=troops,initialTroops=troops,naval=naval,
        startTime=self.time,arrivalAt=self.time+travel,lastStep=self.time,
        frontier={targetId},seen={[targetId]=true},
    }
    return true,self.nextAttack,troops
end

function State:_captureTile(n,t)
    local oldId=t.ownerId
    if oldId==n.id then return false end
    local old=self.players[oldId]
    if old then
        self:_removeTile(old,t)
        if t.building then
            old.buildings[t.building]=math.max(0,(old.buildings[t.building] or 0)-1)
            old.buildingLevels[t.building]=math.max(0,(old.buildingLevels[t.building] or 0)-(t.buildingLevel or 1))
        end
        if old.owned==0 and old.alive then
            old.alive=false;old.troops=0;n.kills+=1
            if old.userId then self.byUser[old.userId]=nil;old.userId=nil end
            for attackId,a in pairs(self.attacks) do
                if a.owner==old.id then self.attacks[attackId]=nil end
            end
        end
    end
    if t.building then
        n.buildings[t.building]=(n.buildings[t.building] or 0)+1
        n.buildingLevels[t.building]=(n.buildingLevels[t.building] or 0)+(t.buildingLevel or 1)
    end
    t.ownerId=n.id;self:_addTile(n,t);self:_markDirty(t.id)
    return true
end

function State:_stepAttack(a)
    local n=self.players[a.owner]
    if not n or not n.alive then return true end
    if a.naval and self.time<a.arrivalAt then return false end
    if #a.frontier==0 or a.troops<=0 then return true end

    local first=self.map:get(a.target)
    local base=first and first.terrain or "Plains"
    local spec=terrainSpec(base)
    local maxCaptures=clamp(math.floor(a.troops/(spec.TileCost*Rules.Attack.TroopsPerTileStep)),1,Rules.Attack.MaxTilesPerStep)
    local captured=0

    for _=1,maxCaptures do
        if #a.frontier==0 or a.troops<=0 then break end
        -- Prefer frontier pixels with more same-owner neighbours. This expands
        -- a broad, connected patch rather than a thin random snake.
        local pick,bestScore=1,-math.huge
        for index,frontierId in ipairs(a.frontier) do
            local candidate=self.map:get(frontierId)
            local support=0
            if candidate then
                for _,neighborId in ipairs(candidate.neighbors or {}) do
                    local neighbor=self.map:get(neighborId)
                    if neighbor and neighbor.ownerId==a.targetOwnerId then support+=1 end
                end
            end
            local score=support*3+math.random()
            if score>bestScore then pick,bestScore=index,score end
        end
        local id=table.remove(a.frontier,pick)
        local t=self.map:get(id)
        if t and t.isLand and t.ownerId==a.targetOwnerId and not self:_areAllied(n.id,t.ownerId) then
            local defender=self.players[t.ownerId]
            local terrain=terrainSpec(t.terrain)
            local defense=defender and defender.troops or 0
            local density=defender and defense/math.max(1,defender.owned) or 0
            local pressure=clamp(defense/math.max(1,a.troops),0.6,2)
            local loss=terrain.Magnitude*Rules.Attack.BaseAttackerLossFactor*pressure
                +Rules.Attack.DefenderDensityFactor*density*terrain.Magnitude
            if t.building=="DefensePost" then loss*=Rules.Buildings.DefensePost.DefenseMultiplier end
            if t.building=="SAM" then loss*=Rules.Buildings.SAM.DefenseMultiplier end
            if a.naval and t.building=="Warship" then loss*=Rules.Naval.WarshipDefenseMultiplier end
            loss=math.max(1,math.floor(loss))
            if a.troops<=loss then a.troops=0;return true end

            a.troops-=loss
            if defender and defender~=n then
                defender.troops=math.max(0,defender.troops-math.max(1,math.floor(defense/math.max(1,defender.owned)*0.35)))
            end
            self:_captureTile(n,t);captured+=1

            -- Random 8-neighbour frontier growth produces soft, curved edges.
            for _,neighborId in ipairs(t.neighbors or {}) do
                local neighbor=self.map:get(neighborId)
                if neighbor and neighbor.ownerId==a.targetOwnerId and not a.seen[neighborId] then
                    a.seen[neighborId]=true
                    a.frontier[#a.frontier+1]=neighborId
                end
            end
        end
    end
    a.lastStep=self.time
    return #a.frontier==0 or a.troops<=0
end

function State:_buildForNation(n,t,kind)
    local spec=Rules.Buildings[kind]
    if not spec then return false,"Unknown building" end
    if not t or not t.isLand or t.ownerId~=n.id then return false,"Build only on your land" end
    if spec.RequiresCoast and not t.isCoastal then return false,"This structure needs a coastal pixel" end
    if t.building and t.building~=kind then return false,"This pixel already has another building" end

    local current=t.building==kind and math.max(1,t.buildingLevel or 1) or 0
    local nextLevel=current+1
    local cost=math.floor(spec.Cost*(current==0 and 1 or nextLevel^1.55))
    if n.gold<cost then return false,"Not enough gold ("..tostring(cost)..")" end
    n.gold-=cost
    if current==0 then
        n.buildings[kind]=(n.buildings[kind] or 0)+1
        self.buildingTiles[t.id]=true
    end
    n.buildingLevels[kind]=(n.buildingLevels[kind] or 0)+1
    t.building=kind;t.buildingLevel=nextLevel;self:_markDirty(t.id)
    return true,{kind=kind,level=nextLevel,cost=cost}
end

function State:build(userId,tileId,kind)
    local n=self.byUser[userId]
    if not n or not n.alive then return false,"Deploy first" end
    tileId=math.floor(tonumber(tileId) or 0)
    return self:_buildForNation(n,self.map:get(tileId),tostring(kind))
end

function State:allianceAction(userId,action,targetId)
    if not Rules.Alliance.Enabled then return false,"Alliances are disabled" end
    local n=self.byUser[userId]
    if not n or not n.alive then return false,"Deploy first" end
    local target=self.players[tostring(targetId or "")]
    if not target or not target.alive or target==n then return false,"Invalid nation" end

    if action=="propose" then
        if target.isAI or not target.userId then return false,"Alliance requests are for human nations" end
        if self:_areAllied(n.id,target.id) then return false,"Already allied" end
        local requests=self.allianceRequests[target.id] or {}
        local count=0;for _ in pairs(requests) do count+=1 end
        if count>=Rules.Alliance.MaxPendingPerNation then return false,"Too many pending alliance requests" end
        requests[n.id]=self.time;self.allianceRequests[target.id]=requests
        return true,target
    elseif action=="accept" then
        local requests=self.allianceRequests[n.id]
        if not requests or not requests[target.id] then return false,"No pending request from that nation" end
        requests[target.id]=nil;self.alliances[allianceKey(n.id,target.id)]=true
        return true,target
    elseif action=="reject" then
        local requests=self.allianceRequests[n.id]
        if not requests or not requests[target.id] then return false,"No pending request from that nation" end
        requests[target.id]=nil;return true,target
    elseif action=="break" then
        if not self:_areAllied(n.id,target.id) then return false,"No alliance to break" end
        self.alliances[allianceKey(n.id,target.id)]=nil;return true,target
    end
    return false,"Unknown alliance action"
end

function State:retreat(userId,attackId)
    local n=self.byUser[userId]
    if not n or not n.alive then return false,"Deploy first" end
    local a=self.attacks[tonumber(attackId)]
    if not a or a.owner~=n.id then return false,"Attack is no longer active" end
    local refund=math.floor(a.troops*Rules.Attack.RetreatRefund)
    n.troops+=refund;self.attacks[a.id]=nil
    return true,refund
end

function State:nuke(userId,targetId)
    local n=self.byUser[userId]
    if not n or not n.alive then return false,"Deploy first" end
    local target=self.map:get(math.floor(tonumber(targetId) or 0))
    if not target or not target.isLand then return false,"Invalid target" end
    if (n.buildings.MissileSilo or 0)<1 then return false,"Build a Missile Silo first" end
    if n.gold<Rules.Nuclear.Cost then return false,"Not enough gold" end
    if self.time<n.protectedUntil then return false,"Your nation is protected" end
    if (n._lastNuke or -math.huge)+Rules.Nuclear.CooldownSeconds>self.time then return false,"Nuclear cooldown active" end
    local defender=self.players[target.ownerId]
    if defender and (defender.buildings.SAM or 0)>0 and math.random()<math.min(.75,.18*defender.buildings.SAM) then
        n.gold-=math.floor(Rules.Nuclear.Cost*.25);n._lastNuke=self.time
        return false,"Missile intercepted by enemy SAM network"
    end
    n.gold-=Rules.Nuclear.Cost;n._lastNuke=self.time;n.nukes+=1
    local radius=Rules.Nuclear.Radius
    for y=math.max(1,target.y-radius),math.min(self.map.height,target.y+radius) do
        for x=math.max(1,target.x-radius),math.min(self.map.width,target.x+radius) do
            local dx,dy=x-target.x,y-target.y
            if dx*dx+dy*dy<=radius*radius then
                local t=self.map:get((y-1)*self.map.width+x)
                if t and t.isLand and t.ownerId~=n.id then
                    if t.building then
                        local old=self.players[t.ownerId]
                        if old then
                            old.buildings[t.building]=math.max(0,(old.buildings[t.building] or 0)-1)
                            old.buildingLevels[t.building]=math.max(0,(old.buildingLevels[t.building] or 0)-(t.buildingLevel or 1))
                        end
                        t.building=nil;t.buildingLevel=0;self.buildingTiles[t.id]=nil
                    end
                    local old=self.players[t.ownerId]
                    if old then old.troops=math.floor(old.troops*(1-Rules.Nuclear.TroopLoss)) end
                    self:_markDirty(t.id)
                end
            end
        end
    end
    return true,"Nuclear strike launched"
end

function State:_aiBuild(n)
    local kind="Factory"
    if (n.buildings.City or 0)<2 then kind="City"
    elseif (n.buildings.Port or 0)<1 then kind="Port" end
    local spec=Rules.Buildings[kind]
    if n.gold<spec.Cost then return end
    local candidates={}
    for _,id in ipairs(n.tileIds) do
        local t=self.map:get(id)
        if t and t.ownerId==n.id and not t.building and (not spec.RequiresCoast or t.isCoastal) then
            candidates[#candidates+1]=t
        end
    end
    if #candidates>0 then self:_buildForNation(n,candidates[math.random(1,#candidates)],kind) end
end

function State:_aiTick()
    local now=self.time
    for _,n in pairs(self.players) do
        if n.isAI and n.alive then
            if (n._nextAI or 0)<=now then
                local minimum=n.kind=="Tribe" and Rules.AI.TribeThinkMin or Rules.AI.NationThinkMin
                local maximum=n.kind=="Tribe" and Rules.AI.TribeThinkMax or Rules.AI.NationThinkMax
                n._nextAI=now+minimum+math.random()*(maximum-minimum)
                local borders=self:_borderTiles(n)
                if #borders>0 and n.troops>Rules.AI.MinimumAttackTroops then
                    local targetId,best=nil,math.huge
                    for _=1,math.min(10,#borders) do
                        local source=self.map:get(borders[math.random(1,#borders)])
                        for _,neighborId in ipairs(source.neighbors or {}) do
                            local t=self.map:get(neighborId)
                            if t and t.ownerId~=n.id and not self:_areAllied(n.id,t.ownerId) then
                                local defender=self.players[t.ownerId]
                                local score=t.ownerId==0 and -100000 or (defender and defender.troops or 0)
                                if defender and now<defender.protectedUntil then score=math.huge end
                                if score<best then targetId,best=t.id,score end
                            end
                        end
                    end
                    if targetId then
                        local ratio=n.kind=="Tribe" and Rules.AI.TribeAttackRatio or Rules.AI.NationAttackRatio
                        self:attack(n.id,targetId,ratio)
                    end
                end
            end
            if (n._nextBuild or 0)<=now then
                n._nextBuild=now+Rules.AI.BuildThinkSeconds+math.random()*8
                self:_aiBuild(n)
            end
        end
    end
end

function State:tick(dt)
    dt=clamp(tonumber(dt) or 0,0,.25);self.time+=dt
    for _,n in pairs(self.players) do
        if n.alive then
            local lv=n.buildingLevels
            local city=lv.City or 0
            local cap=Rules.HumanStartingTroops+n.owned*Rules.TroopCapPerTile+city*Rules.Buildings.City.TroopCapacity
            -- OpenFront-style nonlinear regeneration: faster at low army,
            -- tapering smoothly as the army approaches its capacity.
            local fill=cap>0 and clamp(1-(n.troops/cap),0,1) or 0
            local perTick=Rules.TroopRegenerationBase+(math.max(0,n.troops)^0.73)/4
            local growth=perTick*fill*(dt/Rules.TickSeconds)
            n.troops=math.min(cap,n.troops+growth)
            local income=Rules.GoldPerSecond
                +(lv.City or 0)*Rules.Buildings.City.GoldPerSecond
                +(lv.Factory or 0)*Rules.Buildings.Factory.GoldPerSecond
                +(lv.Port or 0)*Rules.Buildings.Port.GoldPerSecond
            n.gold=math.min(999999999,n.gold+income*dt)
        end
    end
    for id,a in pairs(self.attacks) do
        if self.time-a.lastStep>=Rules.TickSeconds then
            if self:_stepAttack(a) then
                local n=self.players[a.owner]
                if n and n.alive and a.troops>0 then n.troops+=math.floor(a.troops*.45) end
                self.attacks[id]=nil
            end
        end
    end
    self:_aiTick()
    if not self.winner and self.map.totalLand>0 then
        for id,n in pairs(self.players) do
            if n.alive and n.owned/self.map.totalLand>=.8 then self.winner=id;break end
        end
    end
end

local function packPlayers(self)
    local players={}
    for id,n in pairs(self.players) do
        local allies={}
        for otherId in pairs(self.players) do
            if self:_areAllied(id,otherId) then allies[otherId]=true end
        end
        local lx,ly=0,0
        if n.owned>0 then lx=n.centerXSum/n.owned;ly=n.centerYSum/n.owned end
        local maxTroops=Rules.HumanStartingTroops+n.owned*Rules.TroopCapPerTile
            +(n.buildingLevels.City or 0)*Rules.Buildings.City.TroopCapacity
        local fill=maxTroops>0 and clamp(1-(n.troops/maxTroops),0,1) or 0
        local regenPerSecond=(Rules.TroopRegenerationBase+(math.max(0,n.troops)^0.73)/4)
            *fill/Rules.TickSeconds
        players[id]={
            id=id,name=n.displayName or n.name,color=n.color,
            troops=math.floor(n.troops),maxTroops=math.floor(maxTroops),
            regenPerSecond=math.floor(regenPerSecond),gold=math.floor(n.gold),
            owned=n.owned,share=self.map.totalLand>0 and n.owned/self.map.totalLand or 0,
            alive=n.alive,isAI=n.isAI,kind=n.kind,userId=n.userId,
            kills=n.kills,attacks=n.attacks,nukes=n.nukes,
            buildings=n.buildings,buildingLevels=n.buildingLevels,allies=allies,
            protectedSeconds=math.max(0,math.ceil(n.protectedUntil-self.time)),
            labelX=lx,labelY=ly,
        }
    end
    return players
end

local function packAttacks(self)
    local list={}
    for id,a in pairs(self.attacks) do
        local s,t=self.map:get(a.source),self.map:get(a.target)
        if s and t then
            list[#list+1]={
                id=id,owner=a.owner,source=a.source,target=a.target,naval=a.naval,
                startTime=a.startTime,arrivalAt=a.arrivalAt,troops=math.floor(a.troops),
                initialTroops=a.initialTroops,sourceX=s.x,sourceY=s.y,targetX=t.x,targetY=t.y,
            }
        end
    end
    return list
end

function State:metadataSnapshot()
    local markers={}
    for id in pairs(self.buildingTiles) do
        local t=self.map:get(id)
        if t and t.building and #markers<260 then
            markers[#markers+1]={id=id,kind=Rules.BuildingCodes[t.building] or 0,level=t.buildingLevel or 1}
        end
    end
    return {
        matchId=self.matchId,width=self.map.width,height=self.map.height,
        totalLand=self.map.totalLand,time=self.time,winner=self.winner,
        ownerIds=self.ownerIds,players=packPlayers(self),attacks=packAttacks(self),
        buildingMarkers=markers,
    }
end

function State:makeTileBuffer()
    local packed=buffer.create(self.map.width*self.map.height*6)
    for id,t in ipairs(self.map.tiles) do
        local offset=(id-1)*6
        local ownerIndex=t.ownerId==0 and 0 or (self.ownerIndexById[t.ownerId] or 0)
        buffer.writeu16(packed,offset,ownerIndex)
        buffer.writeu8(packed,offset+2,t.isLand and 1 or 0)
        buffer.writeu8(packed,offset+3,Rules.TerrainCodes[t.terrain] or 0)
        buffer.writeu8(packed,offset+4,Rules.BuildingCodes[t.building] or 0)
        buffer.writeu8(packed,offset+5,clamp(t.buildingLevel or 0,0,255))
    end
    return packed
end

function State:tileDeltaSnapshot()
    local changes={}
    for id in pairs(self.dirtyTiles) do
        local t=self.map:get(id)
        if t then
            changes[#changes+1]={
                id=id,ownerIndex=t.ownerId==0 and 0 or (self.ownerIndexById[t.ownerId] or 0),
                isLand=t.isLand and 1 or 0,terrain=Rules.TerrainCodes[t.terrain] or 0,
                building=Rules.BuildingCodes[t.building] or 0,
                level=clamp(t.buildingLevel or 0,0,255),
            }
        end
    end
    table.clear(self.dirtyTiles)
    local data=self:metadataSnapshot()
    data.tileChanges=changes
    return data
end

return State
