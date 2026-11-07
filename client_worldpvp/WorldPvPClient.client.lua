-- client_worldpvp/WorldPvPClient.client.lua
-- Pixel World PvP client: direct map spawn + click-to-send troop attacks.
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
local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=100
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1)
root.BackgroundColor3=Color3.fromRGB(8,12,18)
root.BorderSizePixel=0
root.Parent=gui

local mapFrame=Instance.new("Frame")
mapFrame.Size=UDim2.new(1,-300,1,-72)
mapFrame.Position=UDim2.fromOffset(8,8)
mapFrame.BackgroundColor3=Color3.fromRGB(10,31,50)
mapFrame.BorderSizePixel=0
mapFrame.ClipsDescendants=true
mapFrame.Parent=root

local image=AssetService:CreateEditableImage({Size=Vector2.new(W,H)})
assert(image,"EditableImage could not be created. Enable Allow Mesh / Image APIs in Experience Settings > Security.")
local mapImage=Instance.new("ImageLabel")
mapImage.Name="PixelWorld"
mapImage.Size=UDim2.fromScale(1,1)
mapImage.BackgroundTransparency=1
mapImage.ResampleMode=Enum.ResamplerMode.Pixelated
mapImage.ImageContent=Content.fromObject(image)
mapImage.Parent=mapFrame

local click=Instance.new("ImageButton")
click.Size=UDim2.fromScale(1,1)
click.BackgroundTransparency=1
click.ImageTransparency=1
click.AutoButtonColor=false
click.Parent=mapFrame

local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,276,1,-16)
panel.Position=UDim2.new(1,-284,0,8)
panel.BackgroundColor3=Color3.fromRGB(13,20,30)
panel.BorderSizePixel=0
panel.Parent=root
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,12)

local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-24,0,44)
title.Position=UDim2.fromOffset(12,10)
title.BackgroundTransparency=1
title.Text="WORLD PvP"
title.Font=Enum.Font.GothamBlack
title.TextSize=22
title.TextColor3=Color3.fromRGB(240,245,252)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Parent=panel

local status=Instance.new("TextLabel")
status.Size=UDim2.new(1,-24,0,62)
status.Position=UDim2.fromOffset(12,58)
status.BackgroundTransparency=1
status.Text="اختر نقطة على الخريطة"
status.TextWrapped=true
status.Font=Enum.Font.GothamBold
status.TextSize=13
status.TextColor3=Color3.fromRGB(180,195,214)
status.TextXAlignment=Enum.TextXAlignment.Left
status.TextYAlignment=Enum.TextYAlignment.Top
status.Parent=panel

local stats=Instance.new("TextLabel")
stats.Size=UDim2.new(1,-24,0,108)
stats.Position=UDim2.fromOffset(12,128)
stats.BackgroundColor3=Color3.fromRGB(20,30,43)
stats.BorderSizePixel=0
stats.Text="لم يتم اختيار دولة"
stats.TextWrapped=true
stats.Font=Enum.Font.GothamBold
stats.TextSize=13
stats.TextColor3=Color3.fromRGB(225,233,244)
stats.TextXAlignment=Enum.TextXAlignment.Left
stats.TextYAlignment=Enum.TextYAlignment.Top
stats.Parent=panel
Instance.new("UICorner",stats).CornerRadius=UDim.new(0,8)

local ratioTitle=Instance.new("TextLabel")
ratioTitle.Size=UDim2.new(1,-24,0,30)
ratioTitle.Position=UDim2.fromOffset(12,248)
ratioTitle.BackgroundTransparency=1
ratioTitle.Text="Attack Ratio"
ratioTitle.Font=Enum.Font.GothamBlack
ratioTitle.TextSize=14
ratioTitle.TextColor3=Color3.fromRGB(230,237,246)
ratioTitle.TextXAlignment=Enum.TextXAlignment.Left
ratioTitle.Parent=panel

local ratio=.20
local ratioButtons={}
local vals={.05,.10,.20,.35,.50,1}
for i,v in ipairs(vals) do
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(0,37,0,34)
    b.Position=UDim2.fromOffset(12+(i-1)*42,278)
    b.BackgroundColor3=(v==ratio and Color3.fromRGB(43,112,170) or Color3.fromRGB(27,39,53))
    b.BorderSizePixel=0
    b.Text=tostring(math.floor(v*100)).."%"
    b.TextColor3=Color3.fromRGB(235,240,247)
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    b.MouseButton1Click:Connect(function()
        ratio=v
        for _,x in ipairs(ratioButtons) do x.BackgroundColor3=Color3.fromRGB(27,39,53) end
        b.BackgroundColor3=Color3.fromRGB(43,112,170)
    end)
    ratioButtons[#ratioButtons+1]=b
end

local selected=Instance.new("TextLabel")
selected.Size=UDim2.new(1,-24,0,86)
selected.Position=UDim2.fromOffset(12,326)
selected.BackgroundColor3=Color3.fromRGB(18,28,41)
selected.BorderSizePixel=0
selected.Text="انقر على أرض حرة للـSpawn.
بعد الـSpawn: أي نقرة = إرسال الجيش."
selected.TextWrapped=true
selected.Font=Enum.Font.Gotham
selected.TextSize=12
selected.TextColor3=Color3.fromRGB(175,190,209)
selected.TextXAlignment=Enum.TextXAlignment.Left
selected.TextYAlignment=Enum.TextYAlignment.Top
selected.Parent=panel
Instance.new("UICorner",selected).CornerRadius=UDim.new(0,8)

local function makeAction(text,x,y,w,callback)
    local b=Instance.new("TextButton")
    b.Size=UDim2.fromOffset(w or 116,34)
    b.Position=UDim2.fromOffset(x,y)
    b.BackgroundColor3=Color3.fromRGB(27,39,53)
    b.BorderSizePixel=0
    b.Text=text
    b.TextColor3=Color3.fromRGB(235,240,247)
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.Parent=panel
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,7)
    b.MouseButton1Click:Connect(callback)
    return b
end

local buildTitle=Instance.new("TextLabel")
buildTitle.Size=UDim2.new(1,-24,0,24)
buildTitle.Position=UDim2.fromOffset(12,420)
buildTitle.BackgroundTransparency=1
buildTitle.Text="Build on selected own pixel"
buildTitle.Font=Enum.Font.GothamBlack
buildTitle.TextSize=12
buildTitle.TextColor3=Color3.fromRGB(230,237,246)
buildTitle.TextXAlignment=Enum.TextXAlignment.Left
buildTitle.Parent=panel

makeAction("City",12,448,56,function() if selectedTile then Build:FireServer(selectedTile,"City") end end)
makeAction("Factory",74,448,70,function() if selectedTile then Build:FireServer(selectedTile,"Factory") end end)
makeAction("Port",150,448,50,function() if selectedTile then Build:FireServer(selectedTile,"Port") end end)
makeAction("Defense",206,448,58,function() if selectedTile then Build:FireServer(selectedTile,"DefensePost") end end)
makeAction("☢ Nuke",12,486,74,function() if selectedTile then Nuke:FireServer(selectedTile) end end)

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(1,-24,0,70)
notice.Position=UDim2.new(0,12,1,-62)
notice.BackgroundTransparency=1
notice.Text=""
notice.TextWrapped=true
notice.Font=Enum.Font.GothamBold
notice.TextSize=12
notice.TextColor3=Color3.fromRGB(160,235,180)
notice.TextXAlignment=Enum.TextXAlignment.Left
notice.TextYAlignment=Enum.TextYAlignment.Bottom
notice.Parent=panel

local snapshot=nil
local myId=nil
local selectedTile=nil
local colorCache={}

local function ownerColor(ownerId)
    if not ownerId or ownerId==0 then return nil end
    if colorCache[ownerId] then return colorCache[ownerId] end
    if snapshot and snapshot.players and snapshot.players[ownerId] then
        local c=snapshot.players[ownerId].color
        if c then
            local cc=Color3.new(c[1] or c.r or .3,c[2] or c.g or .5,c[3] or c.b or .7)
            colorCache[ownerId]=cc
            return cc
        end
    end
    return Color3.fromRGB(130,145,160)
end

local function render()
    if not snapshot then return end
    local b=buffer.create(W*H*4)
    for id,t in ipairs(snapshot.tiles) do
        local p=(id-1)*4
        local owner=t[1]
        local land=t[3]==1
        local c
        if not land then
            c=Color3.fromRGB(8,31,51)
        elseif owner==0 then
            c=Color3.fromRGB(91,99,105)
        else
            c=ownerColor(owner)
        end
        buffer.writeu8(b,p,math.floor(c.R*255))
        buffer.writeu8(b,p+1,math.floor(c.G*255))
        buffer.writeu8(b,p+2,math.floor(c.B*255))
        buffer.writeu8(b,p+3,255)
    end
    image:WritePixelsBuffer(Vector2.zero,Vector2.new(W,H),b)
end

local function tileAt(rx,ry)
    local x=math.clamp(math.floor(rx*W)+1,1,W)
    local y=math.clamp(math.floor(ry*H)+1,1,H)
    return (y-1)*W+x,x,y
end

local function updatePanel(tileId)
    if not snapshot or not tileId then return end
    local t=snapshot.tiles[tileId]
    if not t then return end
    selectedTile=tileId
    local owner=t[1]
    local p=owner~=0 and snapshot.players[owner] or nil
    local name=p and p.name or "Neutral Land"
    selected.Text="Target: "..name
        .."\nTile: "..tostring(tileId)
        .."\nTerrain: "..tostring(t[2])
        .."\n\n"..(owner==0 and "أرض محايدة" or ("المالك: "..name))
end

click.InputBegan:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1
        and input.UserInputType~=Enum.UserInputType.Touch then return end
    if not snapshot then return end
    local pos=input.Position
    local abs=click.AbsolutePosition
    local size=click.AbsoluteSize
    local rx=math.clamp((pos.X-abs.X)/math.max(1,size.X),0,1)
    local ry=math.clamp((pos.Y-abs.Y)/math.max(1,size.Y),0,1)
    local tileId=tileAt(rx,ry)
    updatePanel(tileId)

    if not myId then
        local t=snapshot.tiles[tileId]
        if t and t[3]==1 and t[1]==0 then
            Spawn:FireServer(tileId)
        else
            notice.Text="اختار أرض محايدة."
            notice.TextColor3=Color3.fromRGB(255,125,125)
        end
    else
        local t=snapshot.tiles[tileId]
        if t and t[3]==1 and t[1]~=myId then
            Attack:FireServer(tileId,ratio)
        elseif t and t[1]==myId then
            notice.Text="هاي أرضك. انقر خارج حدودك للهجوم."
        end
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
        status.Text="دولتك: "..tostring(me.name)
        stats.Text="⚔ الجيش: "..tostring(me.troops)
            .."\n🪙 الذهب: "..tostring(me.gold)
            .."\n▣ الأراضي: "..tostring(me.owned)
            .."\n⚔ الهجمات: "..tostring(me.attacks or 0)
        selected.Text="انقر أي بكسل عدو لإرسال "..math.floor(ratio*100).."% من جيشك."
    else
        status.Text="اختر نقطة البداية"
        stats.Text="لم يتم Spawn بعد"
    end
    render()
end)

Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    notice.TextColor3=(data.kind=="error" and Color3.fromRGB(255,125,125))
        or Color3.fromRGB(165,235,185)
end)

Request:FireServer()
