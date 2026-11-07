-- Tests for the active PixelWorldState engine (not the retired WorldState module).
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local State=require(ReplicatedStorage.Shared.WorldPvP.PixelWorldState)
local MapRegistry=require(ReplicatedStorage.Shared.WorldPvP.MapRegistry)

local Tests={}

local function expect(value,message)
    if not value then error("PixelWorldState test failed: "..message,2) end
end

local function makeMap(width,height)
    local map={width=width,height=height,totalLand=width*height,tiles={}}
    local directions={{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
    for y=1,height do
        for x=1,width do
            local id=(y-1)*width+x
            map.tiles[id]={
                id=id,x=x,y=y,isLand=true,ownerId=0,terrain="Plains",
                isCoastal=x==1 or x==width or y==1 or y==height,
                neighbors={},building=nil,buildingLevel=0,
            }
        end
    end
    for y=1,height do
        for x=1,width do
            local tile=map.tiles[(y-1)*width+x]
            for _,d in ipairs(directions) do
                local nx,ny=x+d[1],y+d[2]
                if nx>=1 and nx<=width and ny>=1 and ny<=height then
                    tile.neighbors[#tile.neighbors+1]=(ny-1)*width+nx
                end
            end
        end
    end
    function map:get(id)
        if type(id)~="number" or id%1~=0 then return nil end
        return self.tiles[id]
    end
    function map:findSpawnTiles(centerId,_radius)
        local tile=self:get(centerId)
        if tile and tile.isLand and tile.ownerId==0 then return {centerId} end
        return {}
    end
    return map
end

local function newState()
    return State.new({map=makeMap(7,7),seedAI=false})
end

local function connectedOwnedTiles(state,nation)
    local owned={}
    for _,id in ipairs(nation.tileIds) do owned[id]=true end
    local start=nation.tileIds[1]
    local visited={[start]=true}
    local queue={start}
    local head=1
    while head<=#queue do
        local id=queue[head]
        head+=1
        local tile=state.map:get(id)
        for _,neighborId in ipairs(tile.neighbors) do
            if owned[neighborId] and not visited[neighborId] then
                visited[neighborId]=true
                queue[#queue+1]=neighborId
            end
        end
    end
    for id in pairs(owned) do
        if not visited[id] then return false end
    end
    return true
end

function Tests:run()
    local passed=0

    -- Map registry must expose independent geographic presets.
    expect(MapRegistry.get("World").wrapX==true,"world map wraps horizontally")
    expect(MapRegistry.get("Europe").wrapX==false,"regional maps do not wrap")
    expect(MapRegistry.get("Asia").bounds.west==25,"asia uses its own geographic bounds")
    expect(MapRegistry.get("MENA").bounds.east==68,"middle east map has independent bounds")
    passed+=4

    -- Spawn must claim a valid free land pixel and register its owner.
    local state=newState()
    local spawnId=16 -- (2,3) on a 7x7 test grid
    local ok,nation=state:spawnHuman(101,"Test Nation",spawnId)
    expect(ok and nation.owned==1,"human spawn claims land")
    expect(state.byUser[101]==nation,"spawn registers user")
    passed+=2

    local duplicate,duplicateReason=state:spawnHuman(101,"Test Nation",17)
    expect(not duplicate and duplicateReason=="You already deployed","duplicate deployment rejected")
    passed+=1

    -- A non-adjacent inland pixel cannot be attacked as a ground or sea target.
    local farInland=(4-1)*7+4
    local distant,distantReason=state:attack(101,farInland,1000)
    expect(not distant and string.find(distantReason,"coastal target",1,true)~=nil,"non-adjacent inland target rejected")
    passed+=1

    -- Exact troop amount is deducted, even while the attacker is spawn-protected.
    local targetId=17 -- (3,3), adjacent to spawn
    local before=nation.troops
    local attackStarted,attackId,sent=state:attack(101,targetId,2000)
    expect(attackStarted and attackId==1 and sent==2000,"exact troop attack starts")
    expect(nation.troops<=before-2000,"exact troop amount deducted")
    expect(state.time<nation.protectedUntil,"attacker remains spawn-protected while expanding")
    passed+=3

    state:tick(0.1)
    expect(state.map:get(targetId).ownerId==nation.id,"attack captures adjacent neutral land")
    expect(connectedOwnedTiles(state,nation),"captured pixels remain one connected patch")
    passed+=2

    -- Defender spawn protection prevents an incoming attack.
    local protectedState=newState()
    local firstSpawn=protectedState:spawnHuman(201,"First",16)
    local secondOk,second=protectedState:spawnHuman(202,"Protected",17)
    expect(firstSpawn and secondOk and second.owned==1,"two separated nations can deploy")
    local protectedAttack,protectedReason=protectedState:attack(201,17,1000)
    expect(not protectedAttack and protectedReason=="Target is protected","new nation cannot be attacked during protection")
    passed+=2

    -- Retreat refunds the configured share of troops still in flight.
    local retreatState=newState()
    local retreatOk,retreatNation=retreatState:spawnHuman(301,"Retreat",16)
    expect(retreatOk,"retreat test nation spawns")
    local started,retreatId=retreatState:attack(301,17,2000)
    expect(started,"retreat test attack starts")
    local retreated,refund=retreatState:retreat(301,retreatId)
    expect(retreated and refund==1500,"retreat returns configured fraction")
    passed+=3

    -- Building validation and accounting use the current engine.
    local buildState=newState()
    local buildOk,buildNation=buildState:spawnHuman(401,"Builder",16)
    expect(buildOk,"builder spawns")
    local built,building=buildState:build(401,16,"City")
    expect(built and building.kind=="City" and buildNation.buildings.City==1,"city build is charged and counted")
    passed+=2

    return {passed=passed,failed=0,message="PixelWorldState tests passed"}
end

return Tests
