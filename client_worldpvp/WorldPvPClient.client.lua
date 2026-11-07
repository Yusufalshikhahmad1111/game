-- client_worldpvp/WorldPvPClient.client.lua
-- Full-screen political map UI. Countries are rendered as real polygon silhouettes,
-- not square tiles. Click the map to select a starting country or attack a neighbor.

local Players=game:GetService("Players")
local AssetService=game:GetService("AssetService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("WorldPvPRemotes")
local SelectCountry=remotes:WaitForChild("SelectCountry")
local AttackCountry=remotes:WaitForChild("AttackCountry")
local Snapshot=remotes:WaitForChild("Snapshot")
local Notice=remotes:WaitForChild("Notice")
local RequestSnapshot=remotes:WaitForChild("RequestSnapshot")
local CountryData=require(ReplicatedStorage.Shared.WorldPvP.CountryMapData)

local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=100
gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1)
root.BackgroundColor3=Color3.fromRGB(8,13,20)
root.BorderSizePixel=0
root.Parent=gui

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,68)
top.BackgroundColor3=Color3.fromRGB(10,17,27)
top.BorderSizePixel=0
top.Parent=root

local title=Instance.new("TextLabel")
title.Size=UDim2.fromOffset(360,68)
title.Position=UDim2.fromOffset(22,0)
title.BackgroundTransparency=1
title.Text="WORLD DOMINION"
title.Font=Enum.Font.GothamBlack
title.TextSize=24
title.TextColor3=Color3.fromRGB(240,245,252)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Parent=top

local stats=Instance.new("TextLabel")
stats.Size=UDim2.new(1,-410,68,0)
stats.Position=UDim2.fromOffset(390,0)
stats.BackgroundTransparency=1
stats.Text="اختر نقطة البداية على الخريطة"
stats.Font=Enum.Font.GothamBold
stats.TextSize=14
stats.TextColor3=Color3.fromRGB(185,198,215)
stats.TextXAlignment=Enum.TextXAlignment.Right
stats.Parent=top

local mapHolder=Instance.new("Frame")
mapHolder.Size=UDim2.new(1,-360,1,-92)
mapHolder.Position=UDim2.fromOffset(16,80)
mapHolder.BackgroundColor3=Color3.fromRGB(10,31,51)
mapHolder.BorderSizePixel=0
mapHolder.ClipsDescendants=true
mapHolder.Parent=root
Instance.new("UICorner",mapHolder).CornerRadius=UDim.new(0,14)

local mapImage=Instance.new("ImageLabel")
mapImage.Size=UDim2.fromScale(1,1)
mapImage.BackgroundTransparency=1
mapImage.ScaleType=Enum.ScaleType.Stretch
mapImage.Parent=mapHolder

local mapButton=Instance.new("ImageButton")
mapButton.Size=UDim2.fromScale(1,1)
mapButton.BackgroundTransparency=1
mapButton.ImageTransparency=1
mapButton.AutoButtonColor=false
mapButton.Parent=mapHolder

local side=Instance.new("Frame")
side.Size=UDim2.new(0,328,1,-92)
side.Position=UDim2.new(1,-344,0,80)
side.BackgroundColor3=Color3.fromRGB(12,20,31)
side.BorderSizePixel=0
side.Parent=root
Instance.new("UICorner",side).CornerRadius=UDim.new(0,14)

local sideTitle=Instance.new("TextLabel")
sideTitle.Size=UDim2.new(1,-28,0,42)
sideTitle.Position=UDim2.fromOffset(14,12)
sideTitle.BackgroundTransparency=1
sideTitle.Text="WORLD MAP"
sideTitle.Font=Enum.Font.GothamBlack
sideTitle.TextSize=19
sideTitle.TextColor3=Color3.fromRGB(240,245,252)
sideTitle.TextXAlignment=Enum.TextXAlignment.Left
sideTitle.Parent=side

local instruction=Instance.new("TextLabel")
instruction.Size=UDim2.new(1,-28,0,94)
instruction.Position=UDim2.fromOffset(14,55)
instruction.BackgroundTransparency=1
instruction.Text="انقر على دولة غير محتلة لتضع عاصمتك. بعد البداية، انقر على دولة مجاورة لبدء الهجوم."
instruction.TextWrapped=true
instruction.Font=Enum.Font.Gotham
instruction.TextSize=13
instruction.TextColor3=Color3.fromRGB(165,181,202)
instruction.TextXAlignment=Enum.TextXAlignment.Left
instruction.TextYAlignment=Enum.TextYAlignment.Top
instruction.Parent=side

local selected=Instance.new("TextLabel")
selected.Size=UDim2.new(1,-28,0,170)
selected.Position=UDim2.fromOffset(14,160)
selected.BackgroundColor3=Color3.fromRGB(18,30,45)
selected.BorderSizePixel=0
selected.Text="لا توجد دولة محددة"
selected.TextWrapped=true
selected.Font=Enum.Font.GothamBold
selected.TextSize=14
selected.TextColor3=Color3.fromRGB(225,233,244)
selected.TextXAlignment=Enum.TextXAlignment.Left
selected.TextYAlignment=Enum.TextYAlignment.Top
selected.Parent=side
Instance.new("UICorner",selected).CornerRadius=UDim.new(0,10)

local action=Instance.new("TextButton")
action.Size=UDim2.new(1,-28,0,46)
action.Position=UDim2.new(0,14,1,-118)
action.BackgroundColor3=Color3.fromRGB(34,83,132)
action.BorderSizePixel=0
action.Text="اختيار / هجوم"
action.TextColor3=Color3.new(1,1,1)
action.Font=Enum.Font.GothamBlack
action.TextSize=14
action.Parent=side
Instance.new("UICorner",action).CornerRadius=UDim.new(0,10)

local power=Instance.new("TextLabel")
power.Size=UDim2.new(1,-28,0,46)
power.Position=UDim2.new(0,14,1,-66)
power.BackgroundTransparency=1
power.Text="القوة: 5,000 • انقر دولة مجاورة"
power.Font=Enum.Font.GothamBold
power.TextSize=12
power.TextColor3=Color3.fromRGB(175,191,211)
power.TextXAlignment=Enum.TextXAlignment.Left
power.Parent=side

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(1,-32,0,38)
notice.Position=UDim2.new(0,16,1,-46)
notice.BackgroundColor3=Color3.fromRGB(13,25,39)
notice.BackgroundTransparency=.05
notice.BorderSizePixel=0
notice.Text=""
notice.Font=Enum.Font.GothamBold
notice.TextSize=12
notice.TextColor3=Color3.fromRGB(170,235,190)
notice.Parent=root
Instance.new("UICorner",notice).CornerRadius=UDim.new(0,9)

local W,H=768,384
local image=AssetService:CreateEditableImage({Size=Vector2.new(W,H)})
mapImage.ImageContent=Content.fromObject(image)

local snapshot=nil
local selectedId=nil
local myNation=nil
local colors={}

local function rgb(c)
    return Color3.new(c.r or .3,c.g or .5,c.b or .7)
end

local function project(lon,lat)
    local x=(lon+180)/360*(W-1)
    local y=(85-lat)/(85+60)*(H-1)
    return x,y
end

local function countryColor(c)
    if c.ownerNationId then
        return rgb(c.color)
    end
    local base=((tonumber(string.byte(c.id:sub(1,1))) or 40)%9)/20
    return Color3.new(.25+base,.29+base,.34+base)
end

local function clearBuffer()
    local b=buffer.create(W*H*4)
    for i=0,W*H-1 do
        local p=i*4
        buffer.writeu8(b,p,12)
        buffer.writeu8(b,p+1,39)
        buffer.writeu8(b,p+2,62)
        buffer.writeu8(b,p+3,255)
    end
    return b
end

local function fillRing(b,ring,color)
    local pts={}
    for _,p in ipairs(ring) do
        local x,y=project(p[1],p[2])
        pts[#pts+1]={x=x,y=y}
    end
    local minY,maxY=H-1,0
    for _,p in ipairs(pts) do
        minY=math.min(minY,math.floor(p.y))
        maxY=math.max(maxY,math.ceil(p.y))
    end
    minY=math.max(0,minY); maxY=math.min(H-1,maxY)
    for py=minY,maxY do
        local scan=py+.5
        local xs={}
        local j=#pts
        for i=1,#pts do
            local a,b=pts[i],pts[j]
            if (a.y>scan) ~= (b.y>scan) then
                local x=a.x+(scan-a.y)*(b.x-a.x)/((b.y-a.y)+1e-9)
                xs[#xs+1]=x
            end
            j=i
        end
        table.sort(xs)
        for i=1,#xs-1,2 do
            local x1=math.max(0,math.ceil(xs[i]))
            local x2=math.min(W-1,math.floor(xs[i+1]))
            for px=x1,x2 do
                local idx=(py*W+px)*4
                buffer.writeu8(b,idx,math.floor(color.R*255))
                buffer.writeu8(b,idx+1,math.floor(color.G*255))
                buffer.writeu8(b,idx+2,math.floor(color.B*255))
                buffer.writeu8(b,idx+3,255)
            end
        end
    end
end

local function drawBorders()
    local border=Color3.fromRGB(25,31,39)
    for _,country in ipairs(CountryData.Countries) do
        for _,ring in ipairs(country.polygons) do
            local previous
            for _,p in ipairs(ring) do
                local x,y=project(p[1],p[2])
                local current=Vector2.new(x,y)
                if previous then
                    image:DrawLine(previous,current,border,0,Enum.ImageCombineType.Overwrite,Enum.AntiAliasing.Enabled)
                end
                previous=current
            end
            if previous and #ring>2 then
                local p=ring[1]
                local current=Vector2.new(project(p[1],p[2]))
                image:DrawLine(previous,current,border,0,Enum.ImageCombineType.Overwrite,Enum.AntiAliasing.Enabled)
            end
        end
    end
end

local function render()
    if not snapshot then return end
    local b=clearBuffer()
    for _,country in ipairs(snapshot.countries) do
        local c=countryColor(country)
        local source=CountryData.get(country.id)
        if source then
            for _,ring in ipairs(source.polygons) do
                fillRing(b,ring,c)
            end
        end
    end
    image:WritePixelsBuffer(Vector2.zero,Vector2.new(W,H),b)
    drawBorders()
end

local function countryAt(x,y)
    local lon=x/(W-1)*360-180
    local lat=85-y/(H-1)*(85+60)
    return CountryData.findAt(lon,lat)
end

local function showCountry(country)
    if not country or not snapshot then return end
    selectedId=country.id
    local live
    for _,c in ipairs(snapshot.countries) do
        if c.id==country.id then live=c break end
    end
    if not live then return end
    local mine=live.ownerUserId==player.UserId
    local label=live.ownerName and ("القائد: "..live.ownerName) or "غير محتلة"
    selected.Text=country.name.."\n"..label.."\n\n⚔ الجيش: "..tostring(math.floor(live.troops))
        .."\n🪙 الذهب: "..tostring(math.floor(live.gold))
        .."\n🌍 القارة: "..country.continent
        .."\n\n"..(mine and "هذه أرضك." or "اضغط زر الإجراء للتوسع إذا كانت مجاورة.")
end

-- GuiButton click events do not provide screen X/Y coordinates.
-- InputBegan supplies an InputObject; use its Position relative to the map button.
mapButton.InputBegan:Connect(function(inputObject)
    local inputType = inputObject.UserInputType
    if inputType ~= Enum.UserInputType.MouseButton1
        and inputType ~= Enum.UserInputType.Touch then
        return
    end

    local screenPosition = inputObject.Position
    local mapPosition = mapButton.AbsolutePosition
    local mapSize = mapButton.AbsoluteSize

    if mapSize.X <= 0 or mapSize.Y <= 0 then
        return
    end

    local relativeX = math.clamp(
        (screenPosition.X - mapPosition.X) / mapSize.X,
        0,
        1
    )
    local relativeY = math.clamp(
        (screenPosition.Y - mapPosition.Y) / mapSize.Y,
        0,
        1
    )

    local country = countryAt(relativeX * (W - 1), relativeY * (H - 1))
    showCountry(country)
end)

action.MouseButton1Click:Connect(function()
    if not selectedId or not snapshot then return end
    local live
    for _,c in ipairs(snapshot.countries) do if c.id==selectedId then live=c break end end
    if not live then return end
    if not myNation then
        if live.ownerNationId then
            notice.Text="هذه الدولة أصبحت محجوزة. اختر أرضاً أخرى."
            notice.TextColor3=Color3.fromRGB(255,130,130)
            return
        end
        SelectCountry:FireServer(selectedId)
    elseif live.ownerNationId~=myNation then
        AttackCountry:FireServer(selectedId,5000)
    else
        notice.Text="هذه أرضك بالفعل."
    end
end)

Snapshot.OnClientEvent:Connect(function(data)
    snapshot=data
    myNation=nil
    for _,c in ipairs(data.countries) do
        if c.ownerUserId==player.UserId then
            myNation=c.ownerNationId
            break
        end
    end
    if myNation then
        local own
        for _,c in ipairs(data.countries) do if c.ownerNationId==myNation then own=c break end end
        stats.Text="دولتك: "..(own and (own.ownerName or own.name) or player.DisplayName)
            .."   |   الجيش "..tostring(math.floor(own and own.troops or 0))
            .."   |   اضغط على دولة مجاورة للهجوم"
        action.Text="⚔ هجوم 5,000"
    else
        stats.Text="اختر نقطة البداية على الخريطة"
        action.Text="اختر هذه الدولة"
    end
    render()
    if selectedId then showCountry(CountryData.get(selectedId)) end
end)

Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    notice.TextColor3=(data.kind=="error" and Color3.fromRGB(255,120,120))
        or (data.kind=="warning" and Color3.fromRGB(255,210,100))
        or Color3.fromRGB(165,235,185)
end)

RequestSnapshot:FireServer()
