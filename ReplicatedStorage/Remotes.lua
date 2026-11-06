-- ReplicatedStorage/Remotes.lua (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "GameRemotes"
folder.Parent = ReplicatedStorage

-- Player actions
local selectColor = Instance.new("RemoteEvent")
selectColor.Name = "SelectColor"
selectColor.Parent = folder

local setMapSize = Instance.new("RemoteEvent")
setMapSize.Name = "SetMapSize"
setMapSize.Parent = folder

-- Server to client
local updateMap = Instance.new("RemoteEvent")
updateMap.Name = "UpdateMap"
updateMap.Parent = folder

local gameOver = Instance.new("RemoteEvent")
gameOver.Name = "GameOver"
gameOver.Parent = folder

local resourceUpdate = Instance.new("RemoteEvent")
resourceUpdate.Name = "ResourceUpdate"
resourceUpdate.Parent = folder

local visualEffect = Instance.new("RemoteEvent")
visualEffect.Name = "VisualEffect"
visualEffect.Parent = folder

-- M5: Powers and Events
local usePower = Instance.new("RemoteEvent")
usePower.Name = "UsePower"
usePower.Parent = folder

local eventNotify = Instance.new("RemoteEvent")
eventNotify.Name = "EventNotify"
eventNotify.Parent = folder

-- M6: Multiplayer
local joinLobby = Instance.new("RemoteEvent")
joinLobby.Name = "JoinLobby"
joinLobby.Parent = folder

local leaveLobby = Instance.new("RemoteEvent")
leaveLobby.Name = "LeaveLobby"
leaveLobby.Parent = folder

local setReady = Instance.new("RemoteEvent")
setReady.Name = "SetReady"
setReady.Parent = folder

local startMatch = Instance.new("RemoteEvent")
startMatch.Name = "StartMatch"
startMatch.Parent = folder

-- Server → Client: lobby & match state
local lobbyState = Instance.new("RemoteEvent")
lobbyState.Name = "LobbyState"
lobbyState.Parent = folder

local matchState = Instance.new("RemoteEvent")
matchState.Name = "MatchState"
matchState.Parent = folder

local turnTimeout = Instance.new("RemoteEvent")
turnTimeout.Name = "TurnTimeout"
turnTimeout.Parent = folder

-- For future multiplayer
local playerJoined = Instance.new("RemoteEvent")
playerJoined.Name = "PlayerJoined"
playerJoined.Parent = folder