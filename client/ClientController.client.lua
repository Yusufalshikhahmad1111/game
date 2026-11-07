-- StarterPlayer/StarterPlayerScripts/ClientController.client.lua (LocalScript)
-- M8: Premium Visual Upgrade - Modern Strategy Game UI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
-- PREMIUM THEME & CONFIGURATION
-- ============================================================
local THEME = {
    -- Deep space dark theme
    Background    = Color3.fromRGB(10, 12, 18),
    Surface       = Color3.fromRGB(20, 24, 34),
    SurfaceElev   = Color3.fromRGB(30, 36, 50),
    SurfaceGlow   = Color3.fromRGB(40, 48, 66),
    Border        = Color3.fromRGB(60, 72, 96),
    BorderGlow    = Color3.fromRGB(0, 170, 255),
    TextPrimary   = Color3.new(1, 1, 1),
    TextSecondary = Color3.fromRGB(180, 190, 210),
    TextMuted     = Color3.fromRGB(120, 130, 150),
    Accent        = Color3.fromRGB(0, 170, 255),
    AccentGlow    = Color3.fromRGB(0, 200, 255),
    Success       = Color3.fromRGB(0, 255, 120),
    SuccessGlow   = Color3.fromRGB(60, 255, 140),
    Warning       = Color3.fromRGB(255, 180, 0),
    WarningGlow   = Color3.fromRGB(255, 200, 60),
    Danger        = Color3.fromRGB(255, 60, 60),
    DangerGlow    = Color3.fromRGB(255, 80, 80),
    Neutral       = Color3.fromRGB(120, 120, 120),
    Gold          = Color3.fromRGB(255, 215, 0),
    Food          = Color3.fromRGB(120, 200, 80),
    Wood          = Color3.fromRGB(160, 120, 60),
    Relic         = Color3.fromRGB(200, 100, 255)
}

local TEAM_COLORS = {
    Player = Color3.fromRGB(0, 170, 255),
    AI1    = Color3.fromRGB(255, 60, 60),
    AI2    = Color3.fromRGB(60, 255, 60),
    Neutral= Color3.fromRGB(100, 100, 100)
}

local TEAM_NAMES_AR = {
    Player = "اللاعب",
    AI1    = "الذكاء الاصطناعي 1",
    AI2    = "الذكاء الاصطناعي 2",
    Neutral= "محايد"
}

local TERRAIN_SYMBOLS = {
    Plains = "🌾",
    Forest = "🌲",
    Mine   = "⛏️",
    Ruins  = "🏛️",
    Fortress = "🏰",
    Capital = "🏛️",
    Harbor = "⚓"
}

local TERRAIN_NAMES_AR = {
    Plains = "سهل",
    Forest = "غابة",
    Mine   = "منجم",
    Ruins  = "آثار",
    Fortress = "حصن",
    Capital = "عاصمة",
    Harbor = "ميناء"
}

local POWER_DATA = {
    Scout      = {icon = "🔍", nameAr = "كشاف",   color = THEME.Accent},
    Harvest    = {icon = "🌾", nameAr = "حصاد",   color = THEME.Success},
    Fortify    = {icon = "🛡️", nameAr = "حصن",   color = THEME.Warning},
    Sabotage   = {icon = "💣", nameAr = "تخريب", color = THEME.Danger},
    ColorShift = {icon = "🎨", nameAr = "تحويل", color = THEME.Relic},
    Shockwave  = {icon = "💥", nameAr = "موجة",   color = Color3.fromRGB(255, 100, 50)}
}

-- ============================================================
-- STATE
-- ============================================================
local cellButtons     = {}
local selectedCellId  = nil
local isGameActive    = false
local currentTeam     = "Player"
local myTeam          = nil
local myResources     = {Gold = 0, Food = 0, Wood = 0, Relic = 0}
local turnStartTime   = nil
local turnTimeoutDuration = 30
local lobbyAnimConn   = nil

-- ============================================================
-- HELPERS
-- ============================================================
local function colorForOwner(owner)
    return TEAM_COLORS[owner] or THEME.Neutral
end

local function getDominionPercentage(data)
    if not data or #data == 0 then return 0 end
    local p = 0
    for _, c in ipairs(data) do
        if c.owner == myTeam then p = p + 1 end
    end
    return math.floor((p / #data) * 100)
end

local function tween(obj, props, duration, style, dir)
    duration = duration or 0.25
    style    = style    or Enum.EasingStyle.Quad
    dir      = dir      or Enum.EasingDirection.Out
    local t = TweenService:Create(obj, TweenInfo.new(duration, style, dir), props)
    t:Play()
    return t
end

local function ripple(btn)
    local ripple = Instance.new("Frame")
    ripple.Name = "Ripple"
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
    ripple.BackgroundColor3 = Color3.new(1, 1, 1)
    ripple.BackgroundTransparency = 0.7
    ripple.BorderSizePixel = 0
    ripple.ZIndex = btn.ZIndex + 1
    ripple.Parent = btn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = ripple

    tween(ripple, {Size = UDim2.new(2, 0, 2, 0), Position = UDim2.new(-0.5, 0, -0.5, 0), BackgroundTransparency = 1}, 0.4)
    task.delay(0.4, function() ripple:Destroy() end)
end

-- ============================================================
-- GUI ROOT
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "IslandDominionGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(1, 0, 1, 0)
main.Position = UDim2.new(0, 0, 0, 0)
main.BackgroundColor3 = THEME.Background
main.BorderSizePixel = 0
main.Parent = gui

-- Subtle animated background grid
local bgPattern = Instance.new("Frame")
bgPattern.Name = "BgPattern"
bgPattern.Size = UDim2.new(1, 0, 1, 0)
bgPattern.BackgroundTransparency = 1
bgPattern.Parent = main

local bgStroke = Instance.new("UIStroke")
bgStroke.Color = Color3.fromRGB(30, 36, 50)
bgStroke.Thickness = 1
bgStroke.Parent = bgPattern

-- ============================================================
-- LOBBY SCREEN
-- ============================================================
local lobby = Instance.new("Frame")
lobby.Name = "Lobby"
lobby.Size = UDim2.new(1, 0, 1, 0)
lobby.Position = UDim2.new(0, 0, 0, 0)
lobby.BackgroundColor3 = THEME.Surface
lobby.BorderSizePixel = 0
lobby.Visible = true
lobby.Parent = main

-- Lobby header
local lobbyHeader = Instance.new("Frame")
lobbyHeader.Name = "Header"
lobbyHeader.Size = UDim2.new(1, -40, 0, 90)
lobbyHeader.Position = UDim2.new(0, 20, 0, 20)
lobbyHeader.BackgroundTransparency = 1
lobbyHeader.Parent = lobby

local gameTitle = Instance.new("TextLabel")
gameTitle.Name = "Title"
gameTitle.Size = UDim2.new(0.6, 0, 1, 0)
gameTitle.BackgroundTransparency = 1
gameTitle.Text = "ISLAND DOMINION"
gameTitle.TextColor3 = THEME.TextPrimary
gameTitle.Font = Enum.Font.GothamBlack
gameTitle.TextSize = 34
gameTitle.TextXAlignment = Enum.TextXAlignment.Left
gameTitle.Parent = lobbyHeader

local gameSub = Instance.new("TextLabel")
gameSub.Name = "Subtitle"
gameSub.Size = UDim2.new(0.6, 0, 0, 24)
gameSub.Position = UDim2.new(0, 0, 0, 56)
gameSub.BackgroundTransparency = 1
gameSub.Text = "استراتيجية الأراضي -יברסية ثنائية الأبعاد"
gameSub.TextColor3 = THEME.TextSecondary
gameSub.Font = Enum.Font.Gotham
gameSub.TextSize = 16
gameSub.TextXAlignment = Enum.TextXAlignment.Left
gameSub.Parent = lobbyHeader

-- Lobby center card
local lobbyCard = Instance.new("Frame")
lobbyCard.Name = "Card"
lobbyCard.Size = UDim2.new(0, 420, 0, 460)
lobbyCard.Position = UDim2.new(0.5, -210, 0.5, -230)
lobbyCard.BackgroundColor3 = THEME.SurfaceElev
lobbyCard.BorderSizePixel = 0
lobbyCard.Parent = lobby

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = lobbyCard

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = THEME.Border
cardStroke.Thickness = 1.5
cardStroke.Parent = lobbyCard

local cardGlow = Instance.new("ImageLabel")
cardGlow.Name = "Glow"
cardGlow.Size = UDim2.new(1, 40, 1, 40)
cardGlow.Position = UDim2.new(0, -20, 0, -20)
cardGlow.BackgroundTransparency = 1
cardGlow.Image = "rbxassetid://5028857084" -- soft glow
cardGlow.ImageColor3 = Color3.fromRGB(0, 170, 255)
cardGlow.ImageTransparency = 0.8
cardGlow.ScaleType = Enum.ScaleType.Slice
cardGlow.SliceCenter = Rect.new(24, 24, 276, 276)
cardGlow.ZIndex = 0
cardGlow.Parent = lobbyCard

local cardTitle = Instance.new("TextLabel")
cardTitle.Name = "CardTitle"
cardTitle.Size = UDim2.new(1, -30, 0, 40)
cardTitle.Position = UDim2.new(0, 20, 0, 20)
cardTitle.BackgroundTransparency = 1
cardTitle.Text = "اللوبي"
cardTitle.TextColor3 = THEME.TextPrimary
cardTitle.Font = Enum.Font.GothamBold
cardTitle.TextSize = 22
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Parent = lobbyCard

-- Players list
local playersList = Instance.new("ScrollingFrame")
playersList.Name = "PlayersList"
playersList.Size = UDim2.new(1, -30, 0, 180)
playersList.Position = UDim2.new(0, 15, 0, 75)
playersList.BackgroundColor3 = THEME.Surface
playersList.BorderSizePixel = 0
playersList.ScrollBarThickness = 3
playersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
playersList.Parent = lobbyCard

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent = playersList

local listStroke = Instance.new("UIStroke")
listStroke.Color = THEME.Border
listStroke.Thickness = 1
listStroke.Parent = playersList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim2.new(0, 0, 0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = playersList

-- My team label
local myTeamLabel = Instance.new("TextLabel")
myTeamLabel.Name = "MyTeam"
myTeamLabel.Size = UDim2.new(1, -30, 0, 30)
myTeamLabel.Position = UDim2.new(0, 15, 0, 265)
myTeamLabel.BackgroundTransparency = 1
myTeamLabel.Text = "فريقك: غير محدد"
myTeamLabel.TextColor3 = THEME.TextSecondary
myTeamLabel.Font = Enum.Font.GothamBold
myTeamLabel.TextSize = 16
myTeamLabel.TextXAlignment = Enum.TextXAlignment.Left
myTeamLabel.Parent = lobbyCard

-- Map size selector
local sizeLabel = Instance.new("TextLabel")
sizeLabel.Name = "SizeLabel"
sizeLabel.Size = UDim2.new(1, -30, 0, 22)
sizeLabel.Position = UDim2.new(0, 15, 0, 305)
sizeLabel.BackgroundTransparency = 1
sizeLabel.Text = "حجم الخريطة"
sizeLabel.TextColor3 = THEME.TextMuted
sizeLabel.Font = Enum.Font.Gotham
sizeLabel.TextSize = 13
sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
sizeLabel.Parent = lobbyCard

local sizeRow = Instance.new("Frame")
sizeRow.Name = "SizeRow"
sizeRow.Size = UDim2.new(1, -30, 0, 36)
sizeRow.Position = UDim2.new(0, 15, 0, 330)
sizeRow.BackgroundTransparency = 1
sizeRow.Parent = lobbyCard

local sizeLayout = Instance.new("UIListLayout")
sizeLayout.FillDirection = Enum.FillDirection.Horizontal
sizeLayout.Padding = UDim2.new(0, 8, 0, 0)
sizeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
sizeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sizeLayout.Parent = sizeRow

-- Action buttons
local readyBtn = Instance.new("TextButton")
readyBtn.Name = "ReadyBtn"
readyBtn.Size = UDim2.new(0, 180, 0, 48)
readyBtn.Position = UDim2.new(0, 15, 0, 390)
readyBtn.BackgroundColor3 = THEME.Success
readyBtn.BorderSizePixel = 0
readyBtn.Text = "جاهز"
readyBtn.TextColor3 = Color3.new(1, 1, 1)
readyBtn.Font = Enum.Font.GothamBold
readyBtn.TextSize = 17
readyBtn.AutoButtonColor = false
readyBtn.Parent = lobbyCard

local readyCorner = Instance.new("UICorner")
readyCorner.CornerRadius = UDim.new(0, 12)
readyCorner.Parent = readyBtn

local readyStroke = Instance.new("UIStroke")
readyStroke.Color = THEME.Success
readyStroke.Thickness = 1
readyStroke.Parent = readyBtn

local startBtn = Instance.new("TextButton")
startBtn.Name = "StartBtn"
startBtn.Size = UDim2.new(0, 180, 0, 48)
startBtn.Position = UDim2.new(0, 220, 0, 390)
startBtn.BackgroundColor3 = THEME.Accent
startBtn.BorderSizePixel = 0
startBtn.Text = "ابدأ المباراة"
startBtn.TextColor3 = Color3.new(1, 1, 1)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 17
startBtn.AutoButtonColor = false
startBtn.Parent = lobbyCard

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 12)
startCorner.Parent = startBtn

local startStroke = Instance.new("UIStroke")
startStroke.Color = THEME.Accent
startStroke.Thickness = 1
startStroke.Parent = startBtn

-- ============================================================
-- MATCH HUD
-- ============================================================
local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.new(1, 0, 1, 0)
hud.Position = UDim2.new(0, 0, 0, 0)
hud.BackgroundTransparency = 1
hud.Visible = false
hud.Parent = main

-- Top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, -40, 0, 70)
topBar.Position = UDim2.new(0, 20, 0, 16)
topBar.BackgroundTransparency = 1
topBar.Parent = hud

local turnBox = Instance.new("Frame")
turnBox.Name = "TurnBox"
turnBox.Size = UDim2.new(0, 260, 1, 0)
turnBox.BackgroundTransparency = 1
turnBox.Parent = topBar

local turnBadge = Instance.new("TextLabel")
turnBadge.Name = "Badge"
turnBadge.Size = UDim2.new(0, 52, 0, 32)
turnBadge.Position = UDim2.new(0, 0, 0.5, -16)
turnBadge.BackgroundColor3 = THEME.Success
turnBadge.BorderSizePixel = 0
turnBadge.Text = "P"
turnBadge.TextColor3 = Color3.new(1,1,1)
turnBadge.Font = Enum.Font.GothamBold
turnBadge.TextSize = 16
turnBadge.Parent = turnBox

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 8)
badgeCorner.Parent = turnBadge

local turnText = Instance.new("TextLabel")
turnText.Name = "Text"
turnText.Size = UDim2.new(1, -70, 1, 0)
turnText.Position = UDim2.new(0, 62, 0, 0)
turnText.BackgroundTransparency = 1
turnText.Text = "دورك الآن"
turnText.TextColor3 = THEME.TextPrimary
turnText.Font = Enum.Font.GothamBold
turnText.TextSize = 18
turnText.TextXAlignment = Enum.TextXAlignment.Left
turnText.Parent = turnBox

local turnTimer = Instance.new("TextLabel")
turnTimer.Name = "Timer"
turnTimer.Size = UDim2.new(1, -70, 0, 20)
turnTimer.Position = UDim2.new(0, 62, 1, -20)
turnTimer.BackgroundTransparency = 1
turnTimer.Text = "الوقت المتبقي: 30s"
turnTimer.TextColor3 = THEME.TextMuted
turnTimer.Font = Enum.Font.Gotham
turnTimer.TextSize = 12
turnTimer.TextXAlignment = Enum.TextXAlignment.Left
turnTimer.Parent = turnBox

local resBox = Instance.new("Frame")
resBox.Name = "Resources"
resBox.Size = UDim2.new(0.38, 0, 1, 0)
resBox.Position = UDim2.new(0.31, 0, 0, 0)
resBox.BackgroundTransparency = 1
resBox.Parent = topBar

local resLabel = Instance.new("TextLabel")
resLabel.Name = "Label"
resLabel.Size = UDim2.new(1, 0, 0.5, 0)
resLabel.BackgroundTransparency = 1
resLabel.Text = "الموارد"
resLabel.TextColor3 = THEME.TextMuted
resLabel.Font = Enum.Font.Gotham
resLabel.TextSize = 13
resLabel.TextXAlignment = Enum.TextXAlignment.Center
resLabel.Parent = resBox

local resValue = Instance.new("TextLabel")
resValue.Name = "Value"
resValue.Size = UDim2.new(1, 0, 0.5, 0)
resValue.Position = UDim2.new(0, 0, 0.5, 0)
resValue.BackgroundTransparency = 1
resValue.Text = "🪙 0  |  🍖 0  |  🪵 0  |  🔮 0"
resValue.TextColor3 = THEME.TextPrimary
resValue.Font = Enum.Font.GothamBold
resValue.TextSize = 16
resValue.TextXAlignment = Enum.TextXAlignment.Center
resValue.Parent = resBox

local domBox = Instance.new("Frame")
domBox.Name = "Dominion"
domBox.Size = UDim2.new(0.3, 0, 1, 0)
domBox.Position = UDim2.new(0.7, 0, 0, 0)
domBox.BackgroundTransparency = 1
domBox.Parent = topBar

local domLabel = Instance.new("TextLabel")
domLabel.Name = "Label"
domLabel.Size = UDim2.new(1, 0, 0.5, 0)
domLabel.BackgroundTransparency = 1
domLabel.Text = "السيطرة"
domLabel.TextColor3 = THEME.TextMuted
domLabel.Font = Enum.Font.Gotham
domLabel.TextSize = 13
domLabel.TextXAlignment = Enum.TextXAlignment.Right
domLabel.Parent = domBox

local domValue = Instance.new("TextLabel")
domValue.Name = "Value"
domValue.Size = UDim2.new(1, 0, 0.5, 0)
domValue.Position = UDim2.new(0, 0, 0.5, 0)
domValue.BackgroundTransparency = 1
domValue.Text = "0%"
domValue.TextColor3 = THEME.TextPrimary
domValue.Font = Enum.Font.GothamBold
domValue.TextSize = 20
domValue.TextXAlignment = Enum.TextXAlignment.Right
domValue.Parent = domBox

-- Divider
local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Size = UDim2.new(1, -40, 0, 1)
divider.Position = UDim2.new(0, 20, 0, 96)
divider.BackgroundColor3 = THEME.Border
divider.BorderSizePixel = 0
divider.Parent = hud

-- Board area
local boardArea = Instance.new("Frame")
boardArea.Name = "BoardArea"
boardArea.Size = UDim2.new(1, 0, 1, -170)
boardArea.Position = UDim2.new(0, 0, 0, 100)
boardArea.BackgroundTransparency = 1
boardArea.Parent = hud

local gridContainer = Instance.new("Frame")
gridContainer.Name = "Grid"
gridContainer.Size = UDim2.new(0, 620, 0, 620)
gridContainer.Position = UDim2.new(0.5, -310, 0.5, -310)
gridContainer.BackgroundTransparency = 1
gridContainer.Parent = boardArea

local gridLayout = Instance.new("UIGridLayout")
gridLayout.Name = "Layout"
gridLayout.CellSize = UDim2.new(0, 52, 0, 52)
gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

-- Inspector panel (right side)
local inspector = Instance.new("Frame")
inspector.Name = "Inspector"
inspector.Size = UDim2.new(0, 320, 1, -120)
inspector.Position = UDim2.new(1, -320, 0, 90)
inspector.BackgroundColor3 = THEME.SurfaceElev
inspector.BorderSizePixel = 0
inspector.Visible = false
inspector.Parent = hud

local insCorner = Instance.new("UICorner")
insCorner.CornerRadius = UDim.new(0, 16)
insCorner.Parent = inspector

local insStroke = Instance.new("UIStroke")
insStroke.Color = THEME.Border
insStroke.Thickness = 1
insStroke.Parent = inspector

local insHeader = Instance.new("Frame")
insHeader.Name = "Header"
insHeader.Size = UDim2.new(1, 0, 0, 56)
insHeader.BackgroundTransparency = 1
insHeader.Parent = inspector

local insClose = Instance.new("TextButton")
insClose.Name = "Close"
insClose.Size = UDim2.new(0, 32, 0, 32)
insClose.Position = UDim2.new(1, -40, 0.5, -16)
insClose.BackgroundColor3 = THEME.Danger
insClose.BorderSizePixel = 0
insClose.Text = "✕"
insClose.TextColor3 = Color3.new(1,1,1)
insClose.Font = Enum.Font.GothamBold
insClose.TextSize = 18
insClose.AutoButtonColor = false
insClose.Parent = insHeader

local insCloseCorner = Instance.new("UICorner")
insCloseCorner.CornerRadius = UDim.new(0, 8)
insCloseCorner.Parent = insClose

local insTitle = Instance.new("TextLabel")
insTitle.Name = "Title"
insTitle.Size = UDim2.new(1, -70, 1, 0)
insTitle.BackgroundTransparency = 1
insTitle.Text = "تفاصيل الخلية"
insTitle.TextColor3 = THEME.TextPrimary
insTitle.Font = Enum.Font.GothamBold
insTitle.TextSize = 17
insTitle.TextXAlignment = Enum.TextXAlignment.Left
insTitle.Parent = insHeader

local insContent = Instance.new("ScrollingFrame")
insContent.Name = "Content"
insContent.Size = UDim2.new(1, -24, 1, -70)
insContent.Position = UDim2.new(0, 12, 0, 62)
insContent.BackgroundTransparency = 1
insContent.BorderSizePixel = 0
insContent.ScrollBarThickness = 3
insContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
insContent.Parent = inspector

local insLayout = Instance.new("UIListLayout")
insLayout.Padding = UDim2.new(0, 0, 0, 10)
insLayout.SortOrder = Enum.SortOrder.LayoutOrder
insLayout.Parent = insContent

-- Bottom bar
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, -40, 0, 64)
bottomBar.Position = UDim2.new(0, 20, 1, -80)
bottomBar.BackgroundColor3 = THEME.Surface
bottomBar.BorderSizePixel = 0
bottomBar.Visible = false
bottomBar.Parent = hud

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 16)
barCorner.Parent = bottomBar

local barStroke = Instance.new("UIStroke")
barStroke.Color = THEME.Border
barStroke.Thickness = 1
barStroke.Parent = bottomBar

local colorLabel = Instance.new("TextLabel")
colorLabel.Name = "ColorLabel"
colorLabel.Size = UDim2.new(0, 110, 1, 0)
colorLabel.BackgroundTransparency = 1
colorLabel.Text = "اختر لون:"
colorLabel.TextColor3 = THEME.TextSecondary
colorLabel.Font = Enum.Font.GothamBold
colorLabel.TextSize = 15
colorLabel.TextXAlignment = Enum.TextXAlignment.Left
colorLabel.Parent = bottomBar

local colorFrame = Instance.new("Frame")
colorFrame.Name = "Colors"
colorFrame.Size = UDim2.new(1, -440, 1, 0)
colorFrame.Position = UDim2.new(0, 130, 0, 0)
colorFrame.BackgroundTransparency = 1
colorFrame.Parent = bottomBar

local colorLayout = Instance.new("UIGridLayout")
colorLayout.Name = "Layout"
colorLayout.CellSize = UDim2.new(0, 56, 0, 44)
colorLayout.CellPadding = UDim2.new(0, 8, 0, 0)
colorLayout.FillDirection = Enum.FillDirection.Horizontal
colorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
colorLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colorLayout.Parent = colorFrame

local powerFrame = Instance.new("Frame")
powerFrame.Name = "Powers"
powerFrame.Size = UDim2.new(0, 220, 1, 0)
powerFrame.Position = UDim2.new(1, -220, 0, 0)
powerFrame.BackgroundTransparency = 1
powerFrame.Parent = bottomBar

local powerLayout = Instance.new("UIGridLayout")
powerLayout.Name = "Layout"
powerLayout.CellSize = UDim2.new(0, 52, 0, 44)
powerLayout.CellPadding = UDim2.new(0, 8, 0, 0)
powerLayout.FillDirection = Enum.FillDirection.Horizontal
powerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
powerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
powerLayout.Parent = powerFrame

local powerLabel = Instance.new("TextLabel")
powerLabel.Name = "Label"
powerLabel.Size = UDim2.new(0, 70, 1, 0)
powerLabel.BackgroundTransparency = 1
powerLabel.Text = "القوى:"
powerLabel.TextColor3 = THEME.TextSecondary
powerLabel.Font = Enum.Font.GothamBold
powerLabel.TextSize = 13
powerLabel.TextXAlignment = Enum.TextXAlignment.Left
powerLabel.Parent = bottomBar
powerLabel.Position = UDim2.new(1, -290, 0, 0)

-- ============================================================
-- OVERLAYS
-- ============================================================
-- Event notification
local eventBox = Instance.new("Frame")
eventBox.Name = "EventBox"
eventBox.Size = UDim2.new(0, 340, 0, 70)
eventBox.Position = UDim2.new(0.5, -170, 0, 30)
eventBox.BackgroundColor3 = THEME.SurfaceElev
eventBox.BorderSizePixel = 0
eventBox.Visible = false
eventBox.ZIndex = 50
eventBox.Parent = main

local eventCorner = Instance.new("UICorner")
eventCorner.CornerRadius = UDim.new(0, 12)
eventCorner.Parent = eventBox

local eventStroke = Instance.new("UIStroke")
eventStroke.Color = THEME.Accent
eventStroke.Thickness = 2
eventStroke.Parent = eventBox

local eventIcon = Instance.new("TextLabel")
eventIcon.Name = "Icon"
eventIcon.Size = UDim2.new(0, 44, 0, 44)
eventIcon.Position = UDim2.new(0, 14, 0.5, -22)
eventIcon.BackgroundTransparency = 1
eventIcon.Text = "☄️"
eventIcon.TextColor3 = THEME.TextPrimary
eventIcon.Font = Enum.Font.GothamBold
eventIcon.TextSize = 28
eventIcon.Parent = eventBox

local eventText = Instance.new("TextLabel")
eventText.Name = "Text"
eventText.Size = UDim2.new(1, -70, 1, 0)
eventText.Position = UDim2.new(0, 66, 0, 0)
eventText.BackgroundTransparency = 1
eventText.Text = "حدث عالمي نشط!"
eventText.TextColor3 = THEME.TextPrimary
eventText.Font = Enum.Font.GothamBold
eventText.TextSize = 17
eventText.TextXAlignment = Enum.TextXAlignment.Left
eventText.Parent = eventBox

-- Game over overlay
local gameOverBox = Instance.new("Frame")
gameOverBox.Name = "GameOver"
gameOverBox.Size = UDim2.new(1, 0, 1, 0)
gameOverBox.Position = UDim2.new(0, 0, 0, 0)
gameOverBox.BackgroundColor3 = Color3.new(0, 0, 0)
gameOverBox.BackgroundTransparency = 0.55
gameOverBox.Visible = false
gameOverBox.ZIndex = 100
gameOverBox.Parent = main

local goCard = Instance.new("Frame")
goCard.Name = "Card"
goCard.Size = UDim2.new(0, 420, 0, 260)
goCard.Position = UDim2.new(0.5, -210, 0.5, -130)
goCard.BackgroundColor3 = THEME.SurfaceElev
goCard.BorderSizePixel = 0
goCard.Parent = gameOverBox

local goCorner = Instance.new("UICorner")
goCorner.CornerRadius = UDim.new(0, 20)
goCorner.Parent = goCard

local goStroke = Instance.new("UIStroke")
goStroke.Color = THEME.Border
goStroke.Thickness = 2
goStroke.Parent = goCard

local goIcon = Instance.new("TextLabel")
goIcon.Name = "Icon"
goIcon.Size = UDim2.new(1, 0, 0, 80)
goIcon.BackgroundTransparency = 1
goIcon.Text = "🏆"
goIcon.TextColor3 = THEME.Gold
goIcon.Font = Enum.Font.GothamBold
goIcon.TextSize = 60
goIcon.Parent = goCard

local goTitle = Instance.new("TextLabel")
goTitle.Name = "Title"
goTitle.Size = UDim2.new(1, 0, 0, 32)
goTitle.Position = UDim2.new(0, 0, 0, 86)
goTitle.BackgroundTransparency = 1
goTitle.Text = "انتهت المباراة!"
goTitle.TextColor3 = THEME.TextPrimary
goTitle.Font = Enum.Font.GothamBold
goTitle.TextSize = 26
goTitle.TextXAlignment = Enum.TextXAlignment.Center
goTitle.Parent = goCard

local goWinner = Instance.new("TextLabel")
goWinner.Name = "Winner"
goWinner.Size = UDim2.new(1, 0, 0, 28)
goWinner.Position = UDim2.new(0, 0, 0, 120)
goWinner.BackgroundTransparency = 1
goWinner.Text = "الفائز: Player"
goWinner.TextColor3 = THEME.Success
goWinner.Font = Enum.Font.GothamBold
goWinner.TextSize = 20
goWinner.TextXAlignment = Enum.TextXAlignment.Center
goWinner.Parent = goCard

local goBtn = Instance.new("TextButton")
goBtn.Name = "Restart"
goBtn.Size = UDim2.new(0, 200, 0, 48)
goBtn.Position = UDim2.new(0.5, -100, 0, 170)
goBtn.BackgroundColor3 = THEME.Accent
goBtn.BorderSizePixel = 0
goBtn.Text = "العب مرة أخرى"
goBtn.TextColor3 = Color3.new(1, 1, 1)
goBtn.Font = Enum.Font.GothamBold
goBtn.TextSize = 17
goBtn.AutoButtonColor = false
goBtn.Parent = goCard

local goBtnCorner = Instance.new("UICorner")
goBtnCorner.CornerRadius = UDim.new(0, 12)
goBtnCorner.Parent = goBtn

local goBtnStroke = Instance.new("UIStroke")
goBtnStroke.Color = THEME.Accent
goBtnStroke.Thickness = 1
goBtnStroke.Parent = goBtn

-- ============================================================
-- UI STATE
-- ============================================================
local powerButtons = {}
local cellSize = 52
local mapGridSize = 10

-- ============================================================
-- UI FUNCTIONS
-- ============================================================
local function setBtnHover(btn, normalColor, hoverColor)
    btn.MouseEnter:Connect(function()
        tween(btn, {BackgroundColor3 = hoverColor}, 0.2)
        ripple(btn)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, {BackgroundColor3 = normalColor}, 0.2)
    end)
end

local function updateLobbyUI(data)
    -- Clear list
    for _, c in ipairs(playersList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    for _, pInfo in ipairs(data.players) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 40)
        row.BackgroundColor3 = THEME.Surface
        row.BorderSizePixel = 0
        row.Parent = playersList

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 10)
        rc.Parent = row

        local rs = Instance.new("UIStroke")
        rs.Color = THEME.Border
        rs.Thickness = 1
        rs.Parent = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 12, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = pInfo.playerName
        nameLbl.TextColor3 = THEME.TextPrimary
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 14
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row

        local teamLbl = Instance.new("TextLabel")
        teamLbl.Size = UDim2.new(0.25, 0, 1, 0)
        teamLbl.Position = UDim2.new(0.55, 0, 0, 0)
        teamLbl.BackgroundTransparency = 1
        teamLbl.Text = pInfo.team
        teamLbl.TextColor3 = colorForOwner(pInfo.team)
        teamLbl.Font = Enum.Font.GothamBold
        teamLbl.TextSize = 12
        teamLbl.TextXAlignment = Enum.TextXAlignment.Center
        teamLbl.Parent = row

        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(0.2, 0, 1, 0)
        statusLbl.Position = UDim2.new(0.8, 0, 0, 0)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = pInfo.ready and "جاهز" or "غير جاهز"
        statusLbl.TextColor3 = pInfo.ready and THEME.Success or THEME.Warning
        statusLbl.Font = Enum.Font.Gotham
        statusLbl.TextSize = 11
        statusLbl.TextXAlignment = Enum.TextXAlignment.Right
        statusLbl.Parent = row
    end

    -- My team
    local myInfo = nil
    for _, pInfo in ipairs(data.players) do
        if pInfo.userId == player.UserId then myInfo = pInfo break end
    end

    if myInfo then
        myTeam = myInfo.team
        myTeamLabel.Text = "فريقك: " .. (TEAM_NAMES_AR[myTeam] or myTeam)
        myTeamLabel.TextColor3 = colorForOwner(myTeam)
        readyBtn.Visible = true
        startBtn.Visible = (#data.players >= 1 and data.canStart)
        readyBtn.Text = myInfo.ready and "إلغاء جاهزية" or "جاهز"
        readyBtn.BackgroundColor3 = myInfo.ready and THEME.Warning or THEME.Success
        readyStroke.Color = readyBtn.BackgroundColor3
    else
        myTeam = nil
        myTeamLabel.Text = "فريقك: غير محدد"
        myTeamLabel.TextColor3 = THEME.TextSecondary
        readyBtn.Visible = false
        startBtn.Visible = false
    end
end

local function setupSizeButtons()
    for _, c in ipairs(sizeRow:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, sz in ipairs(MapData.AvailableSizes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 88, 0, 34)
        btn.BackgroundColor3 = THEME.Surface
        btn.BorderSizePixel = 0
        btn.Text = tostring(sz) .. "×" .. tostring(sz)
        btn.TextColor3 = THEME.TextPrimary
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.AutoButtonColor = false
        btn.Parent = sizeRow

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 10)
        bc.Parent = btn

        local bs = Instance.new("UIStroke")
        bs.Color = THEME.Border
        bs.Thickness = 1
        bs.Parent = btn

        setBtnHover(btn, THEME.Surface, THEME.SurfaceGlow)

        btn.MouseButton1Click:Connect(function()
            SetMapSize:FireServer(sz)
            sizeLabel.Text = "حجم الخريطة: " .. sz .. "×" .. sz
            for _, b in ipairs(sizeRow:GetChildren()) do
                if b:IsA("TextButton") then
                    tween(b, {BackgroundColor3 = THEME.Surface}, 0.2)
                    b.UIStroke.Color = THEME.Border
                end
            end
            tween(btn, {BackgroundColor3 = THEME.Accent}, 0.2)
            btn.UIStroke.Color = THEME.Accent
        end)
    end
end

setupSizeButtons()

local function buildMap(data)
    local newSize = math.sqrt(#data)
    local newCell = math.clamp(600 / newSize, 24, 60)

    if newSize ~= mapGridSize then
        mapGridSize = newSize
        cellSize = newCell
        gridLayout.CellSize = UDim2.new(0, cellSize, 0, cellSize)
        local total = cellSize * mapGridSize + 4 * (mapGridSize - 1)
        gridContainer.Size = UDim2.new(0, total, 0, total)
        gridContainer.Position = UDim2.new(0.5, -total / 2, 0.5, -total / 2)
    end

    local pct = getDominionPercentage(data)
    domValue.Text = pct .. "%"

    for _, cell in ipairs(data) do
        local btn = cellButtons[cell.id]

        if not btn then
            btn = Instance.new("TextButton")
            btn.Name = cell.id
            btn.Size = UDim2.new(0, cellSize, 0, cellSize)
            btn.BackgroundColor3 = colorForOwner(cell.owner)
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = math.clamp(16, 10, 20)
            btn.Text = TERRAIN_SYMBOLS[cell.terrainType] or "?"
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Parent = gridContainer

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 10)
            c.Parent = btn

            local s = Instance.new("UIStroke")
            s.Color = THEME.Border
            s.Thickness = 1.5
            s.Parent = btn

            cellButtons[cell.id] = btn
            btn:SetAttribute("Owner", cell.owner)
            btn:SetAttribute("Terrain", cell.terrainType or "Plains")

            btn.MouseEnter:Connect(function()
                if btn:GetAttribute("Owner") ~= myTeam then
                    tween(btn, {BackgroundColor3 = colorForOwner(cell.owner):Lerp(Color3.new(1,1,1), 0.25)}, 0.15)
                end
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundColor3 = colorForOwner(cell.owner)}, 0.15)
            end)
            btn.MouseButton1Click:Connect(function()
                showInspector(cell)
            end)
        else
            local prevOwner = btn:GetAttribute("Owner")
            local prevTerrain = btn:GetAttribute("Terrain")

            if prevOwner ~= cell.owner then
                -- Capture flash
                local flash = colorForOwner(cell.owner)
                tween(btn, {BackgroundColor3 = flash}, 0.05)
                task.delay(0.05, function()
                    if btn and btn.Parent then
                        tween(btn, {BackgroundColor3 = colorForOwner(cell.owner)}, 0.2)
                    end
                end)
                btn:SetAttribute("Owner", cell.owner)
            end

            if prevTerrain ~= (cell.terrainType or "Plains") then
                btn.Text = TERRAIN_SYMBOLS[cell.terrainType] or "?"
                btn:SetAttribute("Terrain", cell.terrainType or "Plains")
            end
        end
    end
end

local function showInspector(cellData)
    if not cellData then return end
    selectedCellId = cellData.id

    local owner = cellData.owner or "Neutral"
    local terrain = cellData.terrainType or "Plains"
    local tName = TERRAIN_NAMES_AR[terrain] or terrain
    local symbol = TERRAIN_SYMBOLS[terrain] or "?"

    insTitle.Text = symbol .. "  " .. tName

    for _, c in ipairs(insContent:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    local function addRow(label, value, vColor)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundTransparency = 1
        row.Parent = insContent

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.45, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = THEME.TextMuted
        l.Font = Enum.Font.Gotham
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0.55, 0, 1, 0)
        v.Position = UDim2.new(0.45, 0, 0, 0)
        v.BackgroundTransparency = 1
        v.Text = value
        v.TextColor3 = vColor or THEME.TextPrimary
        v.Font = Enum.Font.GothamBold
        v.TextSize = 13
        v.TextXAlignment = Enum.TextXAlignment.Right
        v.Parent = row
    end

    addRow("المالك:", owner, colorForOwner(owner))
    addRow("نوع الأرضية:", tName, THEME.Accent)
    addRow("القيمة الاستراتيجية:", tostring(cellData.strategicValue or 1), THEME.TextPrimary)

    local defPct = math.floor((cellData.defenseModifier or 0) * 100)
    addRow("معدل الدفاع:", defPct .. "%", defPct > 0 and THEME.Success or THEME.TextMuted)

    local prod = cellData.productionPerTurn or {}
    local prodStr = ""
    for rt, amt in pairs(prod) do
        if prodStr ~= "" then prodStr = prodStr .. "  |  " end
        local icons = {Gold="🪙", Food="🍖", Wood="🪵", Relic="🔮"}
        local ico = icons[rt] or ""
        prodStr = prodStr .. ico .. rt .. " +" .. amt
    end
    if prodStr ~= "" then
        addRow("الإنتاج لكل دور:", prodStr, THEME.Success)
    end

    local by = cellData.baseYield or {}
    local byStr = ""
    for rt, amt in pairs(by) do
        if byStr ~= "" then byStr = byStr .. "  |  " end
        local ico = {Gold="🪙", Food="🍖", Wood="🪵", Relic="🔮"}[rt] or ""
        byStr = byStr .. ico .. rt .. " +" .. amt
    end
    if byStr ~= "" then
        addRow("مكافأة الاحتجاز:", byStr, THEME.Warning)
    end

    inspector.Visible = true
    inspector.Position = UDim2.new(1, 0, 0, 90)
    tween(inspector, {Position = UDim2.new(1, -320, 0, 90)}, 0.3)
end

local function hideInspector()
    if not selectedCellId then return end
    tween(inspector, {Position = UDim2.new(1, 0, 0, 90)}, 0.3)
    task.delay(0.3, function()
        if inspector and inspector.Position == UDim2.new(1, 0, 0, 90) then
            inspector.Visible = false
        end
    end)
    selectedCellId = nil
end

local function updateResources(res)
    myResources = res or {Gold=0, Food=0, Wood=0, Relic=0}
    resValue.Text = string.format(
        "🪙 %d   🍖 %d   🪵 %d   🔮 %d",
        myResources.Gold or 0,
        myResources.Food or 0,
        myResources.Wood or 0,
        myResources.Relic or 0
    )
end

local function playCaptureEffect(cellIds, colorName)
    local flashMap = {
        Red    = Color3.fromRGB(255, 60, 60),
        Blue   = Color3.fromRGB(60, 60, 255),
        Green  = Color3.fromRGB(60, 255, 60),
        Yellow = Color3.fromRGB(255, 235, 60),
        Purple = Color3.fromRGB(180, 60, 255),
        Orange = Color3.fromRGB(255, 140, 0)
    }
    local flash = flashMap[colorName] or Color3.new(1,1,1)

    for _, id in ipairs(cellIds) do
        local btn = cellButtons[id]
        if btn then
            local orig = btn.BackgroundColor3
            tween(btn, {BackgroundColor3 = flash}, 0.08)
            task.delay(0.08, function()
                if btn and btn.Parent then
                    tween(btn, {BackgroundColor3 = orig}, 0.15)
                end
            end)
        end
    end
end

-- Turn timer
local function updateTurnTimer()
    if not turnStartTime then return end
    local elapsed = tick() - turnStartTime
    local rem = math.max(0, turnTimeoutDuration - elapsed)
    turnTimer.Text = string.format("الوقت المتبقي: %ds", math.ceil(rem))
    if rem <= 5 then
        turnTimer.TextColor3 = THEME.Danger
    else
        turnTimer.TextColor3 = THEME.TextMuted
    end
end

local function startTurnTimer()
    turnStartTime = tick()
    task.spawn(function()
        while turnStartTime do
            updateTurnTimer()
            task.wait(0.5)
        end
    end)
end

local function stopTurnTimer()
    turnStartTime = nil
    turnTimer.Text = "الوقت المتبقي: --"
    turnTimer.TextColor3 = THEME.TextMuted
end

-- ============================================================
-- EVENTS
-- ============================================================
LobbyState.OnClientEvent:Connect(function(data)
    updateLobbyUI(data)
end)

UpdateMap.OnClientEvent:Connect(function(data, team, active)
    currentTeam = team or "Player"
    isGameActive = active

    buildMap(data)

    turnBadge.Text = currentTeam == "Player" and "P" or (currentTeam == "AI1" and "A1" or "A2")
    turnBadge.BackgroundColor3 = colorForOwner(currentTeam)

    local isMy = (currentTeam == myTeam)
    turnText.Text = isMy and "دورك الآن" or "دور الخصم: " .. (TEAM_NAMES_AR[currentTeam] or currentTeam)
    turnText.TextColor3 = isMy and THEME.Success or THEME.Warning

    if active then
        if isMy then startTurnTimer() else stopTurnTimer() end
    else
        turnText.Text = "انتهت المباراة!"
        turnText.TextColor3 = THEME.Danger
        stopTurnTimer()
    end
end)

GameOver.OnClientEvent:Connect(function(winner)
    isGameActive = false
    stopTurnTimer()
    goWinner.Text = "الفائز: " .. winner
    goWinner.TextColor3 = (winner == myTeam) and THEME.Success or THEME.Danger
    goIcon.Text = (winner == myTeam) and "🏆" or "💀"
    goIcon.TextColor3 = (winner == myTeam) and THEME.Success or THEME.Danger

    gameOverBox.Visible = true
    gameOverBox.BackgroundTransparency = 1
    tween(gameOverBox, {BackgroundTransparency = 0.55}, 0.4)
    goCard.Position = UDim2.new(0.5, -210, 0.5, -50)
    tween(goCard, {Position = UDim2.new(0.5, -210, 0.5, -130)}, 0.4, Enum.EasingStyle.Back)
end)

ResourceUpdate.OnClientEvent:Connect(function(res)
    updateResources(res)
end)

VisualEffect.OnClientEvent:Connect(function(cellIds, colorName)
    playCaptureEffect(cellIds, colorName)
end)

EventNotify.OnClientEvent:Connect(function(data)
    if data.type == "PowerState" then
        local cds = data.cooldowns or {}
        local powers = data.powers or {}

        for pName, btn in pairs(powerButtons) do
            local cd = cds[pName] or 0
            local p = powers[pName]

            if cd > 0 then
                btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
                btn.Text = p.icon .. "\n" .. cd
                btn.TextSize = 12
                btn.Active = false
            else
                btn.BackgroundColor3 = p.color or THEME.Accent
                btn.Text = p.icon
                btn.TextSize = 20
                btn.Active = true
            end
        end

        local activeCount = 0
        for _, cd in pairs(cds) do if cd > 0 then activeCount = activeCount + 1 end end

        local teamEffects = data.teamEffects or {}
        local myEff = teamEffects[myTeam] or {}
        if #myEff > 0 then
            local names = {}
            for _, e in ipairs(myEff) do table.insert(names, e.power .. "(" .. e.turnsRemaining .. ")") end
            -- Could show in a small label, keep simple
        end
    elseif data.type == "Events" then
        local act = data.active or {}
        if #act > 0 then
            local ev = act[1]
            eventIcon.Text = ev.icon or "⚡"
            eventText.Text = (ev.nameAr or ev.name) .. " (" .. ev.turnsRemaining .. " أدوار)"
            eventBox.Visible = true
            eventBox.BackgroundTransparency = 1
            eventBox.Position = UDim2.new(0.5, -170, 0, -80)
            tween(eventBox, {BackgroundTransparency = 0, Position = UDim2.new(0.5, -170, 0, 30)}, 0.3)
            tween(eventIcon, {TextTransparency = 0}, 0.3)
            tween(eventText, {TextTransparency = 0}, 0.3)

            task.delay(4, function()
                tween(eventBox, {BackgroundTransparency = 1, Position = UDim2.new(0.5, -170, 0, -80)}, 0.3)
                tween(eventIcon, {TextTransparency = 1}, 0.3)
                tween(eventText, {TextTransparency = 1}, 0.3)
                task.wait(0.3)
                eventBox.Visible = false
            end)
        end
    end
end)

TurnTimeout.OnClientEvent:Connect(function(team)
    if team == myTeam then
        turnTimer.Text = "انتهى الوقت!"
        turnTimer.TextColor3 = THEME.Danger
        task.wait(1)
        stopTurnTimer()
    end
end)

-- ============================================================
-- BUTTONS
-- ============================================================
readyBtn.MouseButton1Click:Connect(function()
    local isReady = readyBtn.Text == "جاهز"
    SetReady:FireServer(isReady)
end)

startBtn.MouseButton1Click:Connect(function()
    StartMatch:FireServer()
end)

insClose.MouseButton1Click:Connect(hideInspector)

goBtn.MouseButton1Click:Connect(function()
    gameOverBox.Visible = false
    tween(gameOverBox, {BackgroundTransparency = 1}, 0.3)
end)

-- Color buttons
local function setupColorButtons(colors)
    for _, c in ipairs(colors) do
        local btn = Instance.new("TextButton")
        btn.Text = c
        btn.BackgroundColor3 = THEME.Surface
        btn.BorderSizePixel = 0
        btn.TextColor3 = THEME.TextPrimary
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.AutoButtonColor = false
        btn.Parent = colorFrame

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 12)
        cCorner.Parent = btn

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = THEME.Border
        cStroke.Thickness = 1.5
        cStroke.Parent = btn

        setBtnHover(btn, THEME.Surface, THEME.SurfaceGlow)

        btn.MouseButton1Click:Connect(function()
            if isGameActive and currentTeam == myTeam then
                SelectColor:FireServer(c)
                ripple(btn)
            end
        end)
    end
end

setupColorButtons(MapData.Colors or {"Red","Blue","Green","Yellow","Purple","Orange"})

-- Power buttons
local function setupPowerButtons()
    for _, p in ipairs({
        {name="Scout", icon="🔍"}, {name="Harvest", icon="🌾"},
        {name="Fortify", icon="🛡️"}, {name="Sabotage", icon="💣"},
        {name="ColorShift", icon="🎨"}, {name="Shockwave", icon="💥"}
    }) do
        local btn = Instance.new("TextButton")
        btn.Name = "Power_" .. p.name
        btn.Text = p.icon
        btn.BackgroundColor3 = POWER_DATA[p.name].color
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 20
        btn.AutoButtonColor = false
        btn.Parent = powerFrame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12)
        c.Parent = btn

        local s = Instance.new("UIStroke")
        s.Color = Color3.new(1,1,1)
        s.Thickness = 1
        s.Transparency = 0.6
        s.Parent = btn

        setBtnHover(btn, POWER_DATA[p.name].color, POWER_DATA[p.name].color:Lerp(Color3.new(1,1,1), 0.15))

        btn.MouseButton1Click:Connect(function()
            if isGameActive and currentTeam == myTeam then
                UsePower:FireServer(p.name, nil)
                ripple(btn)
            end
        end)

        powerButtons[p.name] = btn
    end
end

setupPowerButtons()

-- ============================================================
-- INIT
-- ============================================================
JoinLobby:FireServer()
hideInspector()

-- Initial visual pulse on lobby card
lobbyCard.Size = UDim2.new(0, 400, 0, 420)
lobbyCard.Position = UDim2.new(0.5, -200, 0.5, -210)
tween(lobbyCard, {Size = UDim2.new(0, 420, 0, 460), Position = UDim2.new(0.5, -210, 0.5, -230)}, 0.6, Enum.EasingStyle.Back)