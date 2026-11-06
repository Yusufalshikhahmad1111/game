-- ServerScriptService/GameManager.lua (Script)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SelectColor = Remotes:WaitForChild("SelectColor")
local SetMapSize = Remotes:WaitForChild("SetMapSize")
local UpdateMap = Remotes:WaitForChild("UpdateMap")
local GameOver = Remotes:WaitForChild("GameOver")
local ResourceUpdate = Remotes:WaitForChild("ResourceUpdate")
local VisualEffect = Remotes:WaitForChild("VisualEffect")

local MapData = require(ReplicatedStorage:WaitForChild("MapData"))

local grid = MapData.GenerateMap(MapData.DefaultGridSize)
local gridSize = MapData.DefaultGridSize

local turnOrder = {"Player", "AI1", "AI2"}
local currentTurnIndex = 1
local gameActive = true

-- Resources per team
local teamResources = {
    Player = {Gold = 0, Food = 0, Wood = 0},
    AI1    = {Gold = 0, Food = 0, Wood = 0},
    AI2    = {Gold = 0, Food = 0, Wood = 0}
}

local teamColors = {
    Player = Color3.fromRGB(0, 120, 255),
    AI1 = Color3.fromRGB(255, 50, 50),
    AI2 = Color3.fromRGB(50, 255, 50),
    Neutral = Color3.fromRGB(120, 120, 120)
}

-- Serialize grid for client (exclude heavy neighbor tables)
local function serializeGrid()
    local data = {}
    for x = 1, gridSize do
        for y = 1, gridSize do
            local c = grid[x][y]
            table.insert(data, {
                id = c.id,
                x = c.x,
                y = c.y,
                owner = c.owner,
                color = c.color,
                resources = c.resources,   -- send resource table
                totalResources = c.totalResources
            })
        end
    end
    return data
end

local function broadcastMap()
    UpdateMap:FireAllClients(serializeGrid(), turnOrder[currentTurnIndex], gameActive)
end

local function broadcastResources()
    ResourceUpdate:FireAllClients(teamResources)
end

local function captureCells(team, chosenColor)
    local toCapture = {}
    for x = 1, gridSize do
        for y = 1, gridSize do
            local cell = grid[x][y]
            if cell.owner == team then
                for _, nb in ipairs(cell.neighbors) do
                    if nb.owner ~= team and nb.color == chosenColor then
                        table.insert(toCapture, nb)
                    end
                end
            end
        end
    end

    -- Remove duplicates
    local unique, seen = {}, {}
    for _, cell in ipairs(toCapture) do
        if not seen[cell.id] then
            seen[cell.id] = true
            table.insert(unique, cell)
        end
    end

    -- Apply capture and gather resources
    local capturedResources = {Gold = 0, Food = 0, Wood = 0}
    for _, cell in ipairs(unique) do
        cell.owner = team
        -- Add cell resources to team
        for resType, amount in pairs(cell.resources) do
            teamResources[team][resType] = teamResources[team][resType] + amount
            capturedResources[resType] = capturedResources[resType] + amount
        end
    end

    -- Trigger visual effect for captured cells
    if #unique > 0 then
        local cellIds = {}
        for _, cell in ipairs(unique) do
            table.insert(cellIds, cell.id)
        end
        VisualEffect:FireAllClients(cellIds, chosenColor)
    end

    return unique, capturedResources
end

local function checkWin()
    local owner = grid[1][1].owner
    if owner == "Neutral" then return false end
    for x = 1, gridSize do
        for y = 1, gridSize do
            if grid[x][y].owner ~= owner then
                return false
            end
        end
    end
    return true, owner
end

local function endTurn()
    if not gameActive then return end
    currentTurnIndex = currentTurnIndex % #turnOrder + 1
    broadcastMap()
    broadcastResources()

    local team = turnOrder[currentTurnIndex]
    if team ~= "Player" then
        task.wait(1.2)  -- slight delay for AI turn
        AITurn(team)
    end
end

-- Improved AI: one-step lookahead scoring = captured cells + resources gained
function AITurn(team)
    if not gameActive then return end

    local bestColor, bestScore = nil, -1
    local bestCaptureCount = 0

    for _, color in ipairs(MapData.Colors) do
        -- Simulate capture
        local simulatedGrid = {}
        for x = 1, gridSize do
            for y = 1, gridSize do
                simulatedGrid[x] = simulatedGrid[x] or {}
                simulatedGrid[x][y] = {
                    owner = grid[x][y].owner,
                    color = grid[x][y].color,
                    resources = grid[x][y].resources,
                    neighbors = grid[x][y].neighbors
                }
            end
        end

        local captured = 0
        local gainedResources = {Gold = 0, Food = 0, Wood = 0}
        for x = 1, gridSize do
            for y = 1, gridSize do
                local cell = simulatedGrid[x][y]
                if cell.owner == team then
                    for _, nb in ipairs(cell.neighbors) do
                        if nb.owner ~= team and nb.color == color then
                            -- capture nb
                            nb.owner = team
                            captured = captured + 1
                            for resType, amount in pairs(nb.resources) do
                                gainedResources[resType] = gainedResources[resType] + amount
                            end
                        end
                    end
                end
            end
        end

        -- Score: weight cells more than resources (adjustable)
        local score = captured * 2 + (gainedResources.Gold + gainedResources.Food + gainedResources.Wood) * 0.1
        if score > bestScore then
            bestScore = score
            bestColor = color
            bestCaptureCount = captured
        end
    end

    if bestColor then
        captureCells(team, bestColor)  -- actual capture updates resources & visuals
    end

    local won, winner = checkWin()
    if won then
        gameActive = false
        GameOver:FireAllClients(winner)
        return
    end
    endTurn()
end

SelectColor.OnServerEvent:Connect(function(_player, colorName)
    if not gameActive then return end
    if turnOrder[currentTurnIndex] ~= "Player" then return end

    local captured, res = captureCells("Player", colorName)
    -- resources already added inside captureCells

    local won, winner = checkWin()
    if won then
        gameActive = false
        GameOver:FireAllClients(winner)
        return
    end
    endTurn()
end)

SetMapSize.OnServerEvent:Connect(function(_player, size)
    if not gameActive then return end
    -- Only allow changing map size before game starts or between games; here we reset.
    gridSize = tonumber(size) or MapData.DefaultGridSize
    grid = MapData.GenerateMap(gridSize)
    -- Reset resources
    for t, _ in pairs(teamResources) do
        teamResources[t] = {Gold = 0, Food = 0, Wood = 0}
    end
    currentTurnIndex = 1
    gameActive = true
    broadcastMap()
    broadcastResources()
end)

-- Start game
broadcastMap()
broadcastResources()