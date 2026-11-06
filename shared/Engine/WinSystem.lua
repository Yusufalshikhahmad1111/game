-- shared/Engine/WinSystem.lua (ModuleScript)
local WinSystem = {}

function WinSystem.checkWin(board)
    local firstCell = board:getCell(1,1)
    if not firstCell or firstCell.owner == "Neutral" then
        return false, nil
    end
    local owner = firstCell.owner
    for x = 1, board.gridSize do
        for y = 1, board.gridSize do
            local cell = board:getCell(x,y)
            if cell.owner ~= owner then
                return false, nil
            end
        end
    end
    return true, owner
end

return WinSystem