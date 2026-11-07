-- shared/WorldPvP/PixelWorldState.lua
-- Real-time pixel territory simulation inspired by the OpenFront/RoWorld interaction model.
local Rules=require(script.Parent.Rules)
local TileMap=require(script.Parent.TileMap)
local CountryMapData=require(script.Parent.CountryMapData)

local State={}
State.__index=State

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function ratioLoss(defenderTroops,attackTroops)
    return clamp(defenderTroops/math.max(1,attackTroops),0.6,2)
end

function State.new()
    local self=setmetatable({},State)
    self.map=TileMap.build()
    self.players={}
    self.byUser={}
    self.attacks={}
    self.nextAttack=0
    self.time=0
    self.lastId=0
    self.matchId="world_"..tostring(os.time())
    self.aiColors={}
    self:_seedAI()
    return self
end

function State:_newNation(id,name,isAI,kind,color)
    local n={
        id=id,name=name,isAI=isAI,kind=kind or "Nation",color=color,
        troops=isAI and (kind=="Tribe" and Rules.TribeStartingTroops or Rules.NationStartingTroops) or Rules.HumanStartingTroops,
        gold=isAI and Rules.BotStartingGold or Rules.HumanStartingGold,
        owned=0,alive=true,coast=false,userId=nil,displayName=nil,
        kills=0,attacks=0
    }
    self.players[id]=n
    return n
end

function State:_seedAI()
    local palette={
        {0.86,0.22,0.20},{0.20,0.48,0.90},{0.18,0.70,0.38},{0.92,0.60,0.16},
        {0.64,0.32,0.84},{0.12,0.66,0.76},{0.88,0.32,0.54},{0.46,0.56,0.24}
    }
    local used={}
    local ids={}
    for _,country in ipairs(CountryMapData.Countries) do table.insert(ids,country.id) end
    for i=1,math.min(Rules.AI.NationCount,#ids) do
        local countryId=ids[((i-1)*2)%#ids+1]
        if not used[countryId] then
            used[countryId]=true
            local n=self:_newNation("AI_N"..i,countryId,true,"Nation",palette[((i-1)%#palette)+1])
            local center=self.map:countryCenterTile(countryId)
            if center then self:_claimSpawn(n,center,Rules.SpawnRadius) end
        end
    end
    local tribeIndex=0
    for _,country in ipairs(CountryMapData.Countries) do
        if tribeIndex>=Rules.AI.TribeCount then break end
        local center=self.map:countryCenterTile(country.id)
        if center and self.map:get(center).ownerId==0 then
            tribeIndex+=1
            local n=self:_newNation("AI_T"..tribeIndex,"Tribe "..tostring(tribeIndex),true,"Tribe",palette[(tribeIndex%#palette)+1])
            self:_claimSpawn(n,center,Rules.TribeSpawnRadius)
        end
    end
end

function State:_claimSpawn(n,center,radius)
    local tiles=self.map:findSpawnTiles(center,radius)
    if #tiles==0 then return false end
    for _,id in ipairs(tiles) do
        local t=self.map:get(id)
        if t.ownerId==0 then
            t.ownerId=n.id
            n.owned+=1
            if t.isCoastal then n.coast=true end
        end
    end
    return n.owned>0
end

function State:spawnHuman(userId,displayName,tileId)
    if self.byUser[userId] then return false,"You already spawned" end
    local t=self.map:get(tileId)
    if not t or not t.isLand or t.ownerId~=0 then return false,"Choose free land" end
    local id="P_"..tostring(userId)
    local n=self:_newNation(id,displayName,false,"Nation",{0.18,0.72,0.98})
    n.userId=userId
    n.displayName=displayName
    n.protectedUntil=self.time+300
    if not self:_claimSpawn(n,tileId,Rules.SpawnRadius) then
        self.players[id]=nil
        return false,"Spawn location unavailable"
    end
    self.byUser[userId]=n
    return true,n
end

function State:_borderTiles(n)
    local result={}
    for _,t in ipairs(self.map.tiles) do
        if t.ownerId==n.id then
            for _,nid in ipairs(t.neighbors) do
                local x=self.map:get(nid)
                if x and x.isLand and x.ownerId~=n.id then
                    result[#result+1]=t.id
                    break
                end
            end
        end
    end
    return result
end

function State:_hasLandNeighbor(n,target)
    for _,nid in ipairs(target.neighbors) do
        local x=self.map:get(nid)
        if x and x.isLand and x.ownerId==n.id then return true end
    end
    return false
end

function State:_hasCoast(n)
    if n.coast then return true end
    for _,t in ipairs(self.map.tiles) do
        if t.ownerId==n.id and t.isCoastal then n.coast=true return true end
    end
    return false
end

function State:_isCoastalTile(id)
    local t=self.map:get(id)
    return t and t.isLand and t.isCoastal
end

function State:_canNaval(n,target)
    if not self:_hasCoast(n) or not target.isCoastal then return false end
    local sourceCoast=false
    for _,t in ipairs(self.map.tiles) do
        if t.ownerId==n.id and t.isCoastal then sourceCoast=true break end
    end
    return sourceCoast
end

function State:attack(userId,targetId,ratio)
    local n=self.byUser[userId] or self.players[userId]
    if not n then return false,"Spawn first" end
    if self.time<n.protectedUntil then return false,"You are protected for "..math.ceil(n.protectedUntil-self.time).."s" end
    local target=self.map:get(targetId)
    if not target or not target.isLand then return false,"Target must be land" end
    if target.ownerId==n.id then return false,"Already yours" end
    local defender=self.players[target.ownerId]
    if defender and self.time<defender.protectedUntil then return false,"Target is protected" end
    local landAttack=self:_hasLandNeighbor(n,target)
    local naval=not landAttack
    if naval and not self:_canNaval(n,target) then return false,"Need a coastline to launch a sea attack" end
    ratio=clamp(tonumber(ratio) or Rules.DefaultAttackRatio,Rules.MinimumAttackRatio,Rules.MaximumAttackRatio)
    local troops=math.floor(n.troops*ratio)
    if troops<100 then return false,"Not enough troops" end
    n.troops-=troops
    n.attacks+=1
    self.nextAttack+=1
    self.attacks[self.nextAttack]={
        id=self.nextAttack,owner=n.id,target=targetId,troops=troops,
        naval=naval,source=targetId,created=self.time,lastStep=self.time
    }
    return true,self.nextAttack
end

function State:_attackCandidates(a)
    local target=self.map:get(a.target)
    local n=self.players[a.owner]
    local result={}
    if a.naval then
        -- Naval assault lands at the clicked coastal tile, then behaves as a normal frontier attack.
        if target and target.isLand then result[1]=target.id end
        return result
    end
    for _,nid in ipairs(target.neighbors) do
        local t=self.map:get(nid)
        if t and t.isLand and t.ownerId==a.owner then result[#result+1]=target.id break end
    end
    -- Frontier expansion: once the first tile is taken, immediately expose its neighbors.
    if #result==0 then
        for _,t in ipairs(self.map.tiles) do
            if t.ownerId==a.owner then
                for _,nid in ipairs(t.neighbors) do
                    local x=self.map:get(nid)
                    if x and x.isLand and x.ownerId==self.map:get(a.target).ownerId then
                        result[#result+1]=x.id
                    end
                end
            end
        end
    end
    return result
end

function State:_captureTile(n,t)
    local oldId=t.ownerId
    if oldId==n.id then return end
    local old=self.players[oldId]
    if old then
        old.owned=math.max(0,old.owned-1)
        if old.owned==0 then old.alive=false end
    end
    t.ownerId=n.id
    n.owned+=1
    if t.isCoastal then n.coast=true end
end

function State:_stepAttack(a)
    local n=self.players[a.owner]
    local target=self.map:get(a.target)
    if not n or not n.alive or not target or not target.isLand then return true end
    local defender=self.players[target.ownerId]
    if target.ownerId==n.id then return true end

    local cost=Rules.Attack.Plains
    if target.terrain=="Forest" then cost=Rules.Attack.Forest
    elseif target.terrain=="Highland" then cost=Rules.Attack.Highland
    elseif target.terrain=="Mountain" then cost=Rules.Attack.Mountain end

    local defense=defender and defender.troops or 0
    local density=defender and defense/math.max(1,defender.owned) or 0
    local pressure=ratioLoss(defense,a.troops)
    local loss=cost.Magnitude*Rules.Attack.BaseAttackerLossFactor*pressure
    loss+=Rules.Attack.DefenderDensityFactor*density*cost.Magnitude
    if defender and defender.kind=="Tribe" then loss*=0.7 end
    if target.building=="DefensePost" then loss*=2.5 end
    if target.building=="SAM" then loss*=1.6 end
    local speed=(pressure/Rules.Attack.SpeedCostDivisor)*cost.TileCost
    if a.naval then speed*=1.35 end
    local tilesPerStep=math.max(1,math.floor(a.troops/math.max(1,speed*900)))
    local gained=0
    for _=1,tilesPerStep do
        if a.troops<=1 then return true end
        local current=self.map:get(a.target)
        if not current or not current.isLand then return true end
        if current.ownerId~=n.id then
            local defending=self.players[current.ownerId]
            if defending and defending.kind~="Tribe" and defender~=nil then
                defending.troops=math.max(0,defending.troops-(defense/math.max(1,defending.owned)))
            end
            a.troops-=math.max(1,math.floor(loss))
            if a.troops<=0 then return true end
            self:_captureTile(n,current)
            gained+=1
        end
        local frontier={}
        for _,nid in ipairs(current.neighbors) do
            local x=self.map:get(nid)
            if x and x.isLand and x.ownerId~=n.id and x.ownerId==(defender and defender.id or 0) then
                frontier[#frontier+1]=x.id
            end
        end
        if #frontier==0 then break end
        a.target=frontier[math.random(1,#frontier)]
    end
    if gained>0 then a.lastStep=self.time end
    return false
end

function State:tick(dt)
    self.time+=dt
    for _,n in pairs(self.players) do
        if n.alive then
            local cap=Rules.HumanStartingTroops+math.floor(n.owned*40)+n.buildings.City*Rules.Buildings.City.TroopCapacity
            n.troops=math.min(cap,n.troops+Rules.TroopRegenerationBase+math.floor(math.sqrt(math.max(1,n.troops))/2))
            local income=Rules.GoldPerSecond+n.buildings.City*Rules.Buildings.City.GoldPerSecond+n.buildings.Factory*Rules.Buildings.Factory.GoldPerSecond+n.buildings.Port*Rules.Buildings.Port.GoldPerSecond
            n.gold+=income*dt
        end
    end
    for id,a in pairs(self.attacks) do
        if self.time-a.lastStep>=Rules.TickSeconds then
            if self:_stepAttack(a) then self.attacks[id]=nil end
        end
    end
    self:_aiTick()
end

function State:_aiTick()
    local now=self.time
    for _,n in pairs(self.players) do
        if n.isAI and n.alive and (n._nextAI or 0)<=now then
            n._nextAI=now+(n.kind=="Tribe" and (Rules.AI.TribeThinkMin+math.random()*(Rules.AI.TribeThinkMax-Rules.AI.TribeThinkMin)) or (Rules.AI.NationThinkMin+math.random()*(Rules.AI.NationThinkMax-Rules.AI.NationThinkMin)))
            local borders=self:_borderTiles(n)
            if #borders>0 and n.troops>Rules.AI.MinimumAttackTroops then
                local source=self.map:get(borders[math.random(1,#borders)])
                local candidates={}
                for _,nid in ipairs(source.neighbors) do
                    local t=self.map:get(nid)
                    if t and t.isLand and t.ownerId~=n.id then candidates[#candidates+1]=t.id end
                end
                if #candidates>0 then
                    local target=candidates[math.random(1,#candidates)]
                    local ratio=n.kind=="Tribe" and Rules.AI.TribeAttackRatio or Rules.AI.NationAttackRatio
                    self:attack(n.id,target,ratio)
                end
            end
        end
    end
end

function State:build(userId,tileId,kind)
    local n=self.byUser[userId]
    if not n then return false,"Spawn first" end
    local t=self.map:get(tileId)
    local spec=Rules.Buildings[kind]
    if not t or not t.isLand or t.ownerId~=n.id then return false,"Build only on your land" end
    if t.building then return false,"A building already exists here" end
    if not spec then return false,"Unknown building" end
    if n.gold<spec.Cost then return false,"Not enough gold" end
    n.gold-=spec.Cost
    t.building=kind
    n.buildings[kind]=(n.buildings[kind] or 0)+1
    return true
end

function State:nuke(userId,targetId)
    local n=self.byUser[userId]
    local target=self.map:get(targetId)
    if not n or not target or not target.isLand then return false,"Invalid target" end
    if n.gold<Rules.Nuclear.Cost then return false,"Not enough gold" end
    if n.protectedUntil>self.time then return false,"Wait until protection ends" end
    if (n._lastNuke or -math.huge)+Rules.Nuclear.CooldownSeconds>self.time then return false,"Nuclear cooldown active" end
    n.gold-=Rules.Nuclear.Cost
    n._lastNuke=self.time
    local r=Rules.Nuclear.Radius
    for y=math.max(1,target.y-r),math.min(self.map.height,target.y+r) do
        for x=math.max(1,target.x-r),math.min(self.map.width,target.x+r) do
            local dx,dy=x-target.x,y-target.y
            if dx*dx+dy*dy<=r*r then
                local t=self.map:get((y-1)*self.map.width+x)
                if t and t.isLand then
                    if t.ownerId~=n.id then
                        t.building=nil
                        local old=self.players[t.ownerId]
                        if old then old.troops=math.floor(old.troops*(1-Rules.Nuclear.TroopLoss)) end
                    end
                end
            end
        end
    end
    return true
end

function State:tileSnapshot()
    local owners={}
    for id,t in ipairs(self.map.tiles) do owners[id]={t.ownerId,t.terrain,t.isLand and 1 or 0,t.building} end
    local players={}
    for id,n in pairs(self.players) do
        players[id]={id=n.id,name=n.displayName or n.name,color=n.color,troops=math.floor(n.troops),gold=math.floor(n.gold),owned=n.owned,alive=n.alive,isAI=n.isAI,kind=n.kind,userId=n.userId}
    end
    local winner=nil
    for id,n in pairs(self.players) do
        if n.alive and n.owned/self.map.totalLand>=.8 then winner=id break end
    end
    return {matchId=self.matchId,width=self.map.width,height=self.map.height,tiles=owners,players=players,time=self.time,winner=winner,totalLand=self.map.totalLand}
end

return State
