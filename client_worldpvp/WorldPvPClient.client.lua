-- client_worldpvp/WorldPvPClient.client.lua
-- Original Roblox-native strategy UI for World PvP.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("WorldPvPRemotes")
local SelectNation=remotes.SelectNation
local Attack=remotes.Attack
local NavalAttack=remotes.NavalAttack
local Build=remotes.Build
local Nuke=remotes.Nuke
local Snapshot=remotes.Snapshot
local Notice=remotes.Notice
local RequestSnapshot=remotes.RequestSnapshot

local gui=Instance.new("ScreenGui")
gui.Name="WorldPvP"; gui.ResetOnSpawn=false; gui.DisplayOrder=50; gui.Parent=player:WaitForChild("PlayerGui")

local root=Instance.new("Frame")
root.Size=UDim2.fromScale(1,1); root.BackgroundColor3=Color3.fromRGB(7,12,20); root.BorderSizePixel=0; root.Parent=gui

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,70); top.BackgroundColor3=Color3.fromRGB(12,20,32); top.BorderSizePixel=0; top.Parent=root

local logo=Instance.new("TextLabel")
logo.Size=UDim2.fromOffset(250,70); logo.Position=UDim2.fromOffset(18,0); logo.BackgroundTransparency=1
logo.Text="WORLD DOMINION"; logo.Font=Enum.Font.GothamBlack; logo.TextSize=21; logo.TextColor3=Color3.fromRGB(239,245,255)
logo.TextXAlignment=Enum.TextXAlignment.Left; logo.Parent=top

local stats=Instance.new("TextLabel")
stats.Size=UDim2.new(1,-290,0,70); stats.Position=UDim2.fromOffset(270,0); stats.BackgroundTransparency=1
stats.Text="اختر دولة للبدء"; stats.Font=Enum.Font.GothamBold; stats.TextSize=14; stats.TextColor3=Color3.fromRGB(180,195,215)
stats.TextXAlignment=Enum.TextXAlignment.Right; stats.Parent=top

local mapFrame=Instance.new("Frame")
mapFrame.Size=UDim2.new(1,-400,1,-92); mapFrame.Position=UDim2.fromOffset(16,82)
mapFrame.BackgroundColor3=Color3.fromRGB(14,25,39); mapFrame.BorderSizePixel=0; mapFrame.Parent=root
Instance.new("UICorner",mapFrame).CornerRadius=UDim.new(0,14)

local grid=Instance.new("Frame")
grid.BackgroundTransparency=1; grid.AnchorPoint=Vector2.new(.5,.5); grid.Position=UDim2.fromScale(.5,.5); grid.Parent=mapFrame
local layout=Instance.new("UIGridLayout"); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.CellPadding=UDim2.fromOffset(1,1); layout.Parent=grid

local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,365,1,-92); panel.Position=UDim2.new(1,-381,0,82)
panel.BackgroundColor3=Color3.fromRGB(12,20,32); panel.BorderSizePixel=0; panel.Parent=root
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,14)

local heading=Instance.new("TextLabel")
heading.Size=UDim2.new(1,-28,0,40); heading.Position=UDim2.fromOffset(14,12); heading.BackgroundTransparency=1
heading.Text="WORLD MAP"; heading.Font=Enum.Font.GothamBlack; heading.TextSize=18; heading.TextColor3=Color3.fromRGB(239,245,255)
heading.TextXAlignment=Enum.TextXAlignment.Left; heading.Parent=panel

local detail=Instance.new("TextLabel")
detail.Size=UDim2.new(1,-28,0,126); detail.Position=UDim2.fromOffset(14,55); detail.BackgroundTransparency=1
detail.Text="اضغط على دولة لاختيارها، ثم اضغط على إقليم مجاور للتوسع."; detail.TextWrapped=true
detail.TextColor3=Color3.fromRGB(165,183,207); detail.Font=Enum.Font.Gotham; detail.TextSize=13
detail.TextXAlignment=Enum.TextXAlignment.Left; detail.TextYAlignment=Enum.TextYAlignment.Top; detail.Parent=panel

local selectedCell=nil
local selectedNation=nil
local snapshot=nil
local buttons={}

local function makeButton(text,y,callback)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-28,0,38); b.Position=UDim2.fromOffset(14,y); b.BackgroundColor3=Color3.fromRGB(30,51,73)
    b.BorderSizePixel=0; b.Text=text; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=13
    b.AutoButtonColor=true; b.Parent=panel; Instance.new("UICorner",b).CornerRadius=UDim.new(0,9); b.MouseButton1Click:Connect(callback)
    return b
end

local selectBtn=makeButton("اختيار الدولة",190,function()
    if selectedNation then SelectNation:FireServer(selectedNation) end
end)
local attackBtn=makeButton("⚔ هجوم بري — 5,000",234,function()
    if selectedCell then Attack:FireServer(selectedCell,5000) end
end)
local navalBtn=makeButton("⚓ إنزال بحري — 5,000",278,function()
    if selectedCell then NavalAttack:FireServer(selectedCell,5000) end
end)
local cityBtn=makeButton("🏙 مدينة — 25K",322,function()
    if selectedCell then Build:FireServer(selectedCell,"City") end
end)
local factoryBtn=makeButton("🏭 مصنع — 80K",366,function()
    if selectedCell then Build:FireServer(selectedCell,"Factory") end
end)
local portBtn=makeButton("⚓ ميناء — 50K",410,function()
    if selectedCell then Build:FireServer(selectedCell,"Port") end
end)
local defenseBtn=makeButton("🛡 دفاع — 35K",454,function()
    if selectedCell then Build:FireServer(selectedCell,"DefensePost") end
end)
local siloBtn=makeButton("🚀 صومعة — 150K",498,function()
    if selectedCell then Build:FireServer(selectedCell,"MissileSilo") end
end)
local samBtn=makeButton("🛰 SAM — 100K",542,function()
    if selectedCell then Build:FireServer(selectedCell,"SAM") end
end)
local nukeBtn=makeButton("☢ ضربة نووية — 250K",586,function()
    if selectedCell then Nuke:FireServer(selectedCell) end
end)

local notice=Instance.new("TextLabel")
notice.Size=UDim2.new(1,-32,0,36); notice.Position=UDim2.new(0,16,1,-48)
notice.BackgroundColor3=Color3.fromRGB(16,29,45); notice.BackgroundTransparency=.1
notice.Text=""; notice.Font=Enum.Font.GothamBold; notice.TextSize=12; notice.TextColor3=Color3.fromRGB(200,220,240)
notice.TextWrapped=true; notice.Parent=root; Instance.new("UICorner",notice).CornerRadius=UDim.new(0,9)

local function nationInfo(id)
    if not snapshot then return end
    for _,n in ipairs(snapshot.nations) do if n.id==id then return n end end
end

local function colorOf(id)
    local n=nationInfo(id)
    if not n then return Color3.fromRGB(75,85,95) end
    local c=n.color
    return Color3.new(c.r,c.g,c.b)
end

local function mine(id)
    local n=nationInfo(id)
    return n and n.ownerUserId==player.UserId
end

local function showDetail(cell)
    selectedCell=cell.id
    if cell.ownerId then
        local n=nationInfo(cell.ownerId)
        selectedNation=cell.ownerId
        detail.Text=string.format(
            "%s\n%s • %s\n🪙 %s   ⚔ %s   🌍 %.1f%%\nالبناء: %s",
            n and n.name or cell.ownerId,
            n and (n.category or "Nation") or "Unknown",
            cell.isCoastal and "ساحلية" or "داخلية",
            n and math.floor(n.gold) or 0,
            n and math.floor(n.troops) or 0,
            n and n.worldShare*100 or 0,
            cell.building and cell.building.kind or "لا يوجد"
        )
    else
        selectedNation=nil
        detail.Text="أرض محايدة\nاختر دولة أولاً ثم وسّع من حدودك."
    end
end

local function rebuildMap()
    if not snapshot then return end
    for _,child in ipairs(grid:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local cellPx=math.clamp(math.floor(690/snapshot.width),8,18)
    grid.Size=UDim2.fromOffset(snapshot.width*cellPx,snapshot.height*cellPx)
    layout.CellSize=UDim2.fromOffset(cellPx,cellPx)

    for index,cell in ipairs(snapshot.cells) do
        local b=Instance.new("TextButton")
        b.LayoutOrder=index; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Text=cell.building and "◆" or ""
        b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=math.max(7,cellPx-6)
        if not cell.isLand then
            b.BackgroundColor3=Color3.fromRGB(18,63,95)
        elseif cell.ownerId then
            b.BackgroundColor3=colorOf(cell.ownerId)
        else
            b.BackgroundColor3=Color3.fromRGB(73,78,82)
        end
        if selectedCell==cell.id then b.BackgroundColor3=Color3.fromRGB(245,205,80) end
        b.Parent=grid
        b.MouseButton1Click:Connect(function() showDetail(cell) end)
    end
end

Snapshot.OnClientEvent:Connect(function(data)
    snapshot=data
    rebuildMap()
    local own
    for _,n in ipairs(data.nations) do if n.ownerUserId==player.UserId then own=n break end end
    if own then
        stats.Text=string.format("%s  |  🪙 %s  |  ⚔ %s  |  🏳 %d  |  🌍 %.1f%%",
            own.name,math.floor(own.gold),math.floor(own.troops),own.land,own.worldShare*100)
        selectBtn.Text="الدولة: "..own.name
    else
        stats.Text="اختر دولة • القبائل AI • الهدف 80% من العالم"
        selectBtn.Text="اختيار الدولة المحددة"
    end
end)

Notice.OnClientEvent:Connect(function(data)
    notice.Text=data.message or ""
    if data.kind=="error" then
        notice.TextColor3=Color3.fromRGB(255,105,105)
    elseif data.kind=="warning" then
        notice.TextColor3=Color3.fromRGB(255,205,90)
    else
        notice.TextColor3=Color3.fromRGB(150,235,175)
    end
end)

RequestSnapshot:FireServer()
