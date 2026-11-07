-- server_worldpvp/WorldPvPGame.server.lua
-- Direct-start World PvP. There is intentionally no lobby and no character gameplay.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
Players.CharacterAutoLoads=false

local Shared=ReplicatedStorage:WaitForChild("Shared")
local State=require(Shared.WorldPvP.PixelWorldState)
local world=State.new()

local remotes=ReplicatedStorage:FindFirstChild("WorldPvPRemotes") or Instance.new("Folder")
remotes.Name="WorldPvPRemotes"; remotes.Parent=ReplicatedStorage

local function event(name)
    local e=remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    e.Name=name;e.Parent=remotes;return e
end
local Spawn=event("Spawn")
local Attack=event("Attack")
local Request=event("RequestSnapshot")
local Snapshot=event("Snapshot")
local Notice=event("Notice")

local function send(p)
    Snapshot:FireClient(p,world:tileSnapshot())
end
local function broadcast()
    local data=world:tileSnapshot()
    for _,p in ipairs(Players:GetPlayers()) do Snapshot:FireClient(p,data) end
end
local function notice(p,msg,kind)
    Notice:FireClient(p,{message=msg,kind=kind or "info"})
end

Spawn.OnServerEvent:Connect(function(p,tileId)
    local ok,n=world:spawnHuman(p.UserId,p.DisplayName or p.Name,tonumber(tileId))
    if not ok then notice(p,n,"error");return end
    notice(p,"تم اختيار نقطة البداية. الآن أرسل نسبة من جيشك بالنقر على أي بكسل للعدو.","success")
    broadcast()
end)

Attack.OnServerEvent:Connect(function(p,tileId,ratio)
    local ok,result=world:attack(p.UserId,tonumber(tileId),ratio)
    if not ok then notice(p,result,"error");return end
    notice(p,"تم إرسال الجيش "..math.floor((tonumber(ratio) or .2)*100).."% إلى الجبهة.","success")
end)

Request.OnServerEvent:Connect(send)

Players.PlayerAdded:Connect(function(p)
    task.defer(function()
        send(p)
        notice(p,"انقر على أي أرض غير محتلة لتحديد نقطة البداية.","info")
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    local n=world.byUser[p.UserId]
    if n then
        n.userId=nil
        n.isAI=true
        n.kind="Nation"
        n.displayName=n.name
        world.byUser[p.UserId]=nil
    end
end)

task.spawn(function()
    local last=os.clock()
    local nextBroadcast=0
    while true do
        task.wait(0.1)
        local now=os.clock()
        world:tick(math.min(.25,now-last))
        last=now
        if now>=nextBroadcast then
            nextBroadcast=now+.3
            broadcast()
        end
    end
end)

print("[WorldPvP] Pixel World online | "..tostring(world.map.width).."x"..tostring(world.map.height).." | direct start | no lobby | no avatars")
