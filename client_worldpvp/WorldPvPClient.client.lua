-- World PvP client
-- Independent OpenFront/RoWorld-inspired strategy interface:
-- fullscreen pixel world, zoom/pan, bottom command dock, leaderboard and map controls.

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
local Notice=remotes:WaitForChild("Notice")

local W,H=Rules.MapWidth,Rules.MapHeight
local ZOOM_MIN,ZOOM_MAX=0.65,4.5
local zoom=1
local pan=Vector2.zero
local dragging=false
local dragStart=Vector2.zero
local panStart=Vector2.zero
local snapshot=nil
local myId=nil
local selectedTile=nil
local ratio=.20
local colorCache={}
local renderQueued=false

local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=100
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1)
root.BackgroundColor3=Color3.fromRGB(7,12,18)
root.BorderSizePixel=0
root.Parent=gui

-- Top HUD
local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,58)
top.BackgroundColor3=Color3.fromRGB(12,18,27)
top.BorderSizePixel=0
top.ZIndex=10
top.Parent=root

local brand=Instance.new("TextLabel")
brand.Size=UDim2.fromOffset(190,58)
brand.Position=UDim2.fromOffset(18,0)
brand.BackgroundTransparency=1
brand.Text="WORLD PvP"
brand.Font=Enum.Font.GothamBlack
brand.TextSize=22
brand.TextColor3=Color3.fromRGB(239,244,250)
brand.TextXAlignment=Enum.TextXAlignment.Left
brand.Parent=top

local topStats=Instance.new("TextLabel")
topStats.Size=UDim2.new(1,-420,1,0)
topStats.Position=UDim2.fromOffset(220,0)
topStats.BackgroundTransparency=1
topStats.Text="Waiting for deployment..."
topStats.Font=Enum.Font.GothamBold
topStats.TextSize=13
topStats.TextColor3=Color3.fromRGB(176,190,207)
topStats.TextXAlignment=Enum.TextXAlignment.Left
topStats.Parent=top

local topPlayers=Instance.new("TextLabel")
topPlayers.Size=UDim2.fromOffset(180,58)
topPlayers.Position=UDim2.new(1,-198,0,0)
topPlayers.BackgroundTransparency=1
topPlayers.Text="55 MAX PLAYERS"
topPlayers.Font=Enum.Font.GothamBold
topPlayers.TextSize=11
topPlayers.TextColor3=Color3.fromRGB(134,151,170)
topPlayers.TextXAlignment=Enum.TextXAlignment.Right
topPlayers.Parent=top

-- Map viewport
local viewport=Instance.new("Frame")
viewport.Name="WorldViewport"
viewport.Size=UDim2.new(1,0,1,-142)
viewport.Position=UDim2.fromOffset(0,58)
viewport.BackgroundColor3=Color3.fromRGB(8,31,49)
viewport.BorderSizePixel=0
viewport.ClipsDescendants=true
viewport.Parent=root

local mapLayer=Instance.new("Frame")
mapLayer.BackgroundTransparency=1
mapLayer.AnchorPoint=Vector2.new(.5,.5)
mapLayer.Position=UDim2.fromScale(.5,.5)
mapLayer.Size=UDim2.fromScale(1,1)
mapLayer.Parent=viewport

local image=AssetService:CreateEditableImage({Size=Vector2.new(W,H)})
assert(image,"EditableImage unavailable. Enable Image APIs for this experience.")

local mapImage=Instance.new("ImageLabel")
mapImage.Name="PixelWorld"
mapImage.AnchorPoint=Vector2.new(.5,.5)
mapImage.Position=UDim2.fromScale(.5,.5)
mapImage.Size=UDim2.fromScale(1,1)
mapImage.BackgroundTransparency=1
mapImage.ResampleMode=Enum.ResamplerMode.Pixelated
mapImage.ImageContent=Content.fromObject(image)
mapImage.Parent=mapLayer

local click=Instance.new("ImageButton")
click.Size=UDim2.fromScale(1,1)
click.BackgroundTransparency=1
click.ImageTransparency=1
click.AutoButtonColor=false
click.ZIndex=3
click.Parent=mapLayer

local selection=Instance.new("Frame")
selection.Size=UDim2.fromOffset(18,18)
selection.AnchorPoint=Vector2.new(.5,.5)
selection.BackgroundTransparency=1
selection.BorderSizePixel=2
selection.BorderColor3=Color3.fromRGB(255,255,255)
selection.Visible=false
selection.ZIndex=4
selection.Parent=mapLayer

-- Zoom controls
local zoomBox=Instance.new("Frame")
zoomBox.Size=UDim2.fromOffset(48,100)
zoomBox.Position=UDim2.new(1,-62,0,76)
zoomBox.BackgroundColor3=Color3.fromRGB(14,22,32)
zoomBox.BackgroundTransparency=.05
zoomBox.BorderSizePixel=0
zoomBox.ZIndex=10
zoomBox.Parent=root
Instance.new("UICorner",zoomBox).CornerRadius=UDim.new(0,9)

local function button(parent,text,pos,size,callback)
    local b=Instance.new("TextButton")
    b.Size=size or UDim2.fromOffset(38,38)
    b.Position=pos
    b.BackgroundColor3=Color3.fromRGB(27,39,54)
    b.BorderSizePixel=0
    b.Text=text
    b.TextColor3=Color3.fromRGB(235,241,248)
    b.Font=Enum.Font.GothamBold
    b.TextSize=16
    b.ZIndex=11
    b.Parent=parent
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    b.MouseButton1Click:Connect(callback)
    return b
end

button(zoomBox,"+",UDim2.fromOffset(5,5),nil,function() zoom=math.min(ZOOM_MAX,zoom+.25) end)
button(zoomBox,"−",UDim2.fromOffset(5,51),nil,function() zoom=math.max(ZOOM_MIN,zoom-.25) end)

-- Bottom command dock
local dock=Instance.new("Frame")
dock.Name="CommandDock"
dock.Size=UDim2.new(1,-24,0,76)
dock.Position=UDim2.new(0,12,1,-88)
dock.BackgroundColor3=Color3.fromRGB(12,19,28)
dock.BackgroundTransparency=.02
dock.BorderSizePixel=0
dock.ZIndex=20
dock.Parent=root
Instance.new("UICorner",dock).CornerRadius=UDim.new(0,12)

local dockTitle=Instance.new("TextLabel")
dockTitle.Size=UDim2.fromOffset(115,76)
dockTitle.Position=UDim2.fromOffset(12,0)
dockTitle.BackgroundTransparency=1
dockTitle.Text="ARMY\nCOMMAND"
dockTitle.Font=Enum.Font.GothamBlack
dockTitle.TextSize=13
dockTitle.TextColor3=Color3.fromRGB(230,237,246)
dockTitle.TextXAlignment=Enum.TextXAlignment.Left
dockTitle.TextYAlignment=Enum.TextYAlignment.Center
dockTitle.ZIndex=21
dockTitle.Parent=dock

local ratioLabel=Instance.new("TextLabel")
ratioLabel.Size=UDim2.fromOffset(76,24)
ratioLabel.Position=UDim2.fromOffset(130,7)
ratioLabel.BackgroundTransparency=1
ratioLabel.Text="SEND ARMY"
ratioLabel.Font=Enum.Font.GothamBold
ratioLabel.TextSize=10
ratioLabel.TextColor3=Color3.fromRGB(128,148,169)
ratioLabel.ZIndex=21
ratioLabel.Parent=dock

local ratioButtons={}
for i,v in ipairs({.05,.10,.20,.35,.50,1}) do
    local b=button(dock,tostring(math.floor(v*100)).."%",UDim2.fromOffset(128+(i-1)*48,31),UDim2.fromOffset(44,34),function()
        ratio=v
        for _,x in ipairs(ratioButtons) do x.BackgroundColor3=Color3.fromRGB(27,39,54) end
        b.BackgroundColor3=Color3.fromRGB(45,108,166)
    end)
    ratioButtons[#ratioButtons+1]=b
    if v==ratio then b.BackgroundColor3=Color3.fromRGB(45,108,166) end
end

local selectedLabel=Instance.new("TextLabel")
selectedLabel.Size=UDim2.new(0,280,0,52)
selectedLabel.Position=UDim2.new(1,-670,0,12)
selectedLabel.BackgroundTransparency=1
selectedLabel.Text="No target selected"
selectedLabel.TextWrapped=true
selectedLabel.Font=Enum.Font.GothamBold
selectedLabel.TextSize=11
selectedLabel.TextColor3=Color3.fromRGB(178,193,211)
selectedLabel.TextXAlignment=Enum.TextXAlignment.Left
selectedLabel.ZIndex=21
selectedLabel.Parent=dock

button(dock,"CITY",UDim2.new(1,-370,0,21),UDim2.fromOffset(62,34),function()
    if selectedTile then Build:FireServer(selectedTile,"City") end
end)
button(dock,"FACTORY",UDim2.new(1,-302,0,21),UDim2.fromOffset(72,34),function()
    if selectedTile then Build:FireServer(selectedTile,"Factory") end
end)
button(dock,"PORT",UDim2.new(1,-224,0,21),UDim2.fromOffset(58,34),function()
    if selectedTile then Build:FireServer(selectedTile,"Port") end
end)
button(dock,"DEFENSE",UDim2.new(1,-160,0,21),UDim2.fromOffset(70,34),function()
    if selectedTile then Build:FireServer(selectedTile,"DefensePost") end
end)
button(dock,"NUKE",UDim2.new(1,-84,0,21),UDim2.fromOffset(72,34),function()
    if selectedTile then Nuke:FireServer(selectedTile) end
end)

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(0,360,0,38)
notice.Position=UDim2.new(.5,-180,0,66)
notice.BackgroundColor3=Color3.fromRGB(12,19,28)
notice.BackgroundTransparency=.08
notice.BorderSizePixel=0
notice.Text=""
notice.TextWrapped=true
notice.Font=Enum.Font.GothamBold
notice.TextSize=11
notice.TextColor3=Color3.fromRGB(173,231,190)
notice.ZIndex=15
notice.Parent=root
Instance.new("UICorner",notice).CornerRadius=UDim.new(0,8)

-- Leaderboard
local board=Instance.new("Frame")
board.Size=UDim2.fromOffset(220,240)
board.Position=UDim2.fromOffset(14,72)
board.BackgroundColor3=Color3.fromRGB(11,18,27)
board.BackgroundTransparency=.06
board.BorderSizePixel=0
board.ZIndex=10
board.Parent=root
Instance.new("UICorner",board).CornerRadius=UDim.new(0,10)

local boardTitle=Instance.new("TextLabel")
boardTitle.Size=UDim2.new(1,-18,0,32)
boardTitle.Position=UDim2.fromOffset(9,4)
boardTitle.BackgroundTransparency=1
boardTitle.Text="WORLD RANKING"
boardTitle.Font=Enum.Font.GothamBlack
boardTitle.TextSize=12
boardTitle.TextColor3=Color3.fromRGB(224,233,243)
boardTitle.TextXAlignment=Enum.TextXAlignment.Left
boardTitle.ZIndex=11
boardTitle.Parent=board

local boardList=Instance.new("Frame")
boardList.Size=UDim2.new(1,-18,1,-42)
boardList.Position=UDim2.fromOffset(9,38)
boardList.BackgroundTransparency=1
boardList.ZIndex=11
boardList.Parent=board
local layout=Instance.new("UIListLayout")
layout.Padding=UDim.new(0,3)
layout.Parent=boardList

local function ownerColor(ownerId)
    if not ownerId or ownerId==0 then return Color3.fromRGB(90,100,110) end
    if colorCache[ownerId] then return colorCache[ownerId] end
    local p=snapshot and snapshot.players and snapshot.players[ownerId]
    local c=p and p.color
    local cc=c and Color3.new(c[1] or c.r or .3,c[2] or c.g or .5,c[3] or c.b or .7) or Color3.fromRGB(130,145,160)
    colorCache[ownerId]=cc
    return cc
end

local function render()
    if not snapshot then return end
    local b=buffer.create(W*H*4)
    for id,t in ipairs(snapshot.tiles) do
        local p=(id-1)*4
        local owner=t[1]
        local land=t[3]==1
        local c
        if not land then c=Color3.fromRGB(7,32,53)
        elseif owner==0 then c=Color3.fromRGB(83,91,99)
        else c=ownerColor(owner) end
        buffer.writeu8(b,p,math.floor(c.R*255))
        buffer.writeu8(b,p+1,math.floor(c.G*255))
        buffer.writeu8(b,p+2,math.floor(c.B*255))
        buffer.writeu8(b,p+3,255)
    end
    image:WritePixelsBuffer(Vector2.zero,Vector2.new(W,H),b)
end

local function applyMapTransform()
    mapLayer.Size=UDim2.fromScale(zoom,zoom)
    mapLayer.Position=UDim2.new(.5,pan.X,.5,pan.Y)
end

local function tileAt(pos)
    local abs=click.AbsolutePosition
    local size=click.AbsoluteSize
    local localX=(pos.X-abs.X)/math.max(1,size.X)
    local localY=(pos.Y-abs.Y)/math.max(1,size.Y)
    local x=math.clamp(math.floor(localX*W)+1,1,W)
    local y=math.clamp(math.floor(localY*H)+1,1,H)
    return (y-1)*W+x,x,y
end

local function updateSelection(tileId)
    if not snapshot then return end
    local t=snapshot.tiles[tileId]
    if not t then return end
    selectedTile=tileId
    local owner=t[1]
    local p=owner~=0 and snapshot.players[owner] or nil
    local name=p and p.name or "Neutral Land"
    selectedLabel.Text=name.."  •  "..tostring(t[2]).."  •  Tile "..tostring(tileId)
    selection.Visible=true
    local x=(t[1] and ((tileId-1)%W)/W or .5)
    local y=math.floor((tileId-1)/W)/H
    selection.Position=UDim2.new(x,0,y,0)
end

click.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then
        dragging=true
        dragStart=input.Position
        panStart=pan
        return
    end
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if not snapshot then return end
    local tileId=tileAt(input.Position)
    updateSelection(tileId)
    local t=snapshot.tiles[tileId]
    if not myId then
        if t and t[3]==1 and t[1]==0 then Spawn:FireServer(tileId)
        else notice.Text="Select free land to deploy.";notice.TextColor3=Color3.fromRGB(255,135,135) end
    elseif t and t[3]==1 and t[1]~=myId then
        Attack:FireServer(tileId,ratio)
    end
end)

click.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement and dragging then
        local d=input.Position-dragStart
        pan=panStart+d
        applyMapTransform()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=false end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseWheel then
        local oldZoom=zoom
        zoom=math.clamp(zoom+input.Position.Z*.18,ZOOM_MIN,ZOOM_MAX)
        if oldZoom~=zoom then applyMapTransform() end
    end
end)

Snapshot.OnClientEvent:Connect(function(data)
    snapshot=data
    myId=nil
    colorCache={}
    for id,p in pairs(data.players) do
        if p.userId==player.UserId then myId=id break end
    end
    if myId and data.players[myId] then
        local me=data.players[myId]
        topStats.Text="⚔ "..math.floor(me.troops).."    🪙 "..math.floor(me.gold).."    ▣ "..me.owned.." / "..data.totalLand.."    • "..me.name
    else
        topStats.Text="Choose free land to deploy • "..data.width.." × "..data.height.." pixel world"
    end
    boardList:ClearAllChildren()
    local entries={}
    for id,p in pairs(data.players) do
        entries[#entries+1]=p
    end
    table.sort(entries,function(a,b) return (a.owned or 0)>(b.owned or 0) end)
    for i=1,math.min(8,#entries) do
        local p=entries[i]
        local row=Instance.new("TextLabel")
        row.Size=UDim2.new(1,0,0,22)
        row.BackgroundTransparency=1
        row.Text=string.format("%d  %s    %d",i,tostring(p.name),tonumber(p.owned) or 0)
        row.Font=Enum.Font.GothamBold
        row.TextSize=10
        row.TextColor3=(p.userId==player.UserId and Color3.fromRGB(112,207,255) or Color3.fromRGB(190,201,214))
        row.TextXAlignment=Enum.TextXAlignment.Left
        row.ZIndex=12
        row.Parent=boardList
    end
    render()
    if data.winner then
        notice.Text="🏆 "..tostring(data.players[data.winner] and data.players[data.winner].name or data.winner).." controls 80% of the world."
        notice.TextColor3=Color3.fromRGB(255,215,110)
    end
end)

Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    notice.TextColor3=(data.kind=="error" and Color3.fromRGB(255,135,135)) or Color3.fromRGB(173,231,190)
end)

applyMapTransform()
Request:FireServer()
