-- ServerScriptService/WorldBootstrap.server.lua
-- Creates the minimal playable 3D staging area for the generated RBXLX.
-- The actual strategy board is rendered by the client UI; this keeps the
-- character on a safe platform while the lobby/match UI is displayed.

local Workspace = game:GetService("Workspace")

local function ensurePart(name, size, position, material, transparency)
    local part = Workspace:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        return part
    end

    part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Anchored = true
    part.CanCollide = true
    part.Material = material or Enum.Material.SmoothPlastic
    part.Transparency = transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = Workspace
    return part
end

-- Safe platform under the player.
local baseplate = ensurePart(
    "LobbyPlatform",
    Vector3.new(128, 2, 128),
    Vector3.new(0, 0, 0),
    Enum.Material.SmoothPlastic,
    0
)
baseplate.Color = Color3.fromRGB(18, 22, 30)

-- Explicit spawn point so the player never falls into the void.
local spawn = Workspace:FindFirstChild("LobbySpawn")
if not spawn or not spawn:IsA("SpawnLocation") then
    if spawn then
        spawn:Destroy()
    end

    spawn = Instance.new("SpawnLocation")
    spawn.Name = "LobbySpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(0, 2, 0)
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Material = Enum.Material.Neon
    spawn.Color = Color3.fromRGB(0, 170, 255)
    spawn.Transparency = 0.15
    spawn.Parent = Workspace
end

-- Keep the default camera from spawning under the platform.
local camera = Workspace.CurrentCamera
if camera then
    camera.CFrame = CFrame.new(Vector3.new(0, 18, 28), Vector3.new(0, 2, 0))
end
