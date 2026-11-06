-- StarterPlayer/StarterPlayerScripts/ClientController.client.lua (LocalScript)
-- M6: Multiplayer + Fairness UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UsePower = Remotes:WaitForChild("UsePower")
local JoinLobby = Remotes:WaitForChild("JoinLobby")
local LeaveLobby = Remotes:WaitForChild("LeaveLobby")
local SetReady = Remotes:WaitForChild("SetReady")
local StartMatch = Remotes:WaitForChild("StartMatch")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")
local EventNotify = Remotes:WaitForChild("EventNotify")
local LobbyState = Remotes:WaitForChild("LobbyState")
local MatchState = Remotes:WaitForChild("MatchState")
local TurnTimeout = Remotes:WaitForChild("TurnTimeout")

local MapData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapData"))

-- ============================================================
-- CONFIGURATION & THEME
-- ============================================================
local THEME = {
    Background = Color3.fromRGB(18, 18, 22),
    Surface = Color3.fromRGB(28, 28, 34),
    SurfaceElevated = Color3.fromRGB(38, 38, 46),
    Border = Color3.fromRGB(60, 60, 70),
    TextPrimary = Color3.new(1, 1, 1),
    TextSecondary = Color3.fromRGB(200, 200, 200),
    Accent = Color3.fromRGB(0, 170, 255),
    Success = Color3.fromRGB(0, 255, 120),
    Warning = Color3.fromRGB(255, 180, 0),
    Danger = Color3.fromRGB(255, 60, 60),
    Neutral = Color3.fromRGB(120, 120, 120)
}

local TEAM_COLORS = {
    Player = Color3.fromRGB(0, 120, 255),
    AI1 = Color3.fromRGB(255, 50, 50),
    AI2 = Color3.fromRGB(50, 255, 50),
    Neutral = Color3.fromRGB(100, 100, 100)
}

local TERRAIN_SYMBOLS = {
    Plains = "🌾",
    Forest = "🌲",
    Mine = "⛏️",
    Ruins = "🏛️",
    Fortress = "🏰",
    Capital = "🏛️",
    Harbor = "⚓"
}

local TERRAIN_NAMES_AR = {
    Plains = "سهل",
    Forest = "غابة",
    Mine = "منجم",
    Ruins = "آثار",
    Fortress = "حصن",
    Capital = "عاصمة",
    Harbor = "ميناء"
}

-- ============================================================
-- GUI STATE
-- ============================================================
local cellButtons = {}
local selectedCellId = nil
local isGameActive = false
local currentTeam = "Player"
local myTeam = nil
local myResources = {Gold = 0, Food = 0, Wood = 0, Relic = 0}
local turnStartTime = nil
local turnTimeoutDuration = 30

-- ============================================================
-- GUI CONSTRUCTION
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "StrategyGameGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Main container
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(1, 0, 1, 0)
main.Position = UDim2.new(0, 0, 0, 0)
main.BackgroundColor3 = THEME.Background
main.BorderSizePixel = 0
main.Parent = gui

-- ============================================================
-- LOBBY PANEL (shown before match starts)
-- ============================================================
local lobbyPanel = Instance.new("Frame")
lobbyPanel.Name = "LobbyPanel"
lobbyPanel.Size = UDim2.new(1, 0, 1, 0)
lobbyPanel.Position = UDim2.new(0, 0, 0, 0)
lobbyPanel.BackgroundColor3 = THEME.Surface
lobbyPanel.BorderSizePixel = 0
lobbyPanel.Visible = true
lobbyPanel.Parent = main

local lobbyTitle = Instance.new("TextLabel")
lobbyTitle.Name = "Title"
lobbyTitle.Size = UDim2.new(1, 0, 0, 60)
lobbyTitle.BackgroundTransparency = 1
lobbyTitle.Text = "Island Dominion - اللوبي"
lobbyTitle.TextColor3 = THEME.TextPrimary
lobbyTitle.Font = Enum.Font.GothamBold
lobbyTitle.TextSize = 24
lobbyTitle.Parent = lobbyPanel

local lobbyPlayersList = Instance.new("ScrollingFrame")
lobbyPlayersList.Name = "PlayersList"
lobbyPlayersList.Size = UDim2.new(0, 300, 0, 300)
lobbyPlayersList.Position = UDim2.new(0.5, -150, 0.3, -150)
lobbyPlayersList.BackgroundColor3 = THEME.SurfaceElevated
lobbyPlayersList.BorderSizePixel = 0
lobbyPlayersList.ScrollBarThickness = 4
lobbyPlayersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
lobbyPlayersList.Parent = lobbyPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim2.new(0, 0, 0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = lobbyPlayersList

local myTeamLabel = Instance.new("TextLabel")
myTeamLabel.Name = "MyTeamLabel"
myTeamLabel.Size = UDim2.new(0, 300, 0, 40)
myTeamLabel.Position = UDim2.new(0.5, -150, 0.65, 0)
myTeamLabel.BackgroundTransparency = 1
myTeamLabel.Text = "فريقك: غير محدد"
myTeamLabel.TextColor3 = THEME.TextSecondary
myTeamLabel.Font = Enum.Font.GothamBold
myTeamLabel.TextSize = 16
myTeamLabel.Parent = lobbyPanel

local readyButton = Instance.new("TextButton")
readyButton.Name = "ReadyButton"
readyButton.Size = UDim2.new(0, 140, 0, 44)
readyButton.Position = UDim2.new(0.5, -150, 0.72, 0)
readyButton.BackgroundColor3 = THEME.Success
readyButton.BorderSizePixel = 0
readyButton.Text = "جاهز"
readyButton.TextColor3 = Color3.new(1, 1, 1)
readyButton.Font = Enum.Font.GothamBold
readyButton.TextSize = 16
readyButton.Parent = lobbyPanel

local readyCorner = Instance.new("UICorner")
readyCorner.CornerRadius = UDim.new(0, 8)
readyCorner.Parent = readyButton

local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(0, 140, 0, 44)
startButton.Position = UDim2.new(0.5, 10, 0.72, 0)
startButton.BackgroundColor3 = THEME.Accent
startButton.BorderSizePixel = 0
startButton.Text = "ابدأ المباراة"
startButton.TextColor3 = Color3.new(1, 1, 1)
startButton.Font = Enum.Font.GothamBold
startButton.TextSize = 16
startButton.Parent = lobbyPanel

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 8)
startCorner.Parent = startButton

local mapSizeLabel = Instance.new("TextLabel")
mapSizeLabel.Name = "MapSizeLabel"
mapSizeLabel.Size = UDim2.new(0, 300, 0, 24)
mapSizeLabel.Position = UDim2.new(0.5, -150, 0.8, 0)
mapSizeLabel.BackgroundTransparency = 1
mapSizeLabel.Text = "حجم الخريطة: 10×10"
mapSizeLabel.TextColor3 = THEME.TextSecondary
mapSizeLabel.Font = Enum.Font.Gotham
mapSizeLabel.TextSize = 14
mapSizeLabel.Parent = lobbyPanel

local mapSizeButtons = Instance.new("Frame")
mapSizeButtons.Name = "MapSizeButtons"
mapSizeButtons.Size = UDim2.new(0, 300, 0, 30)
mapSizeButtons.Position = UDim2.new(0.5, -150, 0.84, 0)
mapSizeButtons.BackgroundTransparency = 1
mapSizeButtons.Parent = lobbyPanel

local msLayout = Instance.new("UIListLayout")
msLayout.FillDirection = Enum.FillDirection.Horizontal
msLayout.Padding = UDim2.new(0, 6, 0, 0)
msLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
msLayout.VerticalAlignment = Enum.VerticalAlignment.Center
msLayout.Parent = mapSizeButtons

-- ============================================================
-- TOP HUD (shown during match)
-- ============================================================
local topHUD = Instance.new("Frame")
topHUD.Name = "TopHUD"
topHUD.Size = UDim2.new(1, 0, 0, 80)
topHUD.Position = UDim2.new(0, 0, 0, 0)
topHUD.BackgroundColor3 = THEME.Surface
topHUD.BorderSizePixel = 0
topHUD.Visible = false
topHUD.Parent = main

local topHUDLine = Instance.new("Frame")
topHUDLine.Size = UDim2.new(1, 0, 0, 2)
topHUDLine.Position = UDim2.new(0, 0, 1, -2)
topHUDLine.BackgroundColor3 = THEME.Accent
topHUDLine.BorderSizePixel = 0
topHUDLine.Parent = topHUD

local turnContainer = Instance.new("Frame")
turnContainer.Name = "TurnContainer"
turnContainer.Size = UDim2.new(0.33, 0, 1, 0)
turnContainer.Position = UDim2.new(0, 0, 0, 0)
turnContainer.BackgroundTransparency = 1
turnContainer.Parent = topHUD

local turnLabel = Instance.new("TextLabel")
turnLabel.Name = "TurnLabel"
turnLabel.Size = UDim2.new(1, -40, 0.5, 0)
turnLabel.Position = UDim2.new(0, 20, 0, 0)
turnLabel.BackgroundTransparency = 1
turnLabel.Text = "الدور: لاعب"
turnLabel.TextColor3 = THEME.TextPrimary
turnLabel.Font = Enum.Font.GothamBold
turnLabel.TextSize = 18
turnLabel.TextXAlignment = Enum.TextXAlignment.Left
turnLabel.Parent = turnContainer

local turnBadge = Instance.new("TextLabel")
turnBadge.Name = "TurnBadge"
turnBadge.Size = UDim2.new(0, 30, 0, 30)
turnBadge.Position = UDim2.new(1, -40, 0.15, 0)
turnBadge.BackgroundColor3 = THEME.Success
turnBadge.BorderSizePixel = 0
turnBadge.Text = "P"
turnBadge.TextColor3 = Color3.new(1, 1, 1)
turnBadge.Font = Enum.Font.GothamBold
turnBadge.TextSize = 16
turnBadge.Parent = turnContainer

local turnTimerLabel = Instance.new("TextLabel")
turnTimerLabel.Name = "TurnTimer"
turnTimerLabel.Size = UDim2.new(1, -40, 0.5, 0)
turnTimerLabel.Position = UDim2.new(0, 20, 0.5, 0)
turnTimerLabel.BackgroundTransparency = 1
turnTimerLabel.Text = "الوقت المتبقي: 30s"
turnTimerLabel.TextColor3 = THEME.TextSecondary
turnTimerLabel.Font = Enum.Font.Gotham
turnTimerLabel.TextSize = 12
turnTimerLabel.TextXAlignment = Enum.TextXAlignment.Left
turnTimerLabel.Parent = turnContainer

local resourcesContainer = Instance.new("Frame")
resourcesContainer.Name = "ResourcesContainer"
resourcesContainer.Size = UDim2.new(0.34, 0, 1, 0)
resourcesContainer.Position = UDim2.new(0.33, 0, 0, 0)
resourcesContainer.BackgroundTransparency = 1
resourcesContainer.Parent = topHUD

local resourceLabel = Instance.new("TextLabel")
resourceLabel.Name = "ResourceLabel"
resourceLabel.Size = UDim2.new(1, -20, 1, 0)
resourceLabel.Position = UDim2.new(0, 10, 0, 0)
resourceLabel.BackgroundTransparency = 1
resourceLabel.Text = "🪙 0 | 🍖 0 | 🪵 0 | 🔮 0"
resourceLabel.TextColor3 = THEME.TextSecondary
resourceLabel.Font = Enum.Font.Gotham
resourceLabel.TextSize = 16
resourceLabel.TextXAlignment = Enum.TextXAlignment.Center
resourceLabel.Parent = resourcesContainer

local dominionContainer = Instance.new("Frame")
dominionContainer.Name = "DominionContainer"
dominionContainer.Size = UDim2.new(0.33, 0, 1, 0)
dominionContainer.Position = UDim2.new(0.67, 0, 0, 0)
dominionContainer.BackgroundTransparency = 1
dominionContainer.Parent = topHUD

local dominionLabel = Instance.new("TextLabel")
dominionLabel.Name = "DominionLabel"
dominionLabel.Size = UDim2.new(1, -20, 1, 0)
dominionLabel.Position = UDim2.new(0, 10, 0, 0)
dominionLabel.BackgroundTransparency = 1
dominionLabel.Text = "السيطرة: 0%"
dominionLabel.TextColor3 = THEME.TextPrimary
dominionLabel.Font = Enum.Font.GothamBold
dominionLabel.TextSize = 16
dominionLabel.TextXAlignment = Enum.TextXAlignment.Right
dominionLabel.Parent = dominionContainer

-- Power panel
local powerPanel = Instance.new("Frame")
powerPanel.Name = "PowerPanel"
powerPanel.Size = UDim2.new(0.33, 0, 1, 0)
powerPanel.Position = UDim2.new(0, 0, 0, 0)
powerPanel.BackgroundTransparency = 1
powerPanel.Parent = topHUD

local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "PowerLabel"
powerLabel.Size = UDim2.new(1, -20, 0.5, 0)
powerLabel.Position = UDim2.new(0, 10, 0, 5)
powerLabel.BackgroundTransparency = 1
powerLabel.Text = "القوى: --"
powerLabel.TextColor3 = THEME.TextSecondary
powerLabel.Font = Enum.Font.Gotham
powerLabel.TextSize = 14
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.Parent = powerPanel

local powerCooldownLabel = Instance.new("TextLabel")
powerCooldownLabel.Name = "PowerCooldown"
powerCooldownLabel.Size = UDim2.new(1, -20, 0.5, 0)
powerCooldownLabel.Position = UDim2.new(0, 10, 0.5, 0)
powerCooldownLabel.BackgroundTransparency = 1
powerCooldownLabel.Text = "التجديد: --"
powerCooldownLabel.TextColor3 = THEME.Warning
powerCooldownLabel.Font = Enum.Font.Gotham
powerCooldownLabel.TextSize = 12
powerCooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
powerCooldownLabel.Parent = powerPanel

-- Event notification area
local eventNotifyFrame = Instance.new("Frame")
eventNotifyFrame.Name = "EventNotifyFrame"
eventNotifyFrame.Size = UDim2.new(0, 300, 0, 60)
eventNotifyFrame.Position = UDim2.new(0.5, -150, 0, 100)
eventNotifyFrame.BackgroundColor3 = THEME.SurfaceElevated
eventNotifyFrame.BorderSizePixel = 0
eventNotifyFrame.Visible = false
eventNotifyFrame.ZIndex = 20
eventNotifyFrame.Parent = main

local eventCorner = Instance.new("UICorner")
eventCorner.CornerRadius = UDim.new(0, 8)
eventCorner.Parent = eventNotifyFrame

local eventStroke = Instance.new("UIStroke")
eventStroke.Color = THEME.Accent
eventStroke.Thickness = 2
eventStroke.Parent = eventNotifyFrame

local eventIconLabel = Instance.new("TextLabel")
eventIconLabel.Name = "EventIcon"
eventIconLabel.Size = UDim2.new(0, 50, 1, 0)
eventIconLabel.Position = UDim2.new(0, 10, 0, 0)
eventIconLabel.BackgroundTransparency = 1
eventIconLabel.Text = "☄️"
eventIconLabel.TextColor3 = THEME.TextPrimary
eventIconLabel.Font = Enum.Font.GothamBold
eventIconLabel.TextSize = 32
eventIconLabel.Parent = eventNotifyFrame

local eventTextLabel = Instance.new("TextLabel")
eventTextLabel.Name = "EventText"
eventTextLabel.Size = UDim2.new(1, -70, 1, 0)
eventTextLabel.Position = UDim2.new(0, 70, 0, 0)
eventTextLabel.BackgroundTransparency = 1
eventTextLabel.Text = "حدث عالمي نشط!"
eventTextLabel.TextColor3 = THEME.TextPrimary
eventTextLabel.Font = Enum.Font.GothamBold
eventTextLabel.TextSize = 18
eventTextLabel.TextXAlignment = Enum.TextXAlignment.Left
eventTextLabel.Parent = eventNotifyFrame

-- ============================================================
-- BOARD AREA
-- ============================================================
local boardArea = Instance.new("Frame")
boardArea.Name = "BoardArea"
boardArea.Size = UDim2.new(1, 0, 1, -140)
boardArea.Position = UDim2.new(0, 0, 0, 90)
boardArea.BackgroundTransparency = 1
boardArea.Visible = false
boardArea.Parent = main

local gridContainer = Instance.new("Frame")
gridContainer.Name = "GridContainer"
gridContainer.Size = UDim2.new(0, 600, 0, 600)
gridContainer.Position = UDim2.new(0.5, -300, 0.5, -300)
gridContainer.BackgroundTransparency = 1
gridContainer.Parent = boardArea

local gridLayout = Instance.new("UIGridLayout")
gridLayout.Name = "GridLayout"
gridLayout.CellSize = UDim2.new(0, 50, 0, 50)
gridLayout.CellPadding = UDim2.new(0, 2, 0, 2)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- ============================================================
-- INSPECTOR PANEL
-- ============================================================
local inspector = Instance.new("Frame")
inspector.Name = "Inspector"
inspector.Size = UDim2.new(0, 300, 1, -90)
inspector.Position = UDim2.new(1, 0, 0, 90)
inspector.BackgroundColor3 = THEME.SurfaceElevated
inspector.BorderSizePixel = 0
inspector.Visible = false
inspector.Parent = main

local inspectorLine = Instance.new("Frame")
inspectorLine.Size = UDim2.new(0, 2, 1, 0)
inspectorLine.Position = UDim2.new(0, 0, 0, 0)
inspectorLine.BackgroundColor3 = THEME.Accent
inspectorLine.BorderSizePixel = 0
inspectorLine.Parent = inspector

local inspectorTitle = Instance.new("TextLabel")
inspectorTitle.Name = "Title"
inspectorTitle.Size = UDim2.new(1, -20, 0, 40)
inspectorTitle.Position = UDim2.new(0, 10, 0, 10)
inspectorTitle.BackgroundTransparency = 1
inspectorTitle.Text = "تفاصيل الخلية"
inspectorTitle.TextColor3 = THEME.TextPrimary
inspectorTitle.Font = Enum.Font.GothamBold
inspectorTitle.TextSize = 18
inspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
inspectorTitle.Parent = inspector

local inspectorContent = Instance.new("ScrollingFrame")
inspectorContent.Name = "Content"
inspectorContent.Size = UDim2.new(1, -20, 1, -60)
inspectorContent.Position = UDim2.new(0, 10, 0, 55)
inspectorContent.BackgroundTransparency = 1
inspectorContent.BorderSizePixel = 0
inspectorContent.ScrollBarThickness = 4
inspectorContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
inspectorContent.Parent = inspector

local inspectorList = Instance.new("UIListLayout")
inspectorList.Padding = UDim2.new(0, 0, 0, 8)
inspectorList.SortOrder = Enum.SortOrder.LayoutOrder
inspectorList.Parent = inspectorContent

local closeInspector = Instance.new("TextButton")
closeInspector.Name = "Close"
closeInspector.Size = UDim2.new(0, 30, 0, 30)
closeInspector.Position = UDim2.new(1, -40, 0, 10)
closeInspector.BackgroundColor3 = THEME.Danger
closeInspector.BorderSizePixel = 0
closeInspector.Text = "✕"
closeInspector.TextColor3 = Color3.new(1, 1, 1)
closeInspector.Font = Enum.Font.GothamBold
closeInspector.TextSize = 18
closeInspector.Parent = inspector

-- ============================================================
-- BOTTOM ACTION BAR
-- ============================================================
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0, 50)
bottomBar.Position = UDim2.new(0, 0, 1, -50)
bottomBar.BackgroundColor3 = THEME.Surface
bottomBar.BorderSizePixel = 0
bottomBar.Visible = false
bottomBar.Parent = main

local bottomBarLine = Instance.new("Frame")
bottomBarLine.Size = UDim2.new(1, 0, 0, 2)
bottomBarLine.Position = UDim2.new(0, 0, 0, 0)
bottomBarLine.BackgroundColor3 = THEME.Accent
bottomBarLine.BorderSizePixel = 0
bottomBarLine.Parent = bottomBar

local colorLabel = Instance.new("TextLabel")
colorLabel.Name = "ColorLabel"
colorLabel.Size = UDim2.new(0, 100, 1, 0)
colorLabel.Position = UDim2.new(0, 10, 0, 0)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "اختر لون:"
colorLabel.TextColor3 = THEME.TextSecondary
colorLabel.Font = Enum.Font.GothamBold
colorLabel.TextSize = 14
colorLabel.TextXAlignment = Enum.TextXAlignment.Left
colorLabel.Parent = bottomBar

local colorFrame = Instance.new("Frame")
colorFrame.Name = "ColorFrame"
colorFrame.Size = UDim2.new(1, -420, 1, 0)
colorFrame.Position = UDim2.new(0, 120, 0, 0)
colorFrame.BackgroundTransparency = 1
colorFrame.Parent = bottomBar

local colorLayout = Instance.new("UIGridLayout")
colorLayout.Name = "ColorLayout"
colorLayout.CellSize = UDim2.new(0, 60, 0, 44)
colorLayout.CellPadding = UDim2.new(0, 8, 0, 0)
colorLayout.FillDirection = Enum.FillDirection.Horizontal
colorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
colorLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colorLayout.Parent = colorFrame

-- Power buttons
local powerFrame = Instance.new("Frame")
powerFrame.Name = "PowerFrame"
powerFrame.Size = UDim2.new(0, 200, 1, 0)
powerFrame.Position = UDim2.new(0, 340, 0, 0)
powerFrame.BackgroundTransparency = 1
powerFrame.Parent = bottomBar

local powerLayout = Instance.new("UIGridLayout")
powerLayout.Name = "PowerLayout"
powerLayout.CellSize = UDim2.new(0, 55, 0, 44)
powerLayout.CellPadding = UDim2.new(0, 6, 0, 0)
powerLayout.FillDirection = Enum.FillDirection.Horizontal
powerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
powerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
powerLayout.Parent = powerFrame

local powerButtons = {}

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function colorForOwner(owner)
    return TEAM_COLORS[owner] or THEME.Neutral
end

local function getDominionPercentage(data)
    local playerCount = 0
    local total = #data
    for _, cell in ipairs(data) do
        if cell.owner == myTeam then
            playerCount = playerCount + 1
        end
    end
    return math.floor((playerCount / total) * 100)
end

local function tweenObject(obj, props, duration, easingStyle, easingDir)
    duration = duration or 0.3
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    easingDir = easingDir or Enum.EasingDirection.Out
    local tween = TweenService:Create(obj, TweenInfo.new(duration, easingStyle, easingDir), props)
    tween:Play()
    return tween
end

local function showInspector(cellData)
    if not cellData then return end
    selectedCellId = cellData.id
    
    local owner = cellData.owner or "Neutral"
    local terrainType = cellData.terrainType or "Plains"
    local terrainName = TERRAIN_NAMES_AR[terrainType] or terrainType
    local symbol = TERRAIN_SYMBOLS[terrainType] or "?"
    
    inspectorTitle.Text = symbol .. " " .. terrainName
    
    for _, child in ipairs(inspectorContent:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local function addRow(labelText, valueText, valueColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundTransparency = 1
        row.Parent = inspectorContent
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = THEME.TextSecondary
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.5, 0, 1, 0)
        val.Position = UDim2.new(0.5, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = valueText
        val.TextColor3 = valueColor or THEME.TextPrimary
        val.Font = Enum.Font.GothamBold
        val.TextSize = 14
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = row
    end
    
    addRow("المالك:", owner, colorForOwner(owner))
    addRow("نوع الأرضية:", terrainName, THEME.Accent)
    addRow("القيمة الاستراتيجية:", tostring(cellData.strategicValue or 1), THEME.TextPrimary)
    
    local defPct = math.floor((cellData.defenseModifier or 0) * 100)
    addRow("معدل الدفاع:", defPct .. "%", defPct > 0 and THEME.Success or THEME.TextSecondary)
    
    local prod = cellData.productionPerTurn or {}
    local prodStr = ""
    for resType, amount in pairs(prod) do
        if prodStr ~= "" then prodStr = prodStr .. " | " end
        local resIcon = {Gold = "🪙", Food = "🍖", Wood = "🪵", Relic = "🔮"}[resType] or ""
        prodStr = prodStr .. resIcon .. resType .. " +" .. amount
    end
    if prodStr ~= "" then
        addRow("الإنتاج لكل دور:", prodStr, THEME.Success)
    end
    
    inspector.Visible = true
    tweenObject(inspector, {Position = UDim2.new(1, -300, 0, 90)}, 0.3)
end

local function hideInspector()
    if not selectedCellId then return end
    tweenObject(inspector, {Position = UDim2.new(1, 0, 0, 90)}, 0.3)
    task.delay(0.3, function()
        if inspector and inspector.Position == UDim2.new(1, 0, 0, 90) then
            inspector.Visible = false
        end
    end)
    selectedCellId = nil
end

-- ============================================================
-- LOBBY UI
-- ============================================================
local function updateLobbyUI(data)
    -- Clear players list
    for _, child in ipairs(lobbyPlayersList:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Add players
    for _, pInfo in ipairs(data.players) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 24)
        row.BackgroundColor3 = THEME.SurfaceElevated
        row.BorderSizePixel = 0
        row.Parent = lobbyPlayersList
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 6)
        rowCorner.Parent = row
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
        nameLabel.Position = UDim2.new(0, 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = pInfo.playerName .. " (" .. pInfo.team .. ")"
        nameLabel.TextColor3 = THEME.TextPrimary
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0.3, 0, 1, 0)
        statusLabel.Position = UDim2.new(0.7, 0, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = pInfo.ready and "جاهز" or "غير جاهز"
        statusLabel.TextColor3 = pInfo.ready and THEME.Success or THEME.Warning
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 12
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.Parent = row
    end
    
    -- Update my team
    local myInfo = nil
    for _, pInfo in ipairs(data.players) do
        if pInfo.userId == player.UserId then
            myInfo = pInfo
            break
        end
    end
    
    if myInfo then
        myTeam = myInfo.team
        myTeamLabel.Text = "فريقك: " .. myTeam
        myTeamLabel.TextColor3 = colorForOwner(myTeam)
        readyButton.Visible = true
        startButton.Visible = (#data.players >= 1 and data.canStart)
    else
        myTeam = nil
        myTeamLabel.Text = "فريقك: غير محدد"
        readyButton.Visible = false
        startButton.Visible = false
    end
    
    -- Ready button state
    if myInfo then
        readyButton.Text = myInfo.ready and "إلغاء तैयارية" or "جاهز"
        readyButton.BackgroundColor3 = myInfo.ready and THEME.Warning or THEME.Success
    end
    
    lobbyPanel.Visible = true
    topHUD.Visible = false
    boardArea.Visible = false
    bottomBar.Visible = false
end

-- ============================================================
-- MAP BUILDING
-- ============================================================
local function buildMap(data)
    for _, b in pairs(cellButtons) do
        b:Destroy()
    end
    cellButtons = {}
    
    local mapSize = math.sqrt(#data)
    local cellSize = math.clamp(560 / mapSize, 24, 60)
    gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)
    
    local totalGridSize = cellSize * mapSize + 2 * (mapSize - 1)
    gridContainer.Size = UDim2.new(0, totalGridSize, 0, totalGridSize)
    gridContainer.Position = UDim2.new(0.5, -totalGridSize / 2, 0.5, -totalGridSize / 2)
    
    local dominionPct = getDominionPercentage(data)
    dominionLabel.Text = "السيطرة: " .. dominionPct .. "%"
    
    for _, cell in ipairs(data) do
        local btn = Instance.new("TextButton")
        btn.Name = cell.id
        btn.Size = UDim2.new(0, cellSize, 0, cellSize)
        btn.BackgroundColor3 = colorForOwner(cell.owner)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = math.clamp(14, 10, 18)
        btn.Text = TERRAIN_SYMBOLS[cell.terrainType] or "?"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Parent = gridContainer
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = THEME.Border
        stroke.Thickness = 1
        stroke.Parent = btn
        
        cellButtons[cell.id] = btn
        btn:SetAttribute("Owner", cell.owner)
        btn:SetAttribute("TerrainType", cell.terrainType or "Plains")
        btn:SetAttribute("CellData", HttpService:JSONEncode(cell))
        
        btn.MouseEnter:Connect(function()
            if btn:GetAttribute("Owner") ~= myTeam then
                tweenObject(btn, {BackgroundColor3 = colorForOwner(cell.owner):Lerp(Color3.new(1,1,1), 0.3)}, 0.2)
            end
        end)
        
        btn.MouseLeave:Connect(function()
            tweenObject(btn, {BackgroundColor3 = colorForOwner(cell.owner)}, 0.2)
        end)
        
        btn.MouseButton1Click:Connect(function()
            showInspector(cell)
        end)
    end
end

-- ============================================================
-- RESOURCES UPDATE (PER-PLAYER)
-- ============================================================
local function updateResources(resources)
    myResources = resources or {Gold = 0, Food = 0, Wood = 0, Relic = 0}
    resourceLabel.Text = string.format(
        "🪙 %d | 🍖 %d | 🪵 %d | 🔮 %d",
        myResources.Gold or 0,
        myResources.Food or 0,
        myResources.Wood or 0,
        myResources.Relic or 0
    )
end

-- ============================================================
-- VISUAL EFFECTS
-- ============================================================
local function playCaptureEffect(cellIds, colorName)
    local flashColorMap = {
        Red = Color3.fromRGB(255, 60, 60),
        Blue = Color3.fromRGB(60, 60, 255),
        Green = Color3.fromRGB(60, 255, 60),
        Yellow = Color3.fromRGB(255, 235, 60),
        Purple = Color3.fromRGB(180, 60, 255),
        Orange = Color3.fromRGB(255, 140, 0)
    }
    local flashColor = flashColorMap[colorName] or Color3.new(1, 1, 1)
    
    for _, id in ipairs(cellIds) do
        local btn = cellButtons[id]
        if btn then
            local originalColor = btn.BackgroundColor3
            tweenObject(btn, {BackgroundColor3 = flashColor}, 0.1)
            task.wait(0.1)
            tweenObject(btn, {BackgroundColor3 = originalColor}, 0.2)
        end
    end
end

-- ============================================================
-- TURN TIMER
-- ============================================================
local function updateTurnTimer()
    if not turnStartTime then return end
    local elapsed = tick() - turnStartTime
    local remaining = math.max(0, turnTimeoutDuration - elapsed)
    turnTimerLabel.Text = string.format("الوقت المتبقي: %ds", math.ceil(remaining))
    
    if remaining <= 0 then
        turnTimerLabel.TextColor3 = THEME.Danger
    else
        turnTimerLabel.TextColor3 = THEME.TextSecondary
    end
end

local function startTurnTimer()
    turnStartTime = tick()
    spawn(function()
        while turnStartTime do
            updateTurnTimer()
            task.wait(0.5)
        end
    end)
end

local function stopTurnTimer()
    turnStartTime = nil
    turnTimerLabel.Text = "الوقت المتبقي: --"
end

-- ============================================================
-- EVENTS
-- ============================================================
LobbyState.OnClientEvent:Connect(function(data)
    updateLobbyUI(data)
end)

MatchState.OnClientEvent:Connect(function(data)
    -- Match state updated from server
end)

UpdateMap.OnClientEvent:Connect(function(data, currentTeam, active)
    currentTeam = currentTeam or "Player"
    isGameActive = active
    currentTeam = currentTeam
    
    buildMap(data)
    
    if active then
        turnLabel.Text = "الدور: " .. currentTeam
        turnBadge.Text = currentTeam == "Player" and "P" or (currentTeam == "AI1" and "A1" or "A2")
        turnBadge.BackgroundColor3 = colorForOwner(currentTeam)
        
        local isMyTurn = (currentTeam == myTeam)
        turnLabel.TextColor3 = isMyTurn and THEME.Success or THEME.Warning
        
        if isMyTurn then
            startTurnTimer()
        else
            stopTurnTimer()
        end
    else
        turnLabel.Text = "انتهت المباراة!"
        turnLabel.TextColor3 = THEME.Danger
        stopTurnTimer()
    end
end)

GameOver.OnClientEvent:Connect(function(winner)
    isGameActive = false
    stopTurnTimer()
    turnLabel.Text = "🏆 الفائز: " .. winner
    turnLabel.TextColor3 = THEME.Success
end)

ResourceUpdate.OnClientEvent:Connect(function(resources)
    updateResources(resources)
end)

VisualEffect.OnClientEvent:Connect(function(cellIds, colorName)
    playCaptureEffect(cellIds, colorName)
end)

EventNotify.OnClientEvent:Connect(function(data)
    if data.type == "PowerState" then
        local cooldowns = data.cooldowns or {}
        local powers = data.powers or {}
        
        for powerName, btn in pairs(powerButtons) do
            local cd = cooldowns[powerName] or 0
            local power = powers[powerName]
            
            if cd > 0 then
                btn.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
                btn.Text = power.icon .. "\n" .. cd
                btn.TextSize = 14
                btn.Active = false
            else
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                btn.Text = power.icon
                btn.TextSize = 20
                btn.Active = true
            end
        end
        
        local activeCount = 0
        for _, cd in pairs(cooldowns) do
            if cd > 0 then activeCount = activeCount + 1 end
        end
        powerLabel.Text = "القوى: " .. (6 - activeCount) .. "/6 متاحة"
        powerCooldownLabel.Text = "التجديد: " .. activeCount .. " قوة في التبريد"
        
    elseif data.type == "Events" then
        local active = data.active or {}
        if #active > 0 then
            local ev = active[1]
            eventIconLabel.Text = ev.icon or "⚡"
            eventTextLabel.Text = ev.nameAr or ev.name .. " (" .. ev.turnsRemaining .. " أدوار)"
            eventNotifyFrame.Visible = true
            tweenObject(eventNotifyFrame, {BackgroundTransparency = 0}, 0.3)
            tweenObject(eventIconLabel, {TextTransparency = 0}, 0.3)
            tweenObject(eventTextLabel, {TextTransparency = 0}, 0.3)
            
            task.delay(4, function()
                tweenObject(eventNotifyFrame, {BackgroundTransparency = 1}, 0.3)
                tweenObject(eventIconLabel, {TextTransparency = 1}, 0.3)
                tweenObject(eventTextLabel, {TextTransparency = 1}, 0.3)
                task.wait(0.3)
                eventNotifyFrame.Visible = false
            end)
        end
    end
end)

TurnTimeout.OnClientEvent:Connect(function(team)
    if team == myTeam then
        turnTimerLabel.Text = "انتهى الوقت!"
        turnTimerLabel.TextColor3 = THEME.Danger
        task.wait(1)
        stopTurnTimer()
    end
end)

-- ============================================================
-- LOBBY BUTTONS
-- ============================================================
readyButton.MouseButton1Click:Connect(function()
    local isReady = readyButton.Text == "جاهز"
    SetReady:FireServer(isReady)
end)

startButton.MouseButton1Click:Connect(function()
    StartMatch:FireServer()
end)

for _, sz in ipairs(MapData.AvailableSizes) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 1, 0)
    btn.BackgroundColor3 = THEME.Surface
    btn.BorderSizePixel = 0
    btn.Text = tostring(sz) .. "×" .. tostring(sz)
    btn.TextColor3 = THEME.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = mapSizeButtons
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        SetMapSize:FireServer(sz)
        mapSizeLabel.Text = "حجم الخريطة: " .. tostring(sz) .. "×" .. tostring(sz)
    end)
end

-- ============================================================
-- COLOR BUTTONS
-- ============================================================
local function setupColorButtons(colors)
    for _, c in ipairs(colors) do
        local btn = Instance.new("TextButton")
        btn.Text = c
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.AutoButtonColor = false
        btn.Parent = colorFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(90, 90, 100)
        stroke.Thickness = 1
        stroke.Parent = btn
        
        btn.MouseEnter:Connect(function()
            tweenObject(btn, {BackgroundColor3 = Color3.fromRGB(90, 90, 100)}, 0.2)
        end)
        btn.MouseLeave:Connect(function()
            tweenObject(btn, {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}, 0.2)
        end)
        
        btn.MouseButton1Click:Connect(function()
            if isGameActive and currentTeam == myTeam then
                SelectColor:FireServer(c)
            end
        end)
    end
end

setupColorButtons(MapData.Colors or {"Red", "Blue", "Green", "Yellow", "Purple", "Orange"})

-- ============================================================
-- POWER BUTTONS
-- ============================================================
local function setupPowerButtons()
    local powers = {
        {name = "Scout", icon = "🔍"},
        {name = "Harvest", icon = "🌾"},
        {name = "Fortify", icon = "🛡️"},
        {name = "Sabotage", icon = "💣"},
        {name = "ColorShift", icon = "🎨"},
        {name = "Shockwave", icon = "💥"}
    }
    
    for _, power in ipairs(powers) do
        local btn = Instance.new("TextButton")
        btn.Name = "Power_" .. power.name
        btn.Text = power.icon
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 20
        btn.AutoButtonColor = false
        btn.Parent = powerFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(90, 90, 100)
        stroke.Thickness = 1
        stroke.Parent = btn
        
        btn.MouseEnter:Connect(function()
            tweenObject(btn, {BackgroundColor3 = Color3.fromRGB(90, 90, 100)}, 0.2)
        end)
        btn.MouseLeave:Connect(function()
            tweenObject(btn, {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}, 0.2)
        end)
        
        btn.MouseButton1Click:Connect(function()
            if isGameActive and currentTeam == myTeam then
                UsePower:FireServer(power.name)
            end
        end)
        
        powerButtons[power.name] = btn
    end
end

setupPowerButtons()

-- ============================================================
-- BOARD / BOTTOM BAR VISIBILITY
-- ============================================================
local function showMatchUI()
    lobbyPanel.Visible = false
    topHUD.Visible = true
    boardArea.Visible = true
    bottomBar.Visible = true
end

local function hideMatchUI()
    lobbyPanel.Visible = true
    topHUD.Visible = false
    boardArea.Visible = false
    bottomBar.Visible = false
end

-- Initial state: show lobby
hideMatchUI()

-- Join lobby automatically
JoinLobby:FireServer()

-- Close inspector
closeInspector.MouseButton1Click:Connect(hideInspector)