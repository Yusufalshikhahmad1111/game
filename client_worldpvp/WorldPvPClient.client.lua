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
local SelectMap=remotes:WaitForChild("SelectMap")
local Request=remotes:WaitForChild("RequestSnapshot")
local Snapshot=remotes:WaitForChild("Snapshot")
local Chunk=remotes:WaitForChild("MapChunk")
local Notice=remotes:WaitForChild("Notice")
local EnterWorld=remotes:WaitForChild("EnterWorld")

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
local selectedWeapon="Atom"
local ratio=.20
local THEME = {
    Background = Color3.fromRGB(18, 21, 16),
    Top = Color3.fromRGB(27, 31, 23),
    Panel = Color3.fromRGB(35, 37, 27),
    Button = Color3.fromRGB(57, 51, 36),
    Water = Color3.fromRGB(17, 35, 22),
    NeutralLand = Color3.fromRGB(124, 113, 83),
    Text = Color3.fromRGB(244, 237, 218),
    TextMuted = Color3.fromRGB(187, 177, 151),
    Success = Color3.fromRGB(137, 169, 88),
    Gold = Color3.fromRGB(218, 177, 91),
    Brown = Color3.fromRGB(155, 105, 66),
    Error = Color3.fromRGB(211, 112, 83),
}

local sendTroops=5000
local myTroops=0
local myMaxTroops=1
local regenPerSecond=0
local regenToFullSeconds=0
local ownerByTile={}
local landByTile={}
local terrainByTile={}
local colorCache={}
local image=AssetService:CreateEditableImage({Size=Vector2.new(W,H)})

local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=100
gui.Enabled=false
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=THEME.Background;root.BorderSizePixel=0;root.Parent=gui

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,58);top.BackgroundColor3=THEME.Top;top.BorderSizePixel=0;top.ZIndex=10;top.Parent=root
local brand=Instance.new("TextLabel")
brand.Size=UDim2.fromOffset(190,58);brand.Position=UDim2.fromOffset(18,0);brand.BackgroundTransparency=1
brand.Text="WORLD PvP";brand.Font=Enum.Font.GothamBlack;brand.TextSize=22;brand.TextColor3=THEME.Text
brand.TextXAlignment=Enum.TextXAlignment.Left;brand.Parent=top
local topStats=Instance.new("TextLabel")
topStats.Size=UDim2.new(1,-430,1,0);topStats.Position=UDim2.fromOffset(215,0);topStats.BackgroundTransparency=1
topStats.Text="Loading world...";topStats.Font=Enum.Font.GothamBold;topStats.TextSize=13
topStats.TextColor3=THEME.TextMuted;topStats.TextXAlignment=Enum.TextXAlignment.Left;topStats.Parent=top

local viewport=Instance.new("Frame")
viewport.Name="WorldViewport";viewport.Size=UDim2.new(1,0,1,-142);viewport.Position=UDim2.fromOffset(0,58)
viewport.BackgroundColor3=THEME.Water;viewport.BorderSizePixel=0;viewport.ClipsDescendants=true;viewport.Parent=root

local mapLayer=Instance.new("Frame")
mapLayer.BackgroundTransparency=1;mapLayer.AnchorPoint=Vector2.new(.5,.5);mapLayer.Position=UDim2.fromScale(.5,.5)
mapLayer.Size=UDim2.fromScale(1,1);mapLayer.Parent=viewport

local mapImage=Instance.new("ImageLabel")
mapImage.Name="PixelWorld";mapImage.AnchorPoint=Vector2.new(.5,.5);mapImage.Position=UDim2.fromScale(.5,.5)
mapImage.Size=UDim2.fromScale(1,1);mapImage.BackgroundTransparency=1;mapImage.ResampleMode=Enum.ResamplerMode.Pixelated
mapImage.ImageContent=Content.fromObject(image);mapImage.Parent=mapLayer

local click=Instance.new("ImageButton")
click.Size=UDim2.fromScale(1,1);click.BackgroundTransparency=1;click.ImageTransparency=1;click.AutoButtonColor=false;click.ZIndex=3;click.Parent=mapLayer

local effectsLayer=Instance.new("Frame")
effectsLayer.Name="BattleEffects";effectsLayer.Size=UDim2.fromScale(1,1);effectsLayer.BackgroundTransparency=1
effectsLayer.ZIndex=5;effectsLayer.Parent=mapLayer
local labelsLayer=Instance.new("Frame")
labelsLayer.Name="NationLabels";labelsLayer.Size=UDim2.fromScale(1,1);labelsLayer.BackgroundTransparency=1
labelsLayer.ZIndex=6;labelsLayer.Parent=mapLayer

local selection=Instance.new("Frame")
selection.Size=UDim2.fromOffset(16,16);selection.AnchorPoint=Vector2.new(.5,.5);selection.BackgroundTransparency=1
selection.BorderSizePixel=2;selection.BorderColor3=THEME.Text;selection.Visible=false;selection.ZIndex=4;selection.Parent=mapLayer

local function rounded(parent)
    local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,9);c.Parent=parent
end
local function button(parent,text,pos,size,callback)
    local b=Instance.new("TextButton")
    b.Size=size or UDim2.fromOffset(40,36);b.Position=pos;b.BackgroundColor3=THEME.Button;b.BorderSizePixel=0
    b.Text=text;b.TextColor3=THEME.Text;b.Font=Enum.Font.GothamBold;b.TextSize=11;b.ZIndex=30;b.Parent=parent
    rounded(b);b.MouseButton1Click:Connect(callback);return b
end

local mapButton=button(top,"MAP",UDim2.new(1,-122,0,12),UDim2.fromOffset(48,34),function() end)
mapButton.BackgroundColor3=THEME.Gold
local function applyTransform()
    -- Keep each source pixel at native size when zoom=1. The old scale-to-
    -- viewport behavior stretched 1024x512 into the screen and made borders
    -- look like huge blocks.
    mapLayer.Size=UDim2.fromOffset(W*zoom,H*zoom)
    mapLayer.Position=UDim2.new(.5,pan.X,.5,pan.Y)
end

local zoomBox=Instance.new("Frame")
zoomBox.Size=UDim2.fromOffset(48,100);zoomBox.Position=UDim2.new(1,-62,0,76);zoomBox.BackgroundColor3=THEME.Panel
zoomBox.BackgroundTransparency=.05;zoomBox.BorderSizePixel=0;zoomBox.ZIndex=20;zoomBox.Parent=root;rounded(zoomBox)
button(zoomBox,"+",UDim2.fromOffset(5,5),nil,function() zoom=math.min(ZOOM_MAX,zoom+.25);applyTransform() end)
button(zoomBox,"−",UDim2.fromOffset(5,51),nil,function() zoom=math.max(ZOOM_MIN,zoom-.25);applyTransform() end)

local board=Instance.new("Frame")
board.Size=UDim2.fromOffset(225,246);board.Position=UDim2.fromOffset(14,72);board.BackgroundColor3=THEME.Panel
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
dock.Size=UDim2.new(1,-24,0,78);dock.Position=UDim2.new(0,12,1,-90);dock.BackgroundColor3=THEME.Panel
dock.BorderSizePixel=0;dock.ZIndex=20;dock.Parent=root;rounded(dock)
local dockTitle=Instance.new("TextLabel")
dockTitle.Size=UDim2.fromOffset(112,78);dockTitle.Position=UDim2.fromOffset(12,0);dockTitle.BackgroundTransparency=1
dockTitle.Text="ARMY\nCOMMAND";dockTitle.Font=Enum.Font.GothamBlack;dockTitle.TextSize=13;dockTitle.TextColor3=THEME.Text
dockTitle.TextXAlignment=Enum.TextXAlignment.Left;dockTitle.TextYAlignment=Enum.TextYAlignment.Center;dockTitle.ZIndex=21;dockTitle.Parent=dock

local armyLabel=Instance.new("TextLabel")
armyLabel.Size=UDim2.fromOffset(270,20);armyLabel.Position=UDim2.fromOffset(126,5);armyLabel.BackgroundTransparency=1
armyLabel.Text="ARMY  0 / 0";armyLabel.Font=Enum.Font.GothamBold;armyLabel.TextSize=10;armyLabel.TextColor3=THEME.TextMuted
armyLabel.TextXAlignment=Enum.TextXAlignment.Left;armyLabel.ZIndex=21;armyLabel.Parent=dock

local meter=Instance.new("Frame")
meter.Size=UDim2.fromOffset(270,8);meter.Position=UDim2.fromOffset(126,25);meter.BackgroundColor3=THEME.Button
meter.BorderSizePixel=0;meter.ZIndex=21;meter.Parent=dock;rounded(meter)
local meterFill=Instance.new("Frame")
meterFill.Size=UDim2.fromScale(0,1);meterFill.BackgroundColor3=THEME.Success
meterFill.BorderSizePixel=0;meterFill.ZIndex=22;meterFill.Parent=meter;rounded(meterFill)

local amountBox=Instance.new("TextBox")
amountBox.Size=UDim2.fromOffset(92,34);amountBox.Position=UDim2.fromOffset(405,35)
amountBox.BackgroundColor3=THEME.Button;amountBox.BorderSizePixel=0
amountBox.Text="5000";amountBox.PlaceholderText="Troops";amountBox.TextColor3=THEME.Text
amountBox.Font=Enum.Font.GothamBold;amountBox.TextSize=11;amountBox.ClearTextOnFocus=false
amountBox.ZIndex=30;amountBox.Parent=dock;rounded(amountBox)

local amountSlider=Instance.new("TextButton")
amountSlider.Size=UDim2.fromOffset(210,34);amountSlider.Position=UDim2.fromOffset(505,35)
amountSlider.BackgroundColor3=THEME.Button;amountSlider.BorderSizePixel=0
amountSlider.Text="−   5k    10k    25k    50k   +";amountSlider.TextColor3=THEME.TextMuted
amountSlider.Font=Enum.Font.GothamBold;amountSlider.TextSize=10;amountSlider.ZIndex=30;amountSlider.Parent=dock;rounded(amountSlider)

local sendLabel=Instance.new("TextLabel")
sendLabel.Size=UDim2.fromOffset(260,24);sendLabel.Position=UDim2.fromOffset(126,7);sendLabel.BackgroundTransparency=1
sendLabel.Text="SEND ARMY";sendLabel.Font=Enum.Font.GothamBold;sendLabel.TextSize=10;sendLabel.TextColor3=THEME.TextMuted
sendLabel.TextXAlignment=Enum.TextXAlignment.Left;sendLabel.ZIndex=21;sendLabel.Parent=dock

local sendButton=button(dock,"SEND",UDim2.new(1,-84,0,60),UDim2.fromOffset(72,34),function()
    if selectedTile and myId then Attack:FireServer(selectedTile,sendTroops) end
end)
sendButton.BackgroundColor3=THEME.Success

local selectedLabel=Instance.new("TextLabel")
selectedLabel.Size=UDim2.new(0,160,0,52);selectedLabel.Position=UDim2.new(1,-640,0,12);selectedLabel.BackgroundTransparency=1
selectedLabel.Text="Select a pixel";selectedLabel.TextWrapped=true;selectedLabel.Font=Enum.Font.GothamBold;selectedLabel.TextSize=11
selectedLabel.TextColor3=THEME.TextMuted;selectedLabel.TextXAlignment=Enum.TextXAlignment.Left;selectedLabel.ZIndex=21;selectedLabel.Parent=dock

local function buildButton(text,x,kind)
    return button(dock,text,UDim2.new(1,x,0,22),nil,function()
        if selectedTile then Build:FireServer(selectedTile,kind) end
    end)
end
buildButton("CITY",-370,"City").Size=UDim2.fromOffset(62,34)
buildButton("FACTORY",-302,"Factory").Size=UDim2.fromOffset(72,34)
buildButton("PORT",-224,"Port").Size=UDim2.fromOffset(58,34)
buildButton("DEFENSE",-160,"DefensePost").Size=UDim2.fromOffset(70,34)
buildButton("SAM",-438,"SAM").Size=UDim2.fromOffset(52,34)
buildButton("SILO",-496,"MissileSilo").Size=UDim2.fromOffset(56,34)
buildButton("SHIP",-558,"Warship").Size=UDim2.fromOffset(58,34)
local nukeButton=button(dock,"ATOM",UDim2.new(1,-84,0,22),UDim2.fromOffset(72,34),function()
    if selectedTile and myId then Nuke:FireServer(selectedTile,selectedWeapon) end
end)
nukeButton.BackgroundColor3=THEME.Brown
local hydroButton=button(dock,"HYDRO",UDim2.new(1,-162,0,22),UDim2.fromOffset(72,34),function()
    selectedWeapon="Hydrogen";nukeButton.Text="HYDRO"
end)
hydroButton.BackgroundColor3=THEME.Brown
local mirvButton=button(dock,"MIRV",UDim2.new(1,-240,0,22),UDim2.fromOffset(72,34),function()
    selectedWeapon="MIRV";nukeButton.Text="MIRV"
end)
mirvButton.BackgroundColor3=THEME.Brown

local mapPanel=Instance.new("Frame")
mapPanel.Size=UDim2.fromOffset(260,210)
mapPanel.Position=UDim2.new(1,-278,0,72)
mapPanel.BackgroundColor3=THEME.Panel
mapPanel.BorderSizePixel=0
mapPanel.ZIndex=60
mapPanel.Visible=false
mapPanel.Parent=root
rounded(mapPanel)

local mapPanelTitle=Instance.new("TextLabel")
mapPanelTitle.Size=UDim2.new(1,-20,0,34)
mapPanelTitle.Position=UDim2.fromOffset(10,4)
mapPanelTitle.BackgroundTransparency=1
mapPanelTitle.Text="SELECT MAP"
mapPanelTitle.Font=Enum.Font.GothamBlack
mapPanelTitle.TextSize=13
mapPanelTitle.TextColor3=THEME.Text
mapPanelTitle.TextXAlignment=Enum.TextXAlignment.Left
mapPanelTitle.ZIndex=61
mapPanelTitle.Parent=mapPanel

local mapChoices={
    {"World","WORLD"},
    {"Europe","EUROPE"},
    {"Asia","ASIA"},
    {"MENA","MIDDLE EAST"},
}
for index,choice in ipairs(mapChoices) do
    local b=button(mapPanel,choice[2],UDim2.fromOffset(10,38+(index-1)*39),UDim2.new(1,-20,0,32),function()
        SelectMap:FireServer(choice[1])
        mapPanel.Visible=false
    end)
    b.ZIndex=61
end
mapButton.Activated:Connect(function()
    mapPanel.Visible=not mapPanel.Visible
end)

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(0,380,0,38);notice.Position=UDim2.new(.5,-190,0,66);notice.BackgroundColor3=THEME.Panel
notice.BackgroundTransparency=.08;notice.BorderSizePixel=0;notice.Text="";notice.TextWrapped=true;notice.Font=Enum.Font.GothamBold;notice.TextSize=11
notice.TextColor3=THEME.Success;notice.ZIndex=50;notice.Parent=root;rounded(notice)

local function ownerColor(index)
    if index==0 then return THEME.TextMuted end
    if colorCache[index] then return colorCache[index] end
    local id=snapshot and snapshot.ownerIds and snapshot.ownerIds[index]
    local p=id and snapshot.players and snapshot.players[id]
    local c=p and p.color
    local out=c and Color3.new(c[1] or c.r or .3,c[2] or c.g or .5,c[3] or c.b or .7) or THEME.TextMuted
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
    if not land then c=THEME.Water
    elseif owner==0 then c=THEME.NeutralLand
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
        if not land then c=THEME.Water
        elseif owner==0 then c=THEME.NeutralLand
        else
            local base=ownerColor(owner);local k=terrainTint[terrain] or 1
            c=Color3.new(math.clamp(base.R*k,0,1),math.clamp(base.G*k,0,1),math.clamp(base.B*k,0,1))
        end
        local p=i*4
        buffer.writeu8(out,p,math.floor(c.R*255));buffer.writeu8(out,p+1,math.floor(c.G*255));buffer.writeu8(out,p+2,math.floor(c.B*255));buffer.writeu8(out,p+3,255)
    end
    image:WritePixelsBuffer(Vector2.new(packet.x-1,packet.y-1),Vector2.new(packet.w,packet.h),out)
end

local function clearChildren(frame)
    for _,child in ipairs(frame:GetChildren()) do child:Destroy() end
end

local function renderBattleOverlay()
    clearChildren(effectsLayer)
    clearChildren(labelsLayer)
    if not snapshot then return end

    for _,attack in ipairs(snapshot.attacks or {}) do
        local sx=(attack.sourceX or 1)-.5
        local sy=(attack.sourceY or 1)-.5
        local tx=(attack.targetX or 1)-.5
        local ty=(attack.targetY or 1)-.5
        local dx=(tx-sx)/W
        local dy=(ty-sy)/H
        local length=math.sqrt(dx*dx+dy*dy)
        if length>.0001 then
            local line=Instance.new("Frame")
            line.AnchorPoint=Vector2.new(0,.5)
            line.Position=UDim2.new((sx+.5)/W,0,(sy+.5)/H,0)
            line.Size=UDim2.new(length,0,0,3)
            line.BackgroundColor3=attack.naval and THEME.Brown or THEME.Gold
            line.BorderSizePixel=0
            line.Rotation=math.deg(math.atan2(dy,dx))
            line.ZIndex=5
            line.Parent=effectsLayer
            local tip=Instance.new("TextLabel")
            tip.Size=UDim2.fromOffset(20,20)
            tip.AnchorPoint=Vector2.new(.5,.5)
            tip.Position=UDim2.new((tx+.5)/W,0,(ty+.5)/H,0)
            tip.BackgroundTransparency=1
            tip.Text=attack.naval and "⚓" or "➤"
            tip.TextColor3=line.BackgroundColor3
            tip.Font=Enum.Font.GothamBlack
            tip.TextSize=14
            tip.ZIndex=6
            tip.Parent=effectsLayer
        end
    end

    local entries={}
    for id,p in pairs(snapshot.players or {}) do
        if p.alive and p.owned>0 then entries[#entries+1]={id=id,p=p} end
    end
    table.sort(entries,function(a,b) return (a.p.owned or 0)>(b.p.owned or 0) end)
    for i=1,math.min(12,#entries) do
        local item=entries[i]
        local p=item.p
        if p.labelX and p.labelY then
            local label=Instance.new("TextLabel")
            label.Size=UDim2.fromOffset(130,22)
            label.AnchorPoint=Vector2.new(.5,.5)
            label.Position=UDim2.new(p.labelX/W,0,p.labelY/H,0)
            label.BackgroundColor3=THEME.Background
            label.BackgroundTransparency=.28
            label.BorderSizePixel=0
            label.Text=tostring(p.name).."  "..tostring(math.floor(p.owned or 0))
            label.TextColor3=ownerColor(snapshot.ownerIndexById and snapshot.ownerIndexById[item.id] or 0)
            label.Font=Enum.Font.GothamBold
            label.TextSize=9
            label.ZIndex=6
            label.Parent=labelsLayer
            rounded(label)
        end
    end
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
    local ownerIdForTile=snapshot.ownerIds[owner]
    if not myId and owner==0 then Spawn:FireServer(id)
    elseif myId and ownerIdForTile~=myId then
        -- Target selected. Press SEND to commit the chosen army.
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
        myTroops=tonumber(me.troops) or 0
        myMaxTroops=math.max(1,tonumber(me.maxTroops) or myTroops)
        regenPerSecond=tonumber(me.regenPerSecond) or 0
        regenToFullSeconds=tonumber(me.regenToFullSeconds) or 0
        sendTroops=math.floor(math.clamp(tonumber(sendTroops) or 5000,100,math.max(100,myTroops)))
        if not amountBox:IsFocused() then amountBox.Text=tostring(sendTroops) end
        armyLabel.Text="ARMY  "..math.floor(myTroops).." / "..math.floor(myMaxTroops).."   +"..math.floor(regenPerSecond).."/s   FULL "..tostring(regenToFullSeconds).."s"
        meterFill.Size=UDim2.fromScale(math.clamp(myTroops/myMaxTroops,0,1),1)
        topStats.Text="⚔ "..math.floor(me.troops).."    🪙 "..math.floor(me.gold).."    ▣ "..me.owned.." / "..data.totalLand.."    • "..tostring(me.name)
    else
        topStats.Text="DEPLOY • "..tostring(data.mapTitle or data.mapKey or "WORLD").." • "..tostring(data.width).." × "..tostring(data.height).." PIXELS"
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
        row.TextColor3=p.userId==player.UserId and THEME.Success or THEME.TextMuted
        row.TextXAlignment=Enum.TextXAlignment.Left;row.ZIndex=22;row.Parent=boardList
    end
    boardList.CanvasSize=UDim2.fromOffset(0,math.max(0,#data.players*25))
    renderBattleOverlay()
    mapButton.Text=tostring(data.mapTitle or data.mapKey or "MAP")
    if data.winner then
        local win=data.players[data.winner]
        notice.Text="🏆 "..tostring(win and win.name or data.winner).." controls "..tostring(math.floor((data.victoryShare or .8)*100)).."% of the map."
        notice.TextColor3=THEME.Gold
    end
end)

Chunk.OnClientEvent:Connect(paintChunk)
Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    notice.TextColor3=data.kind=="error" and THEME.Error or THEME.Success
end)

amountBox.FocusLost:Connect(function()
    local value=tonumber(amountBox.Text)
    if value then
        sendTroops=math.floor(math.clamp(value,100,math.max(100,myTroops)))
        amountBox.Text=tostring(sendTroops)
    else amountBox.Text=tostring(sendTroops) end
end)
EnterWorld.OnClientEvent:Connect(function(data)
    gui.Enabled=true
    mapButton.Text=tostring(data and (data.mapTitle or data.mapKey) or "MAP")
    Request:FireServer()
end)

amountSlider.MouseButton1Click:Connect(function()
    local steps={1000,5000,10000,25000,50000,100000}
    local next=steps[#steps]
    for _,v in ipairs(steps) do if v>sendTroops then next=v;break end end
    sendTroops=math.min(next,math.max(100,myTroops));amountBox.Text=tostring(sendTroops)
end)

applyTransform()
Request:FireServer()
