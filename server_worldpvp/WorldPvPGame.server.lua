-- WorldDominion 3D lobby -> Pixel PvP gate.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads=true

local Shared=ReplicatedStorage:WaitForChild("Shared")
local State=require(Shared.WorldPvP.PixelWorldState)
local Rules=require(Shared.WorldPvP.Rules)
local MapRegistry=require(Shared.WorldPvP.MapRegistry)

local world=nil
local worldActive=false
local matchMode=nil
local matchMap=nil

local remotes=ReplicatedStorage:FindFirstChild("WorldPvPRemotes") or Instance.new("Folder")
remotes.Name="WorldPvPRemotes"
remotes.Parent=ReplicatedStorage

local function event(name)
    local e=remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    e.Name=name
    e.Parent=remotes
    return e
end

local Spawn=event("Spawn")
local Attack=event("Attack")
local Build=event("Build")
local Nuke=event("Nuke")
local SelectMode=event("SelectMode")
local SelectMap=event("SelectMap")
local EnterWorld=event("EnterWorld")
local Request=event("RequestSnapshot")
local Snapshot=event("Snapshot")
local Chunk=event("MapChunk")
local Notice=event("Notice")

local function notice(player,message,kind)
    Notice:FireClient(player,{message=message,kind=kind or "info"})
end

local function isInWorld(player)
    return player:GetAttribute("WorldDominionActive")==true
end

local function lobby()
    return workspace:FindFirstChild("Lobby")
end

local function setLobbyColor(name,color)
    local root=lobby()
    local part=root and root:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        part.Color=color
    end
end

local function sendMetadata(player)
    if world and worldActive and isInWorld(player) then
        Snapshot:FireClient(player,world:metadataSnapshot())
    end
end

local function sendChunk(player,cx,cy)
    if not world or not worldActive then return end
    local size=Rules.Render.ChunkSize
    local x0=(cx-1)*size+1
    local y0=(cy-1)*size+1
    if x0>world.map.width or y0>world.map.height then return end

    local w=math.min(size,world.map.width-x0+1)
    local h=math.min(size,world.map.height-y0+1)
    local packed=buffer.create(w*h*4)
    local k=0

    for y=y0,y0+h-1 do
        for x=x0,x0+w-1 do
            local tile=world.map:get((y-1)*world.map.width+x)
            local owner=tile.ownerId==0 and 0 or (world.ownerIndexById[tile.ownerId] or 0)
            buffer.writeu16(packed,k,owner)
            buffer.writeu8(packed,k+2,tile.isLand and 1 or 0)
            buffer.writeu8(packed,k+3,Rules.TerrainCodes[tile.terrain] or 0)
            k+=4
        end
    end

    Chunk:FireClient(player,{x=x0,y=y0,w=w,h=h,data=packed})
end

local function sendWorld(player)
    if not world or not worldActive or not isInWorld(player) then return end

    sendMetadata(player)

    task.spawn(function()
        local size=Rules.Render.ChunkSize
        local cols=math.ceil(world.map.width/size)
        local rows=math.ceil(world.map.height/size)
        local sent=0

        for cy=1,rows do
            for cx=1,cols do
                if not player.Parent or not worldActive then return end
                sendChunk(player,cx,cy)
                sent+=1
                if sent%Rules.Render.ChunksPerBurst==0 then task.wait() end
            end
        end
    end)
end

local function broadcast()
    if not world or not worldActive then return end
    local data=world:tileDeltaSnapshot()
    for _,player in ipairs(Players:GetPlayers()) do
        if isInWorld(player) then
            Snapshot:FireClient(player,data)
        end
    end
end

local function startMatch(player,mapId)
    local definition=MapRegistry.get(mapId)
    if not definition then
        notice(player,"الخريطة غير موجودة.","error")
        return
    end

    local mode=player:GetAttribute("WorldDominionMode")
    if mode~="Teams" and mode~="FFA" and mode~="Solo" then
        notice(player,"اختر Teams أو FFA أو Solo أولاً.","error")
        return
    end

    -- Once a match exists, later players may join it only when their chosen
    -- mode and map match the active match.
    if worldActive then
        if mode~=matchMode or definition.id~=matchMap then
            notice(player,"اختيارك لا يطابق المباراة الحالية: "..tostring(matchMap).." / "..tostring(matchMode)..".","error")
            return
        end
        player:SetAttribute("WorldDominionActive",true)
        EnterWorld:FireClient(player,{mode=matchMode,mapKey=matchMap,mapTitle=definition.title})
        sendWorld(player)
        notice(player,"انضممت إلى المباراة الحالية.","success")
        return
    end

    matchMode=mode
    matchMap=definition.id
    world=State.new({mapKey=definition.id,modeKey=mode})
    worldActive=true

    for _,other in ipairs(Players:GetPlayers()) do
        other:SetAttribute("WorldDominionActive",false)
    end
    player:SetAttribute("WorldDominionActive",true)

    -- Move the 3D avatar out of the battle viewport; the map becomes the
    -- primary play surface after the lobby transition.
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame=CFrame.new(0,500,0)
    end

    EnterWorld:FireClient(player,{mode=mode,mapKey=matchMap,mapTitle=definition.title})
    notice(player,"تم الدخول إلى "..tostring(definition.title)..". اختر نقطة بداية على الأرض.","success")
end

SelectMode.OnServerEvent:Connect(function(player,mode)
    if worldActive then
        notice(player,"المباراة بدأت بالفعل.","error")
        return
    end

    mode=tostring(mode or "")
    if mode~="Teams" and mode~="FFA" and mode~="Solo" then
        notice(player,"نمط غير صالح.","error")
        return
    end

    player:SetAttribute("WorldDominionMode",mode)
    local colors={
        Teams=Color3.fromRGB(137,169,88),
        FFA=Color3.fromRGB(218,177,91),
        Solo=Color3.fromRGB(155,105,66),
    }
    setLobbyColor("Teams",colors.Teams)
    setLobbyColor("FFA",colors.FFA)
    setLobbyColor("Solo",colors.Solo)
    setLobbyColor(mode,Color3.fromRGB(244,237,218))

    notice(player,"اخترت "..mode..". الآن اختر الخريطة.","success")
end)

SelectMap.OnServerEvent:Connect(function(player,mapId)
    if worldActive then
        notice(player,"هناك مباراة جارية بالفعل.","error")
        return
    end

    local definition=MapRegistry.get(tostring(mapId or ""))
    if not definition then
        notice(player,"خريطة غير صالحة.","error")
        return
    end

    player:SetAttribute("WorldDominionMap",definition.id)
    notice(player,"اخترت "..definition.title..". الآن اقترب من ENTER WORLD.","success")
end)

Spawn.OnServerEvent:Connect(function(player,tileId)
    if not world or not worldActive or not isInWorld(player) then
        notice(player,"ارجع إلى لوبي 404 FOUND واختر النمط والخريطة.","error")
        return
    end

    local ok,result=world:spawnHuman(player.UserId,player.DisplayName or player.Name,tonumber(tileId))
    if not ok then
        notice(player,result,"error")
        return
    end
    notice(player,"تم اختيار نقطة البداية. حدد أرض العدو ثم أرسل العدد المطلوب من الجنود.","success")
    broadcast()
end)

Attack.OnServerEvent:Connect(function(player,tileId,amount)
    if not world or not worldActive or not isInWorld(player) then
        notice(player,"لم تدخل المباراة بعد.","error")
        return
    end
    local ok,attackId,sentTroops=world:attack(player.UserId,tonumber(tileId),amount)
    if not ok then
        notice(player,attackId,"error")
        return
    end
    notice(player,"تم إرسال "..tostring(math.floor(sentTroops or 0)).." جندي إلى الجبهة.","success")
end)

Build.OnServerEvent:Connect(function(player,tileId,kind)
    if not world or not worldActive or not isInWorld(player) then
        notice(player,"لم تدخل المباراة بعد.","error")
        return
    end
    local ok,msg=world:build(player.UserId,tonumber(tileId),tostring(kind))
    if not ok then
        notice(player,msg,"error")
    else
        notice(player,"تم بناء "..tostring(kind),"success")
    end
end)

Nuke.OnServerEvent:Connect(function(player,tileId,weaponKind)
    if not world or not worldActive or not isInWorld(player) then
        notice(player,"لم تدخل المباراة بعد.","error")
        return
    end
    local ok,msg=world:nuke(player.UserId,tonumber(tileId),tostring(weaponKind or "Atom"))
    if not ok then
        notice(player,msg,"error")
    else
        notice(player,"☢ تم إطلاق "..tostring(weaponKind or "Atom")..".","success")
    end
end)

Request.OnServerEvent:Connect(function(player)
    if not worldActive then
        notice(player,"أهلاً بك في 404 FOUND. اختر Teams أو FFA أو Solo ثم الخريطة.","info")
        return
    end

    if not isInWorld(player) then
        player:SetAttribute("WorldDominionActive",true)
        EnterWorld:FireClient(player,{mode=matchMode,mapKey=matchMap,mapTitle=world.mapTitle})
    end
    sendWorld(player)
end)

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("WorldDominionActive",false)
    player:SetAttribute("WorldDominionMode","FFA")
    player:SetAttribute("WorldDominionMap",MapRegistry.Default)
    task.defer(function()
        notice(player,"أهلاً بك في بيت 404 FOUND. اختر نمط اللعب ثم الخريطة.","info")
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if world and world.byUser[player.UserId] then
        local nation=world.byUser[player.UserId]
        nation.userId=nil
        nation.isAI=true
        nation.kind="Nation"
        nation.displayName=nation.name
        world.byUser[player.UserId]=nil
    end
end)

-- Physical 3D lobby controls. The geometry is static in Workspace,
-- therefore it is visible in Edit mode before Play.
task.defer(function()
    local root=lobby()
    if not root then
        warn("[WorldPvP] 404 FOUND lobby model missing from Workspace")
        return
    end

    local modeEntries={
        {prompt=root.ModePads and root.ModePads.Teams and root.ModePads.Teams:FindFirstChild("TeamsPrompt"),mode="Teams"},
        {prompt=root.ModePads and root.ModePads.FFA and root.ModePads.FFA:FindFirstChild("FFAPrompt"),mode="FFA"},
        {prompt=root.ModePads and root.ModePads.Solo and root.ModePads.Solo:FindFirstChild("SoloPrompt"),mode="Solo"},
    }
    local mapEntries={
        {prompt=root.MapPads and root.MapPads.World and root.MapPads.World:FindFirstChild("WorldPrompt"),map="World"},
        {prompt=root.MapPads and root.MapPads.Europe and root.MapPads.Europe:FindFirstChild("EuropePrompt"),map="Europe"},
        {prompt=root.MapPads and root.MapPads.Asia and root.MapPads.Asia:FindFirstChild("AsiaPrompt"),map="Asia"},
        {prompt=root.MapPads and root.MapPads.MENA and root.MapPads.MENA:FindFirstChild("MENAPrompt"),map="MENA"},
    }

    for _,entry in ipairs(modeEntries) do
        if entry.prompt then
            entry.prompt.Triggered:Connect(function(player)
                if worldActive then
                    notice(player,"المباراة بدأت بالفعل. لا يمكن تغيير النمط الآن.","error")
                    return
                end
                player:SetAttribute("WorldDominionMode",entry.mode)
                notice(player,"تم اختيار "..entry.mode..". الآن اختر الخريطة.","success")
            end)
        end
    end

    for _,entry in ipairs(mapEntries) do
        if entry.prompt then
            entry.prompt.Triggered:Connect(function(player)
                if worldActive then
                    notice(player,"المباراة بدأت بالفعل. انضم إلى المباراة الحالية من نفس الإعدادات.","error")
                    return
                end
                local definition=MapRegistry.get(entry.map)
                player:SetAttribute("WorldDominionMap",definition.id)
                notice(player,"تم اختيار "..definition.title..". اقترب من ENTER WORLD للدخول.","success")
            end)
        end
    end

    local enterPrompt=root.EnterPad and root.EnterPad:FindFirstChild("EnterPrompt")
    if enterPrompt then
        enterPrompt.Triggered:Connect(function(player)
            local mode=player:GetAttribute("WorldDominionMode") or "FFA"
            local mapId=player:GetAttribute("WorldDominionMap") or MapRegistry.Default
            player:SetAttribute("WorldDominionMode",mode)
            player:SetAttribute("WorldDominionMap",mapId)
            startMatch(player,mapId)
        end)
    end

    local sign=root:FindFirstChild("House404") and root.House404:FindFirstChild("Sign")
    local signGui=sign and sign:FindFirstChild("SignGui")
    local signText=signGui and signGui:FindFirstChild("SignText")
    if signText and signText:IsA("TextLabel") then
        signText.Text="404 FOUND"
    end

    local attachedBillboards={
        {root.ModePads and root.ModePads.Teams,"TeamsBillboard"},
        {root.ModePads and root.ModePads.FFA,"FFABillboard"},
        {root.ModePads and root.ModePads.Solo,"SoloBillboard"},
        {root.MapPads and root.MapPads.World,"WorldBillboard"},
        {root.MapPads and root.MapPads.Europe,"EuropeBillboard"},
        {root.MapPads and root.MapPads.Asia,"AsiaBillboard"},
        {root.MapPads and root.MapPads.MENA,"MENABillboard"},
        {root.EnterPad,"EnterBillboard"},
    }
    for _,entry in ipairs(attachedBillboards) do
        local part=entry[1]
        local billboard=part and part:FindFirstChild(entry[2])
        if billboard then billboard.Adornee=part end
    end
end)

task.spawn(function()
    local last=os.clock()
    local nextBroadcast=0

    while true do
        task.wait(.1)

        local now=os.clock()
        local dt=math.min(.25,now-last)
        last=now

        if world and worldActive then
            world:tick(dt)
            if now>=nextBroadcast then
                nextBroadcast=now+Rules.SnapshotSeconds
                broadcast()
            end
        end
    end
end)

print("[WorldPvP] 404 FOUND lobby online | waiting for mode + map selection")
