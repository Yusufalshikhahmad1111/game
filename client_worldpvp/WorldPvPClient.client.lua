-- client_worldpvp/WorldPvPClient.client.lua
-- Original Roblox-native World PvP UI. Designed as a functional first playable pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WorldPvPRemotes")
local SelectNation = remotes:WaitForChild("SelectNation")
local Attack = remotes:WaitForChild("Attack")
local Build = remotes:WaitForChild("Build")
local Nuke = remotes:WaitForChild("Nuke")
local RequestSnapshot = remotes:WaitForChild("RequestSnapshot")
local Snapshot = remotes:WaitForChild("Snapshot")
local Notice = remotes:WaitForChild("Notice")

local gui = Instance.new("ScreenGui")
gui.Name = "WorldPvP"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1,1)
bg.BackgroundColor3 = Color3.fromRGB(9,14,22)
bg.BorderSizePixel = 0
bg.Parent = gui

local top = Instance.new("Frame")
top.Size = UDim2.new(1,0,0,64)
top.BackgroundColor3 = Color3.fromRGB(15,23,35)
top.BorderSizePixel = 0
top.Parent = bg

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0,300,1,0)
title.Position = UDim2.fromOffset(18,0)
title.BackgroundTransparency = 1
title.Text = "WORLD DOMINION"
title.TextColor3 = Color3.fromRGB(235,242,255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local stats = Instance.new("TextLabel")
stats.Size = UDim2.new(1,-340,1,0)
stats.Position = UDim2.fromOffset(325,0)
stats.BackgroundTransparency = 1
stats.Text = "اختر دولة للبدء"
stats.TextColor3 = Color3.fromRGB(160,180,205)
stats.Font = Enum.Font.GothamBold
stats.TextSize = 15
stats.TextXAlignment = Enum.TextXAlignment.Right
stats.Parent = top

local mapFrame = Instance.new("Frame")
mapFrame.Size = UDim2.new(1,-430,1,-90)
mapFrame.Position = UDim2.fromOffset(18,78)
mapFrame.BackgroundColor3 = Color3.fromRGB(18,29,43)
mapFrame.BorderSizePixel = 0
mapFrame.Parent = bg

local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0,16)
mapCorner.Parent = mapFrame

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.AnchorPoint = Vector2.new(0.5,0.5)
grid.Position = UDim2.fromScale(0.5,0.5)
grid.Parent = mapFrame

local layout = Instance.new("UIGridLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.CellPadding = UDim2.fromOffset(1,1)
layout.Parent = grid

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,370,1,-90)
panel.Position = UDim2.new(1,-388,0,78)
panel.BackgroundColor3 = Color3.fromRGB(15,23,35)
panel.BorderSizePixel = 0
panel.Parent = bg

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0,16)
panelCorner.Parent = panel

local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1,-28,0,42)
panelTitle.Position = UDim2.fromOffset(14,12)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "الدولة / الإقليم"
panelTitle.TextColor3 = Color3.fromRGB(235,242,255)
panelTitle.Font = Enum.Font.GothamBold
panelTitle.TextSize = 19
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Parent = panel

local detail = Instance.new("TextLabel")
detail.Size = UDim2.new(1,-28,0,130)
detail.Position = UDim2.fromOffset(14,58)
detail.BackgroundTransparency = 1
detail.Text = "اضغط على دولة غير محتلة لاختيارها، أو اضغط على إقليم مجاور لمهاجمته."
detail.TextWrapped = true
detail.TextColor3 = Color3.fromRGB(165,182,205)
detail.Font = Enum.Font.Gotham
detail.TextSize = 14
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.Parent = panel

local selectedCell = nil
local selectedNation = nil
local snapshot = nil
local buttons = {}

local function button(text, y, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-28,0,42)
    b.Position = UDim2.fromOffset(14,y)
    b.BackgroundColor3 = Color3.fromRGB(35,55,78)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = panel
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,10)
    c.Parent = b
    b.MouseButton1Click:Connect(callback)
    return b
end

local selectBtn = button("اختيار الدولة", 205, function()
    if selectedNation then
        SelectNation:FireServer(selectedNation)
    end
end)

local attackBtn = button("هجوم — 5,000 جندي", 253, function()
    if selectedCell then
        Attack:FireServer(selectedCell, 5000)
    end
end)

local cityBtn = button("بناء مدينة — 25K", 301, function()
    if selectedCell then Build:FireServer(selectedCell, "City") end
end)

local factoryBtn = button("بناء مصنع — 80K", 349, function()
    if selectedCell then Build:FireServer(selectedCell, "Factory") end
end)

local portBtn = button("بناء ميناء — 50K", 397, function()
    if selectedCell then Build:FireServer(selectedCell, "Port") end
end)

local siloBtn = button("بناء صومعة صاروخية — 150K", 445, function()
    if selectedCell then Build:FireServer(selectedCell, "MissileSilo") end
end)

local nukeBtn = button("إطلاق نووي", 493, function()
    if selectedCell then Nuke:FireServer(selectedCell) end
end)

local notice = Instance.new("TextLabel")
notice.Size = UDim2.new(1,-36,0,44)
notice.Position = UDim2.new(0,18,1,-54)
notice.BackgroundColor3 = Color3.fromRGB(20,31,46)
notice.BackgroundTransparency = 0.1
notice.Text = ""
notice.TextColor3 = Color3.fromRGB(220,235,255)
notice.Font = Enum.Font.GothamBold
notice.TextSize = 13
notice.TextWrapped = true
notice.Parent = bg

local function nationColor(nationId)
    if not snapshot then return Color3.fromRGB(70,80,95) end
    for _, nation in ipairs(snapshot.nations) do
        if nation.id == nationId then
            local c = nation.color or {r=.3,g=.6,b=.9}
            return Color3.new(c.r,c.g,c.b)
        end
    end
    return Color3.fromRGB(70,80,95)
end

local function nationInfo(nationId)
    if not snapshot then return nil end
    for _, nation in ipairs(snapshot.nations) do
        if nation.id == nationId then return nation end
    end
end

local function showDetail(cell)
    selectedCell = cell.id
    selectedNation = cell.ownerId

    if cell.ownerId then
        local nation = nationInfo(cell.ownerId)
        detail.Text = string.format(
            "%s\nالأرض: %s\nجيش الدولة: %s\nالذهب: %s\nنسبة العالم: %.1f%%\nالمبنى: %s",
            nation and nation.name or cell.ownerId,
            cell.isCoastal and "ساحلية" or "داخلية",
            nation and math.floor(nation.troops) or 0,
            nation and math.floor(nation.gold) or 0,
            nation and nation.worldShare * 100 or 0,
            cell.building and cell.building.kind or "لا يوجد"
        )
    else
        detail.Text = "أرض محايدة\nاضغط اختيار الدولة لاختيار دولة من الخريطة."
    end
end

local function rebuildMap()
    if not snapshot then return end

    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local total = snapshot.width * snapshot.height
    local cellPx = math.clamp(math.floor(650 / snapshot.width), 10, 22)
    grid.Size = UDim2.fromOffset(snapshot.width * cellPx, snapshot.height * cellPx)
    layout.CellSize = UDim2.fromOffset(cellPx, cellPx)

    for index, cell in ipairs(snapshot.cells) do
        local b = Instance.new("TextButton")
        b.LayoutOrder = index
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = cell.building and "◆" or ""
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = math.max(8, cellPx - 7)

        if not cell.isLand then
            b.BackgroundColor3 = Color3.fromRGB(20,55,85)
        elseif cell.ownerId then
            b.BackgroundColor3 = nationColor(cell.ownerId)
        else
            b.BackgroundColor3 = Color3.fromRGB(80,88,88)
        end

        b.Parent = grid
        b.MouseButton1Click:Connect(function()
            showDetail(cell)

            if cell.ownerId then
                local mine = false
                for _, n in ipairs(snapshot.nations) do
                    if n.id == cell.ownerId and n.ownerUserId == player.UserId then
                        mine = true
                        break
                    end
                end
                if mine then
                    selectedNation = cell.ownerId
                end
            else
                selectedNation = nil
            end
        end)
    end
end

Snapshot.OnClientEvent:Connect(function(data)
    snapshot = data
    rebuildMap()

    local mine = nil
    for _, nation in ipairs(data.nations) do
        if nation.ownerUserId == player.UserId then
            mine = nation
            break
        end
    end

    if mine then
        stats.Text = string.format(
            "%s  |  🪙 %s  |  ⚔ %s  |  🌍 %.1f%%",
            mine.name,
            math.floor(mine.gold),
            math.floor(mine.troops),
            mine.worldShare * 100
        )
        selectBtn.Text = "الدولة: " .. mine.name
    else
        stats.Text = "اختر دولة غير محتلة للبدء — هدف النصر: 80% من العالم"
        selectBtn.Text = "اختيار الدولة المحددة"
    end
end)

Notice.OnClientEvent:Connect(function(data)
    notice.Text = data.message or ""
    notice.TextColor3 = data.kind == "error"
        and Color3.fromRGB(255,110,110)
        or data.kind == "warning"
        and Color3.fromRGB(255,205,90)
        or Color3.fromRGB(150,235,170)
end)

RequestSnapshot:FireServer()
