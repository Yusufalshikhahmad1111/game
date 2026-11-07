-- High-resolution World PvP client.
local Players=game:GetService("Players")
local AssetService=game:GetService("AssetService")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Rules=require(Shared.WorldPvP.Rules)
local remotes=ReplicatedStorage:WaitForChild("WorldPvPRemotes")
local Spawn=remotes:WaitForChild("Spawn")
local Attack=remotes:WaitForChild("Attack")
local Build=remotes:WaitForChild("Build")
local Nuke=remotes:WaitForChild("Nuke")
local Request=remotes:WaitForChild("RequestSnapshot")
local Snapshot=remotes:WaitForChild("Snapshot")
local Chunk=remotes:WaitForChild("MapChunk")
local Notice=remotes:WaitForChild("Notice")

local W,H=Rules.MapWidth,Rules.MapHeight
local ZOOM_MIN,ZOOM_MAX=.65,4.5
local zoom=1
local pan=Vector2.zero
local dragging=false
local dragStart=Vector2.zero
local panStart=Vector2.zero
local snapshot=nil
local myId=nil
local selectedTile=nil
local ratio=.20
local ownerByTile={}
local landByTile={}
local terrainByTile={}
local colorCache={}
local image=AssetService:CreateEditableImage({Size=Vector2.new(W,H)})

local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=100
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromRGB(5,9,14);root.BorderSizePixel=0;root.Parent=gui

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,58);top.BackgroundColor3=Color3.fromRGB(11,17,25);top.BorderSizePixel=0;top.ZIndex=10;top.Parent=root
local brand=Instance.new("TextLabel")
brand.Size=UDim2.fromOffset(190,58);brand.Position=UDim2.fromOffset(18,0);brand.BackgroundTransparency=1
brand.Text="WORLD PvP";brand.Font=Enum.Font.GothamBlack;brand.TextSize=22;brand.TextColor3=Color3.fromRGB(240,245,250)
brand.TextXAlignment=Enum.TextXAlignment.Left;brand.Parent=top
local topStats=Instance.new("TextLabel")
topStats.Size=UDim2.new(1,-430,1,0);topStats.Position=UDim2.fromOffset(215,0);topStats.BackgroundTransparency=1
topStats.Text="Loading world...";topStats.Font=Enum.Font.GothamBold;topStats.TextSize=13
topStats.TextColor3=Color3.fromRGB(178,191,207);topStats.TextXAlignment=Enum.TextXAlignment.Left;topStats.Parent=top

local viewport=Instance.new("Frame")
viewport.Name="WorldViewport";viewport.Size=UDim2.new(1,0,1,-142);viewport.Position=UDim2.fromOffset(0,58)
viewport.BackgroundColor3=Color3.fromRGB(5,25,41);viewport.BorderSizePixel=0;viewport.ClipsDescendants=true;viewport.Parent=root

local mapLayer=Instance.new("Frame")
mapLayer.BackgroundTransparency=1;mapLayer.AnchorPoint=Vector2.new(.5,.5);mapLayer.Position=UDim2.fromScale(.5,.5)
mapLayer.Size=UDim2.fromScale(1,1);mapLayer.Parent=viewport

local mapImage=Instance.new("ImageLabel")
mapImage.Name="PixelWorld";mapImage.AnchorPoint=Vector2.new(.5,.5);mapImage.Position=UDim2.fromScale(.5,.5)
mapImage.Size=UDim2.fromScale(1,1);mapImage.BackgroundTransparency=1;mapImage.ResampleMode=Enum.ResamplerMode.Pixelated
mapImage.ImageContent=Content.fromObject(image);mapImage.Parent=mapLayer

local click=Instance.new("ImageButton")
click.Size=UDim2.fromScale(1,1);click.BackgroundTransparency=1;click.ImageTransparency=1;click.AutoButtonColor=false;click.ZIndex=3;click.Parent=mapLayer

local selection=Instance.new("Frame")
selection.Size=UDim2.fromOffset(16,16);selection.AnchorPoint=Vector2.new(.5,.5);selection.BackgroundTransparency=1
selection.BorderSizePixel=2;selection.BorderColor3=Color3.fromRGB(255,255,255);selection.Visible=false;selection.ZIndex=4;selection.Parent=mapLayer

local function rounded(parent)
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,9);c.Parent=parent
end
local function button(parent,text,pos,size,callback)
    local b=Instance.new("TextButton")
    b.Size=size or UDim2.fromOffset(40,36);b.Position=pos;b.BackgroundColor3=Color3.fromRGB(25,38,52);b.BorderSizePixel=0
    b.Text=text;b.TextColor3=Color3.fromRGB(237,243,249);b.Font=Enum.Font.GothamBold;b.TextSize=11;b.ZIndex=30;b.Parent=parent
    rounded(b);b.MouseButton1Click:Connect(callback);return b
end

local zoomBox=Instance.new("Frame")
zoomBox.Size=UDim2.fromOffset(48,100);zoomBox.Position=UDim2.new(1,-62,0,76);zoomBox.BackgroundColor3=Color3.fromRGB(13,21,31)
zoomBox.BackgroundTransparency=.05;zoomBox.BorderSizePixel=0;zoomBox.ZIndex=20;zoomBox.Parent=root;rounded(zoomBox)
button(zoomBox,"+",UDim2.fromOffset(5,5),nil,function() zoom=math.min(ZOOM_MAX,zoom+.25) end)
button(zoomBox,"−",UDim2.fromOffset(5,51),nil,function() zoom=math.max(ZOOM_MIN,zoom-.25) end)

local board=Instance.new("Frame")
board.Size=UDim2.fromOffset(225,246);board.Position=UDim2.fromOffset(14,72);board.BackgroundColor3=Color3.fromRGB(10,17,26)
board.BackgroundTransparency=.04;board.BorderSizePixel=0;board.ZIndex=20;board.Parent=root;rounded(board)
local boardTitle=Instance.new("TextLabel")
boardTitle.Size=UDim2.new(1,-18,0,32);boardTitle.Position=UDim2.fromOffset(9,4);boardTitle.BackgroundTransparency=1
boardTitle.Text="WORLD RANKING";boardTitle.Font=Enum.Font.GothamBlack;boardTitle.TextSize=12;boardTitle.TextColor3=Color3.fromRGB(225,234,243)
boardTitle.TextXAlignment=Enum.TextXAlignment.Left;boardTitle.ZIndex=21;boardTitle.Parent=board
local boardList=Instance.new("ScrollingFrame")
boardList.Size=UDim2.new(1,-18,1,-42);boardList.Position=UDim2.fromOffset(9,38);boardList.BackgroundTransparency=1
boardList.BorderSizePixel=0;boardList.ScrollBarThickness=3;boardList.ZIndex=21;boardList.Parent=board
local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,3);list.Parent=boardList

local dock=Instance.new("Frame")
dock.Size=UDim2.new(1,-24,0,78);dock.Position=UDim2.new(0,12,1,-90);dock.BackgroundColor3=Color3.fromRGB(11,18,27)
dock.BorderSizePixel=0;dock.ZIndex=20;dock.Parent=root;rounded(dock)
local dockTitle=Instance.new("TextLabel")
dockTitle.Size=UDim2.fromOffset(112,78);dockTitle.Position=UDim2.fromOffset(12,0);dockTitle.BackgroundTransparency=1
dockTitle.Text="ARMY\nCOMMAND";dockTitle.Font=Enum.Font.GothamBlack;dockTitle.TextSize=13;dockTitle.TextColor3=Color3.fromRGB(230,237,246)
dockTitle.TextXAlignment=Enum.TextXAlignment.Left;dockTitle.TextYAlignment=Enum.TextYAlignment.Center;dockTitle.ZIndex=21;dockTitle.Parent=dock

local ratioButtons={}
for i,v in ipairs({.05,.10,.20,.35,.50,1}) do
    local b=button(dock,tostring(math.floor(v*100)).."%",UDim2.fromOffset(126+(i-1)*47,35),UDim2.fromOffset(43,34),function()
        ratio=v
        for _,x in ipairs(ratioButtons) do x.BackgroundColor3=Color3.fromRGB(25,38,52) end
        b.BackgroundColor3=Color3.fromRGB(44,106,164)
    end)
    ratioButtons[#ratioButtons+1]=b
    if v==ratio then b.BackgroundColor3=Color3.fromRGB(44,106,164) end
end
local sendLabel=Instance.new("TextLabel")
sendLabel.Size=UDim2.fromOffset(260,24);sendLabel.Position=UDim2.fromOffset(126,7);sendLabel.BackgroundTransparency=1
sendLabel.Text="SEND ARMY";sendLabel.Font=Enum.Font.GothamBold;sendLabel.TextSize=10;sendLabel.TextColor3=Color3.fromRGB(128,149,170)
sendLabel.TextXAlignment=Enum.TextXAlignment.Left;sendLabel.ZIndex=21;sendLabel.Parent=dock

local selectedLabel=Instance.new("TextLabel")
selectedLabel.Size=UDim2.new(0,245,0,52);selectedLabel.Position=UDim2.new(1,-640,0,12);selectedLabel.BackgroundTransparency=1
selectedLabel.Text="Select a pixel";selectedLabel.TextWrapped=true;selectedLabel.Font=Enum.Font.GothamBold;selectedLabel.TextSize=11
selectedLabel.TextColor3=Color3.fromRGB(180,194,211);selectedLabel.TextXAlignment=Enum.TextXAlignment.Left;selectedLabel.ZIndex=21;selectedLabel.Parent=dock

local function buildButton(text,x,kind)
    return button(dock,text,UDim2.new(1,x,0,22),nil,function()
        if selectedTile then Build:FireServer(selectedTile,kind) end
    end)
end
buildButton("CITY",-370,"City").Size=UDim2.fromOffset(62,34)
buildButton("FACTORY",-302,"Factory").Size=UDim2.fromOffset(72,34)
buildButton("PORT",-224,"Port").Size=UDim2.fromOffset(58,34)
buildButton("DEFENSE",-160,"DefensePost").Size=UDim2.fromOffset(70,34)
buildButton("NUKE",-84,"MissileSilo").Size=UDim2.fromOffset(72,34)

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(0,380,0,38);notice.Position=UDim2.new(.5,-190,0,66);notice.BackgroundColor3=Color3.fromRGB(12,19,28)
notice.BackgroundTransparency=.08;notice.BorderSizePixel=0;notice.Text="";notice.TextWrapped=true;notice.Font=Enum.Font.GothamBold;notice.TextSize=11
notice.TextColor3=Color3.fromRGB(173,231,190);notice.ZIndex=50;notice.Parent=root;rounded(notice)

local function ownerColor(index)
    if index==0 then return Color3.fromRGB(81,89,97) end
    if colorCache[index] then return colorCache[index] end
    local id=snapshot and snapshot.ownerIds and snapshot.ownerIds[index]
    local p=id and snapshot.players and snapshot.players[id]
    local c=p and p.color
    local out=c and Color3.new(c[1] or c.r or .3,c[2] or c.g or .5,c[3] or c.b or .7) or Color3.fromRGB(120,135,150)
    colorCache[index]=out;return out
end

local terrainTint={
    [0]=1,[1]=1,[2]=.88,[3]=.78,[4]=.64
}
local function paintTile(id)
    local owner=ownerByTile[id] or 0
    local land=landByTile[id]
    local terrain=terrainByTile[id] or 1
    local c
    if not land then c=Color3.fromRGB(7,30,49)
    elseif owner==0 then c=Color3.fromRGB(92,96,91)
    else
        local base=ownerColor(owner);local k=terrainTint[terrain] or 1
        c=Color3.new(math.clamp(base.R*k,0,1),math.clamp(base.G*k,0,1),math.clamp(base.B*k,0,1))
    end
    local x=(id-1)%W
    local y=math.floor((id-1)/W)
    local b=buffer.create(4)
    buffer.writeu8(b,0,math.floor(c.R*255));buffer.writeu8(b,1,math.floor(c.G*255));buffer.writeu8(b,2,math.floor(c.B*255));buffer.writeu8(b,3,255)
    image:WritePixelsBuffer(Vector2.new(x,y),Vector2.one,b)
end

local function paintChunk(packet)
    local count=packet.w*packet.h
    local out=buffer.create(count*4)
    for i=0,count-1 do
        local src=i*4
        local owner=buffer.readu16(packet.data,src)
        local land=buffer.readu8(packet.data,src+2)==1
        local terrain=buffer.readu8(packet.data,src+3)
        local id=(packet.y+math.floor(i/packet.w)-1)*W+(packet.x+(i%packet.w))
        ownerByTile[id]=owner;landByTile[id]=land;terrainByTile[id]=terrain
        local c
        if not land then c=Color3.fromRGB(7,30,49)
        elseif owner==0 then c=Color3.fromRGB(92,96,91)
        else
            local base=ownerColor(owner);local k=terrainTint[terrain] or 1
            c=Color3.new(math.clamp(base.R*k,0,1),math.clamp(base.G*k,0,1),math.clamp(base.B*k,0,1))
        end
        local p=i*4
        buffer.writeu8(out,p,math.floor(c.R*255));buffer.writeu8(out,p+1,math.floor(c.G*255));buffer.writeu8(out,p+2,math.floor(c.B*255));buffer.writeu8(out,p+3,255)
    end
    image:WritePixelsBuffer(Vector2.new(packet.x-1,packet.y-1),Vector2.new(packet.w,packet.h),out)
end

local function applyTransform()
    mapLayer.Size=UDim2.fromScale(zoom,zoom)
    mapLayer.Position=UDim2.new(.5,pan.X,.5,pan.Y)
end

local function screenToTile(pos)
    local abs=click.AbsolutePosition
    local size=click.AbsoluteSize
    local localX=math.clamp((pos.X-abs.X)/math.max(1,size.X),0,0.999999)
    local localY=math.clamp((pos.Y-abs.Y)/math.max(1,size.Y),0,0.999999)
    local x=math.floor(localX*W)+1
    local y=math.floor(localY*H)+1
    return (y-1)*W+x
end

local function selectTile(id)
    if not id then return end
    selectedTile=id
    local owner=ownerByTile[id] or 0
    local ownerId=snapshot and snapshot.ownerIds and snapshot.ownerIds[owner]
    local p=ownerId and snapshot.players and snapshot.players[ownerId]
    selectedLabel.Text=(p and p.name or (landByTile[id] and "Neutral Land" or "Sea")).."  •  pixel "..id
    local x=(id-1)%W;local y=math.floor((id-1)/W)
    selection.Position=UDim2.new((x+.5)/W,(0),(y+.5)/H,0);selection.Visible=true
end

click.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        dragging=true;dragStart=Vector2.new(input.Position.X,input.Position.Y);panStart=pan;return
    end
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    local pos=Vector2.new(input.Position.X,input.Position.Y)
    local id=screenToTile(pos);selectTile(id)
    if not snapshot or not landByTile[id] then return end
    local owner=ownerByTile[id] or 0
    if not myId and owner==0 then Spawn:FireServer(id)
    elseif myId and owner~=0 and owner~=snapshot.ownerIds[myId] then Attack:FireServer(id,ratio)
    end
end)

click.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement and dragging then
        local d=Vector2.new(input.Position.X,input.Position.Y)-dragStart
        pan=panStart+d;applyTransform()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=false end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseWheel then
        zoom=math.clamp(zoom+input.Position.Z*.18,ZOOM_MIN,ZOOM_MAX);applyTransform()
    end
end)

Snapshot.OnClientEvent:Connect(function(data)
    snapshot=data;colorCache={}
    myId=nil
    for id,p in pairs(data.players or {}) do if p.userId==player.UserId then myId=id;break end end
    if myId and data.players[myId] then
        local me=data.players[myId]
        topStats.Text="⚔ "..math.floor(me.troops).."    🪙 "..math.floor(me.gold).."    ▣ "..me.owned.." / "..data.totalLand.."    • "..tostring(me.name)
    else
        topStats.Text="DEPLOY • "..tostring(data.width).." × "..tostring(data.height).." PIXELS"
    end
    for _,change in ipairs(data.tileChanges or {}) do
        ownerByTile[change.id]=change.ownerIndex
        if change.isLand~=nil then landByTile[change.id]=change.isLand==1 end
        terrainByTile[change.id]=change.terrain or terrainByTile[change.id] or 1
        paintTile(change.id)
    end
    boardList:ClearAllChildren()
    for i,p in ipairs((function()
        local e={};for _,v in pairs(data.players or {}) do e[#e+1]=v end
        table.sort(e,function(a,b)return (a.owned or 0)>(b.owned or 0) end);return e
    end)()) do
        if i>8 then break end
        local row=Instance.new("TextLabel");row.Size=UDim2.new(1,-4,0,22);row.BackgroundTransparency=1
        row.Text=string.format("%d  %s   %d",i,tostring(p.name),tonumber(p.owned) or 0);row.Font=Enum.Font.GothamBold;row.TextSize=10
        row.TextColor3=p.userId==player.UserId and Color3.fromRGB(105,207,255) or Color3.fromRGB(190,201,214)
        row.TextXAlignment=Enum.TextXAlignment.Left;row.ZIndex=22;row.Parent=boardList
    end
    boardList.CanvasSize=UDim2.fromOffset(0,math.max(0,#data.players*25))
    if data.winner then
        local win=data.players[data.winner]
        notice.Text="🏆 "..tostring(win and win.name or data.winner).." controls 80% of the world."
        notice.TextColor3=Color3.fromRGB(255,215,110)
    end
end)

Chunk.OnClientEvent:Connect(paintChunk)
Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    notice.TextColor3=data.kind=="error" and Color3.fromRGB(255,135,135) or Color3.fromRGB(173,231,190)
end)

applyTransform()
Request:FireServer()
