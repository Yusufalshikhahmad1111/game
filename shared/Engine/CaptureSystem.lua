-- shared/Engine/CaptureSystem.lua (ModuleScript)
local CaptureSystem = {}

function CaptureSystem:capture(board, team, chosenColor, MapData)
    -- Validate color
    local valid = false
    for _, color in ipairs(MapData.Colors) do
        if color == chosenColor then
            valid = true
            break
        end
    end
    if not valid then
        return {}, {Gold = 0, Food = 0, Wood = 0}
    end

    local toCapture = {}
    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x, y)
            if cell and cell.owner == team then
                local neighbors = board:getNeighbors(cell)
                for _, nb in ipairs(neighbors) do
                    if nb and nb.owner ~= team and nb.color == chosenColor then
                        table.insert(toCapture, nb)
                    end
                end
            end
        end
    end

    -- Remove duplicates by id
    local unique = {}
    local seen = {}
    for _, cell in ipairs(toCapture) do
        if cell and not seen[cell.id] then
            seen[cell.id] = true
            table.insert(unique, cell)
        end
    end

    -- Apply capture and compute resources
    local gainedResources = {Gold = 0, Food = 0, Wood = 0}
    for _, cell in ipairs(unique) do
        cell.owner = team
        for resType, amount in pairs(cell.resources) do
            gainedResources[resType] = gainedResources[resType] + amount
        end
    end

    return unique, gainedResources
end

return CaptureSystem