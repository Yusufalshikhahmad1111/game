-- shared/Engine/ValidationSystem.lua (ModuleScript)
local ValidationSystem = {}

function ValidationSystem.validateColor(colorName, MapData)
    if type(colorName) ~= "string" then return false end
    for _, color in ipairs(MapData.Colors) do
        if color == colorName then
            return true
        end
    end
    return false
end

function ValidationSystem.validateMapSize(size, MapData)
    if type(size) ~= "number" then return false end
    for _, s in ipairs(MapData.AvailableSizes) do
        if s == size then
            return true
        end
    end
    return false
end

function ValidationSystem.validateTurn(currentTeam, expectedTeam)
    return currentTeam == expectedTeam
end

function ValidationSystem.validateGameActive(gameActive)
    return gameActive == true
end

return ValidationSystem