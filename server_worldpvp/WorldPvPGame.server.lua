-- server_worldpvp/WorldPvPGame.server.lua
-- Roblox-native real-time World PvP runtime inspired by the broad RoWorld/OpenFront loop.
-- Original implementation; not copied from the Roblox game's private scripts/assets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldSeed = require(Shared.WorldPvP.WorldSeed)
local WorldState = require(Shared.WorldPvP.WorldState)

local REMOTES_NAME = "WorldPvPRemotes"
local remotes = ReplicatedStorage:FindFirstChild(REMOTES_NAME) or Instance.new("Folder")
remotes.Name = REMOTES_NAME
remotes.Parent = ReplicatedStorage

local function remote(name)
    local existing = remotes:FindFirstChild(name)
    if existing then return existing end
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = remotes
    return event
end

local SelectNation = remote("SelectNation")
local Attack = remote("Attack")
local Build = remote("Build")
local Nuke = remote("Nuke")
local AllianceOffer = remote("AllianceOffer")
local AllianceRespond = remote("AllianceRespond")
local RequestSnapshot = remote("RequestSnapshot")
local Snapshot = remote("Snapshot")
local Notice = remote("Notice")

local map, nationNames, seeds, colors = WorldSeed.create()
local state = WorldState.new(map)

for index, name in ipairs(nationNames) do
    local seed = seeds[index]
    local color = colors[((index - 1) % #colors) + 1]
    state:addNation(
        "N" .. index,
        name,
        { seed.id },
        { r = color[1], g = color[2], b = color[3] }
    )
end

local function publicSnapshot()
    return state:getSnapshot()
end

local function sendSnapshot(player)
    Snapshot:FireClient(player, publicSnapshot())
end

local function broadcast()
    local snapshot = publicSnapshot()
    for _, player in ipairs(Players:GetPlayers()) do
        Snapshot:FireClient(player, snapshot)
    end
end

local function notify(player, message, kind)
    Notice:FireClient(player, {
        message = message,
        kind = kind or "info",
    })
end

local function playerNationId(player)
    local nation = state:getNationForPlayer(player.UserId)
    return nation and nation.id or nil
end

SelectNation.OnServerEvent:Connect(function(player, nationId)
    local ok, result = state:assignPlayer(player.UserId, tostring(nationId))
    if not ok then
        notify(player, result, "error")
        return
    end

    notify(player, "تم اختيار " .. result.name .. ". ابدأ التوسع!", "success")
    broadcast()
end)

Attack.OnServerEvent:Connect(function(player, cellId, troopCount)
    local ok, result = state:attack(player.UserId, tostring(cellId), troopCount)
    if not ok then
        notify(player, result, "error")
        return
    end

    notify(player, "تم إطلاق الهجوم #" .. tostring(result), "success")
    broadcast()
end)

Build.OnServerEvent:Connect(function(player, cellId, buildingKind)
    local ok, result = state:build(player.UserId, tostring(cellId), tostring(buildingKind))
    if not ok then
        notify(player, result, "error")
        return
    end

    notify(player, "تم بناء " .. tostring(result.kind), "success")
    broadcast()
end)

Nuke.OnServerEvent:Connect(function(player, cellId)
    local ok, result = state:launchNuke(player.UserId, tostring(cellId))
    if not ok then
        notify(player, result, "error")
        return
    end

    notify(player, "تم إطلاق الضربة الاستراتيجية. الخريطة تضررت.", "warning")
    broadcast()
end)

AllianceOffer.OnServerEvent:Connect(function(player, targetUserId)
    local ok, err = state:proposeAlliance(player.UserId, tonumber(targetUserId))
    if not ok then
        notify(player, err, "error")
        return
    end
    notify(player, "تم إرسال عرض تحالف.", "success")
    broadcast()
end)

AllianceRespond.OnServerEvent:Connect(function(player, accept)
    local ok, err = state:respondAlliance(player.UserId, accept == true)
    if not ok then
        notify(player, err, "error")
        return
    end
    notify(player, accept and "تم قبول التحالف." or "تم رفض التحالف.", "success")
    broadcast()
end)

RequestSnapshot.OnServerEvent:Connect(function(player)
    sendSnapshot(player)
end)

Players.PlayerAdded:Connect(function(player)
    task.defer(function()
        sendSnapshot(player)
        notify(player, "اختر دولة غير محتلة من الخريطة.", "info")
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local nation = state:getNationForPlayer(player.UserId)
    if nation then
        nation.ownerUserId = nil
        nation.isAI = true
        state.playerNation[player.UserId] = nil
    end
end)

task.spawn(function()
    local last = os.clock()
    while true do
        task.wait(1)
        local now = os.clock()
        local dt = math.min(2, now - last)
        last = now

        if not state.matchOver then
            local events = state:tick(dt)
            if #events > 0 then
                broadcast()
            elseif #Players:GetPlayers() > 0 then
                broadcast()
            end
        end
    end
end)

print("[WorldPvP] Real-time world runtime initialized | 55-nation target")
