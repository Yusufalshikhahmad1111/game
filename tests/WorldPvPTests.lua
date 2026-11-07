-- tests/WorldPvPTests.lua
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local WorldMap=require(ReplicatedStorage.Shared.WorldPvP.WorldMap)
local WorldState=require(ReplicatedStorage.Shared.WorldPvP.WorldState)
local Tests={}
local function expect(v,m) if not v then error("WorldPvP test failed: "..m,2) end end
function Tests:run()
    local map=WorldMap.fromRows({"##########","##########","##########","##########","##########","##########"})
    local s=WorldState.new(map)
    s:addNation("A","Alpha",{"02_03"},{r=1,g=0,b=0},"Nation")
    s:addNation("B","Beta",{"03_03"},{r=0,g=0,b=1},"Nation")
    local ok,err=s:assignPlayer(101,"A"); expect(ok,"assign A "..tostring(err))
    local okB,errB=s:assignPlayer(202,"B"); expect(okB,"assign B "..tostring(errB))
    local occupied,occupiedErr=s:assignPlayer(303,"A"); expect(not occupied and occupiedErr=="Nation already occupied","occupied nation")
    local attack,id=s:attack(101,"03_03",5000); expect(attack and id==1,"ground attack")
    local events=s:tick(4); expect(#events>0,"attack resolves")
    expect(map.cellsById["03_03"].ownerId=="A","capture transfers land")
    local build,city=s:build(101,"02_03","City"); expect(build and city.kind=="City","city builds")
    local port,portValue=s:build(101,"01_03","Port"); expect(port and portValue.kind=="Port","coastal port builds")
    local naval,navalId=s:queueAttack("A","09_03",5000,true); expect(naval and navalId==2,"naval attack queues")
    local bad,reason=s:build(101,"03_03","Port"); expect(not bad and reason=="Insufficient gold","gold limits construction after purchases")
    local snapshot=s:getSnapshot(); expect(snapshot.width==10 and #snapshot.cells==60,"snapshot dimensions")
    return {passed=11,failed=0,message="World PvP simulation tests passed"}
end
return Tests