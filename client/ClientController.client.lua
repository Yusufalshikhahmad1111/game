-- StarterPlayer/StarterPlayerScripts/ClientController.client.lua (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")

local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))
local HttpService = game:GetService("HttpService")

-- Terrain type display abbreviations and colors
local TerrainDisplay = {
    Plains = {symbol = "P", color = Color3.fromRGB(34, 139, 34)},
    Forest = {symbol = "F", color = Color3.fromRGB(0, 100, 0)},
    Mine   = {symbol = "M", color = Color3.fromRGB(169, 169, 169)},
    Ruins  = {symbol = "R", color = Color3.fromRGB(139, 69, 19)},
    Fortress = {symbol = "F", color = Color3.fromRGB(128, 0, 128)},
    Capital = {symbol = "C", color = Color3.fromRGB(255, 215, 0)},
    Harbor = {symbol = "H", color = Color3.fromRGB(0, 191, 255)}
}

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "StrategyGameGUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 640, 0, 820)
main.Position = UDim2.new(0.5, -320, 0.5, -410)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
main.BorderSizePixel = 0
main.Parent = gui

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Island Dominion - استراتيجية الأراضي"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = main

-- Turn & Resources display
local infoFrame = Instance.new("Frame")
infoFrame.Size = UDim2.new(1, -20, 0, 70)
infoFrame.Position = UDim2.new(0, 10, 0, 50)
infoFrame.BackgroundTransparency = 1
infoFrame.Parent = main

local turnLabel = Instance.new("TextLabel")
turnLabel.Size = UDim2.new(0.5, 0, 1, 0)
turnLabel.BackgroundTransparency = 1
turnLabel.TextColor3 = Color3.new(1, 1, 0)
turnLabel.Font = Enum.Font.Gotham
turnLabel.TextSize = 16
turnLabel.Text = "الدور: لاعب"
turnLabel.Parent = infoFrame

local resourceLabel = Instance.new("TextLabel")
resourceLabel.Size = UDim2.new(0.5, 0, 1, 0)
resourceLabel.Position = UDim2.new(0.5, 0, 0, 0)
resourceLabel.BackgroundTransparency = 1
resourceLabel.TextColor3 = Color3.new(1, 1, 0)
resourceLabel.Font = Enum.Font.Gotham
resourceLabel.TextSize = 16
resourceLabel.Text = "الموارد: Gold 0 | Food 0 | Wood 0 | Relic 0"
resourceLabel.Parent = infoFrame

-- Map size selector
local sizeFrame = Instance.new("Frame")
sizeFrame.Size = UDim2.new(1, -20, 0, 40)
sizeFrame.Position = UDim2.new(0, 10, 0, 130)
sizeFrame.BackgroundTransparency = 1
sizeFrame.Parent = main

local sizeLabel = Instance.new("TextLabel")
sizeLabel.Size = UDim2.new(0, 100, 1, 0)
sizeLabel.BackgroundTransparency = 1
sizeLabel.Text = "حجم الخريطة:"
sizeLabel.TextColor3 = Color3.new(1, 1, 1)
sizeLabel.Font = Enum.Font.Gotham
sizeLabel.TextSize = 16
sizeLabel.Parent = sizeFrame

local function makeSizeButton(text, sizeValue)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = text
    btn.MouseButton1Click:Connect(function()
        SetMapSize:FireServer(sizeValue)
    end)
    return btn
end

for _, sz in ipairs(MapData.AvailableSizes) do
    local btn = makeSizeButton(tostring(sz) .. "x" .. tostring(sz), sz)
    btn.Parent = sizeFrame
end

local sizeLayout = Instance.new("UIListLayout")
sizeLayout.FillDirection = Enum.FillDirection.Horizontal
sizeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
sizeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sizeLayout.Padding = UDim2.new(0, 8, 0, 0)
sizeLayout.Parent = sizeFrame

-- Grid container
local gridContainer = Instance.new("Frame")
gridContainer.Size = UDim2.new(1, -20, 0, 520)
gridContainer.Position = UDim2.new(0, 10, 0, 180)
gridContainer.BackgroundTransparency = 1
gridContainer.Parent = main

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 50, 0, 50)
gridLayout.CellPadding = UDim2.new(0, 2, 0, 2)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- Color selection
local colorFrame = Instance.new("Frame")
colorFrame.Size = UDim2.new(1, -20, 0, 60)
colorFrame.Position = UDim2.new(0, 10, 0, 720)
colorFrame.BackgroundTransparency = 1
colorFrame.Parent = main

local colorLayout = Instance.new("UIGridLayout")
colorLayout.CellSize = UDim2.new(0, 100, 0, 44)
colorLayout.CellPadding = UDim2.new(0, 5, 0, 5)
colorLayout.Parent = colorFrame

local cellButtons = {}

local function colorForOwner(owner)
    return {
        Player = Color3.fromRGB(0, 120, 255),
        AI1 = Color3.fromRGB(255, 50, 50),
        AI2 = Color3.fromRGB(50, 255, 50),
        Neutral = Color3.fromRGB(100, 100, 100)
    }[owner] or Color3.new(1, 1, 1)
end

local function terrainSymbol(terrainType)
    return TerrainDisplay[terrainType] and TerrainDisplay[terrainType].symbol or "?"
end

local function buildMap(data)
    for _, b in pairs(cellButtons) do b:Destroy() end
    cellButtons = {}

    local mapSize = math.sqrt(#data)
    local cellSize = math.clamp(600 / mapSize, 30, 80)
    gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)

    for _, cell in ipairs(data) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, cellSize, 0, cellSize)

        local sym = terrainSymbol(cell.terrainType)
        local ownerSym = cell.owner == "Player" and "P"
            or cell.owner == "AI1" and "A1"
            or cell.owner == "AI2" and "A2"
            or "N"

        -- Show terrain symbol with owner indicator
        btn.Text = sym .. ownerSym
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BackgroundColor3 = colorForOwner(cell.owner)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = math.clamp(12, 8, 18)
        btn.Parent = gridContainer

        cellButtons[cell.id] = btn
        btn:SetAttribute("Owner", cell.owner)
        btn:SetAttribute("TerrainType", cell.terrainType or "Plains")
        btn:SetAttribute("TerrainColor", cell.color or Color3.new(1,1,1))
        btn:SetAttribute("BaseYield", HttpService:JSONEncode(cell.baseYield or {}))
        btn:SetAttribute("ProductionPerTurn", HttpService:JSONEncode(cell.productionPerTurn or {}))
        btn:SetAttribute("StrategicValue", cell.strategicValue or 1)
        btn:SetAttribute("DefenseModifier", cell.defenseModifier or 0)

        -- Hover tooltip
        btn.MouseEnter:Connect(function()
            local tip = string.format(
                "%s (%s)\nالمالك: %s\nالقيمة الاستراتيجية: %d\nالدفاع: %d%%",
                cell.terrainType or "?",
                cell.owner or "Neutral",
                cell.owner or "Neutral",
                cell.strategicValue or 1,
                math.floor((cell.defenseModifier or 0) * 100)
            )
            -- Simple tooltip via label update
            turnLabel.Text = tip
        end)

        btn.MouseLeave:Connect(function()
            turnLabel.Text = "الدور: " .. (turnLabel:GetAttribute("LastTeam") or "لاعب")
        end)
    end
end

local function updateResources(resources)
    resourceLabel.Text = string.format(
        "الموارد: Gold %d | Food %d | Wood %d | Relic %d",
        resources.Gold or 0,
        resources.Food or 0,
        resources.Wood or 0,
        resources.Relic or 0
    )
end

local function playVisualEffect(cellIds, colorName)
    local flashColor = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 0, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Purple = Color3.fromRGB(160, 32, 240),
        Orange = Color3.fromRGB(255, 165, 0)
    }[colorName] or Color3.new(1, 1, 1)

    for _, id in ipairs(cellIds) do
        local btn = cellButtons[id]
        if btn then
            local original = btn.BackgroundColor3
            btn.BackgroundColor3 = flashColor
            task.spawn(function()
                task.wait(0.15)
                if btn and btn.Parent then
                    btn.BackgroundColor3 = original
                end
            end)
        end
    end
end

UpdateMap.OnClientEvent:Connect(function(data, currentTeam, active)
    buildMap(data)
    turnLabel:SetAttribute("LastTeam", currentTeam)
    if active then
        turnLabel.Text = "الدور: " .. currentTeam
        turnLabel.TextColor3 = (currentTeam == "Player") and Color3.new(0, 1, 0) or Color3.new(1, 0.6, 0)
    else
        turnLabel.Text = "انتهت اللعبة!"
    end
end)

GameOver.OnClientEvent:Connect(function(winner)
    turnLabel.Text = "الفائز: " .. winner
    turnLabel.TextColor3 = Color3.new(0, 1, 0)
end)

ResourceUpdate.OnClientEvent:Connect(function(resources)
    updateResources(resources)
end)

VisualEffect.OnClientEvent:Connect(function(cellIds, colorName)
    playVisualEffect(cellIds, colorName)
end)

-- Initialize color buttons
local function setupColorButtons(colors)
    for _, c in ipairs(colors) do
        local btn = Instance.new("TextButton")
        btn.Text = c
        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.Parent = colorFrame
        btn.MouseButton1Click:Connect(function()
            SelectColor:FireServer(c)
        end)
    end
end

setupColorButtons(MapData.Colors or {"Red", "Blue", "Green", "Yellow", "Purple", "Orange"})