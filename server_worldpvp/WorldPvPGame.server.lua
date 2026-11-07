-- Direct-start World PvP server. No lobby and no character gameplay.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
Players.CharacterAutoLoads=false
local Shared=ReplicatedStorage:WaitForChild("Shared")
local State=require(Shared.WorldPvP.PixelWorldState)
local Rules=require(Shared.WorldPvP.Rules)
local world=State.new()
local remotes=ReplicatedStorage:FindFirstChild("WorldPvPRemotes") or Instance.new("Folder")
remotes.Name="WorldPvPRemotes";remotes.Parent=ReplicatedStorage
local function event(name)
    local e=remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    e.Name=name;e.Parent=remotes;return e
end
local Spawn=event("Spawn");local Attack=event("Attack");local Build=event("Build");local Nuke=event("Nuke")
local Request=event("RequestSnapshot");local Snapshot=event("Snapshot");local Chunk=event("MapChunk");local Notice=event("Notice")
local function sendMetadata(p) Snapshot:FireClient(p,world:metadataSnapshot()) end
local function sendChunk(p,cx,cy)
    local size=Rules.Render.ChunkSize
    local x0=(cx-1)*size+1;local y0=(cy-1)*size+1
    if x0>world.map.width or y0>world.map.height then return end
    local w=math.min(size,world.map.width-x0+1);local h=math.min(size,world.map.height-y0+1)
    local packed=buffer.create(w*h*4);local k=0
    for y=y0,y0+h-1 do for x=x0,x0+w-1 do
        local tile=world.map:get((y-1)*world.map.width+x)
        local owner=tile.ownerId==0 and 0 or (world.ownerIndexById[tile.ownerId] or 0)
        buffer.writeu16(packed,k,owner);buffer.writeu8(packed,k+2,tile.isLand and 1 or 0)
        buffer.writeu8(packed,k+3,Rules.TerrainCodes[tile.terrain] or 0);k+=4
    end end
    Chunk:FireClient(p,{x=x0,y=y0,w=w,h=h,data=packed})
end
local function sendWorld(p)
    sendMetadata(p)
    task.spawn(function()
        local size=Rules.Render.ChunkSize;local cols=math.ceil(world.map.width/size);local rows=math.ceil(world.map.height/size);local sent=0
        for cy=1,rows do for cx=1,cols do
            if not p.Parent then return end
            sendChunk(p,cx,cy);sent+=1
            if sent%Rules.Render.ChunksPerBurst==0 then task.wait() end
        end end
    end)
end
local function broadcast()
    local data=world:tileDeltaSnapshot()
    for _,p in ipairs(Players:GetPlayers()) do Snapshot:FireClient(p,data) end
end
local function notice(p,msg,kind) Notice:FireClient(p,{message=msg,kind=kind or "info"}) end
Spawn.OnServerEvent:Connect(function(p,tileId)
    local ok,n=world:spawnHuman(p.UserId,p.DisplayName or p.Name,tonumber(tileId))
    if not ok then notice(p,n,"error");return end
    notice(p,"تم اختيار نقطة البداية. انقر على أرض العدو لإرسال الجيش.","success");broadcast()
end)
Attack.OnServerEvent:Connect(function(p,tileId,ratio)
    local ok,result=world:attack(p.UserId,tonumber(tileId),ratio)
    if not ok then notice(p,result,"error");return end
    notice(p,"تم إرسال "..math.floor((tonumber(ratio) or .2)*100).."% من الجيش إلى الجبهة.","success")
end)
Build.OnServerEvent:Connect(function(p,tileId,kind)
    local ok,msg=world:build(p.UserId,tonumber(tileId),tostring(kind))
    if not ok then notice(p,msg,"error") else notice(p,"تم بناء "..tostring(kind),"success") end
end)
Nuke.OnServerEvent:Connect(function(p,tileId)
    local ok,msg=world:nuke(p.UserId,tonumber(tileId))
    if not ok then notice(p,msg,"error") else notice(p,"☢ تم إطلاق الضربة النووية.","success") end
end)
Request.OnServerEvent:Connect(sendWorld)
Players.PlayerAdded:Connect(function(p) task.defer(function() sendWorld(p);notice(p,"انقر على أرض حرة لتحديد نقطة البداية.","info") end) end)
Players.PlayerRemoving:Connect(function(p)
    local n=world.byUser[p.UserId]
    if n then n.userId=nil;n.isAI=true;n.kind="Nation";n.displayName=n.name;world.byUser[p.UserId]=nil end
end)
task.spawn(function()
    local last=os.clock();local nextBroadcast=0
    while true do
        task.wait(.1);local now=os.clock();world:tick(math.min(.25,now-last));last=now
        if now>=nextBroadcast then nextBroadcast=now+Rules.SnapshotSeconds;broadcast() end
    end
end)
print("[WorldPvP] Pixel World online | "..world.map.width.."x"..world.map.height.." | direct start | no lobby | no avatars")