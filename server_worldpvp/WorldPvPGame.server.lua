-- server_worldpvp/WorldPvPGame.server.lua
-- Country-level World PvP runtime: no avatar gameplay, only map strategy.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local WorldState=require(Shared.WorldPvP.WorldState)
local CountryMapData=require(Shared.WorldPvP.CountryMapData)
local Rules=require(Shared.WorldPvP.Rules)

Players.CharacterAutoLoads=false

local folder=ReplicatedStorage:FindFirstChild("WorldPvPRemotes") or Instance.new("Folder")
folder.Name="WorldPvPRemotes"; folder.Parent=ReplicatedStorage

local function remote(name)
    local r=folder:FindFirstChild(name) or Instance.new("RemoteEvent")
    r.Name=name; r.Parent=folder; return r
end

local SelectCountry=remote("SelectCountry")
local AttackCountry=remote("AttackCountry")
local RequestSnapshot=remote("RequestSnapshot")
local Snapshot=remote("Snapshot")
local Notice=remote("Notice")

local state=WorldState.new(nil)
local palette={
    {r=.84,g=.22,b=.20},{r=.20,g=.48,b=.86},{r=.18,g=.66,b=.38},{r=.92,g=.59,b=.17},
    {r=.61,g=.31,b=.82},{r=.12,g=.67,b=.73},{r=.88,g=.33,b=.55},{r=.48,g=.57,b=.24},
    {r=.20,g=.70,b=.58},{r=.80,g=.43,b=.18},{r=.36,g=.50,b=.73},{r=.72,g=.35,b=.31},
}
for i,country in ipairs(CountryMapData.Countries) do
    state:addCountryNation(country.id,palette[((i-1)%#palette)+1],"Nation")
    -- Roughly half the world starts as neutral land; the rest is occupied by AI nations.
    -- This gives the player a real "choose your starting location" phase.
    if i % 2 == 1 then
        state.countryOwners[country.id]=nil
    end
end

local function send(player)
    Snapshot:FireClient(player,state:getCountrySnapshot())
end
local function broadcast()
    local data=state:getCountrySnapshot()
    for _,player in ipairs(Players:GetPlayers()) do Snapshot:FireClient(player,data) end
end
local function notify(player,message,kind)
    Notice:FireClient(player,{message=message,kind=kind or "info"})
end

SelectCountry.OnServerEvent:Connect(function(player,countryId)
    local ok,nation=state:assignPlayerCountry(player.UserId,tostring(countryId))
    if not ok then notify(player,nation,"error"); return end
    state:setPlayerDisplayName(player.UserId,player.DisplayName or player.Name)
    notify(player,"تم تثبيت موقعك. الآن انقر على دولة مجاورة لتتوسع.","success")
    broadcast()
end)

AttackCountry.OnServerEvent:Connect(function(player,countryId,troops)
    local ok,id=state:attackCountry(player.UserId,tostring(countryId),troops)
    if not ok then notify(player,id,"error"); return end
    notify(player,"الهجوم انطلق نحو الجبهة #"..tostring(id),"success")
end)

RequestSnapshot.OnServerEvent:Connect(send)

Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        send(player)
        notify(player,"انقر أي أرض غير محتلة لاختيار نقطة البداية.","info")
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local nation=state:getNationForPlayer(player.UserId)
    if nation then
        nation.ownerUserId=nil
        nation.isAI=true
        state.playerNation[player.UserId]=nil
    end
end)

local aiNext={}
local last=os.clock()
local lastBroadcast=0

task.spawn(function()
    while true do
        task.wait(Rules.TickSeconds)
        local now=os.clock()
        local dt=math.min(2,now-last)
        last=now
        if not state.matchOver then
            local events=state:tick(dt)
            for id,nation in pairs(state.nations) do
                if nation.isAI and state:getNationLand(id)>0 and now>=(aiNext[id] or 0) then
                    aiNext[id]=now+Rules.AI.ThinkMinSeconds+math.random()*(Rules.AI.ThinkMaxSeconds-Rules.AI.ThinkMinSeconds)
                    local targets={}
                    for countryId,ownerId in pairs(state.countryOwners) do
                        if ownerId~=id then
                            local country=CountryMapData.get(countryId)
                            if country then
                                for _,neighborId in ipairs(country.neighbors) do
                                    if state.countryOwners[neighborId]==id then
                                        targets[#targets+1]=countryId
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if #targets>0 and nation.troops>=Rules.AI.MinimumAttackTroops then
                        local target=targets[math.random(1,#targets)]
                        state.attacks[#state.attacks+1]={
                            id=state.nextAttackId+1,attackerNationId=id,defenderNationId=state.countryOwners[target],
                            targetCountryId=target,troopCount=math.floor(nation.troops*Rules.AI.AttackReserveRatio),
                            naval=false,resolvesAt=state.clock+Rules.Attack.TravelSeconds
                        }
                        state.nextAttackId+=1
                        nation.troops-=math.floor(nation.troops*Rules.AI.AttackReserveRatio)
                    end
                end
            end
            if #events>0 or now-lastBroadcast>=Rules.SnapshotSeconds then
                broadcast()
                lastBroadcast=now
            end
        end
    end
end)

print("[WorldPvP] Country map online | "..tostring(#CountryMapData.Countries).." real countries | avatar spawning disabled")
