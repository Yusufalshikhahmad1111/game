-- ServerScriptService/RemoteSetup.server.lua (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ensure GameRemotes folder exists
local remoteFolder = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remoteFolder then
    remoteFolder = Instance.new("Folder")
    remoteFolder.Name = "GameRemotes"
    remoteFolder.Parent = ReplicatedStorage
end

-- List of required RemoteEvents
local requiredRemotes = {
    "SelectColor",
    "SetMapSize",
    "UpdateMap",
    "GameOver",
    "ResourceUpdate",
    "VisualEffect"
}

for _, remoteName in ipairs(requiredRemotes) do
    if not remoteFolder:FindFirstChild(remoteName) then
        local remote = Instance.new("RemoteEvent")
        remote.Name = remoteName
        remote.Parent = remoteFolder
    end
end