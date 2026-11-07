-- server_worldpvp/WorldPvPGame.server.lua
-- Server-authoritative World PvP runtime. Original Roblox-native implementation.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local WorldSeed=require(Shared.WorldPvP.WorldSeed)
local WorldState=require(Shared.WorldPvP.WorldState)
local Rules=require(Shared.WorldPvP.Rules)

local folder=ReplicatedStorage:FindFirstChild("WorldPvPRemotes") or Instance.new("Folder")
folder.Name="WorldPvPRemotes"; folder.Parent=ReplicatedStorage

local function remote(name)
    local r=folder:FindFirstChild(name) or Instance.new("RemoteEvent")
    r.Name=name; r.Parent=folder; return r
end

local SelectNation=remote("SelectNation")
local Attack=remote("Attack")
local NavalAttack=remote("NavalAttack")
local Build=remote("Build")
local Nuke=remote("Nuke")
local AllianceOffer=remote("AllianceOffer")
local AllianceRespond=remote("AllianceRespond")
local RequestSnapshot=remote("RequestSnapshot")
local Snapshot=remote("Snapshot")
local Notice=remote("Notice")

local map,entities=WorldSeed.create()
local state=WorldState.new(map)
for _,entity in ipairs(entities) do
    state:addNation(entity.id,entity.name,{entity.cellId},entity.color,entity.category)
end

local function snapshot() return state:getSnapshot() end
local function send(player) Snapshot:FireClient(player,snapshot()) end
local function broadcast()
    local data=snapshot()
    for _,p in ipairs(Players:GetPlayers()) do Snapshot:FireClient(p,data) end
end
local function notify(player,message,kind)
    Notice:FireClient(player,{message=message,kind=kind or "info"})
end

SelectNation.OnServerEvent:Connect(function(player,nationId)
    if #Players:GetPlayers()>Rules.MaxPlayers then notify(player,"السيرفر ممتلئ.","error"); return end
    local ok,result=state:assignPlayer(player.UserId,tostring(nationId))
    if not ok then notify(player,result,"error"); return end
    notify(player,"تم اختيار "..result.name.." — ابدأ التوسع!","success")
    broadcast()
end)

Attack.OnServerEvent:Connect(function(player,cellId,troops)
    local ok,result=state:attack(player.UserId,tostring(cellId),troops)
    if not ok then notify(player,result,"error"); return end
    notify(player,"الهجوم في الطريق #"..result,"success")
end)

NavalAttack.OnServerEvent:Connect(function(player,cellId,troops)
    local nation=state:getNationForPlayer(player.UserId)
    if not nation then notify(player,"اختر دولة أولاً.","error"); return end
    local ok,result=state:queueAttack(nation.id,tostring(cellId),troops,true)
    if not ok then notify(player,result,"error"); return end
    notify(player,"تم إطلاق الإنزال البحري #"..result,"success")
end)

Build.OnServerEvent:Connect(function(player,cellId,kind)
    local ok,result=state:build(player.UserId,tostring(cellId),tostring(kind))
    if not ok then notify(player,result,"error"); return end
    notify(player,"تم بناء "..tostring(result.kind),"success")
    broadcast()
end)

Nuke.OnServerEvent:Connect(function(player,cellId)
    local ok,result=state:launchNuke(player.UserId,tostring(cellId))
    if not ok then notify(player,result,"error"); return end
    notify(player,"تم إطلاق الضربة الاستراتيجية.","warning")
    broadcast()
end)

AllianceOffer.OnServerEvent:Connect(function(player,targetUserId)
    local ok,err=state:proposeAlliance(player.UserId,tonumber(targetUserId))
    if not ok then notify(player,err,"error"); return end
    notify(player,"تم إرسال عرض التحالف.","success")
end)

AllianceRespond.OnServerEvent:Connect(function(player,accept)
    local ok,err=state:respondAlliance(player.UserId,accept==true)
    if not ok then notify(player,err,"error"); return end
    notify(player,accept and "تم قبول التحالف." or "تم رفض التحالف.","success")
    broadcast()
end)

RequestSnapshot.OnServerEvent:Connect(function(player) send(player) end)

Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        send(player)
        notify(player,"اختر دولة ملونة غير محتلة. القبائل مناطق AI.","info")
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
        local dt=math.min(2,now-last); last=now

        if not state.matchOver then
            local events=state:tick(dt)

            for id,nation in pairs(state.nations) do
                if nation.isAI and #nation.cellIds>0 and now>=(aiNext[id] or 0) then
                    aiNext[id]=now+Rules.AI.ThinkMinSeconds+math.random()*(Rules.AI.ThinkMaxSeconds-Rules.AI.ThinkMinSeconds)

                    local targets=state:findAttackTargets(id)
                    if #targets>0 and nation.troops>=Rules.AI.MinimumAttackTroops then
                        local target=targets[math.random(1,#targets)]
                        local commit=math.floor(nation.troops*Rules.AI.AttackReserveRatio)
                        if commit>=Rules.AI.MinimumAttackTroops then
                            state:queueAttack(id,target,commit,false)
                        end
                    elseif nation.gold>=Rules.AI.CityReserveGold then
                        for _,cellId in ipairs(nation.cellIds) do
                            local cell=map.cellsById[cellId]
                            if cell and not cell.building then
                                local kind=cell.isCoastal and "Port" or "City"
                                local def=Rules.Buildings[kind]
                                if nation.gold>=def.Cost then
                                    nation.gold-=def.Cost
                                    cell.building={kind=kind,level=1,health=100}
                                    break
                                end
                            end
                        end
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

print("[WorldPvP] Runtime online | 55-player target | "..tostring(#entities).." world entities")
