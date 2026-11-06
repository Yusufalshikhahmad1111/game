-- shared/Engine/PowerSystem.lua (ModuleScript)
-- M7: Full implementation of Dominion Powers with server-authoritative effects
local PowerSystem = {}

-- Available powers with costs, cooldowns, and effects
PowerSystem.Powers = {
    Scout = {
        name = "Scout",
        nameAr = "كشّاف",
        description = "كشف منطقة مخفية مؤقتاً",
        costGold = 50,
        costFood = 0,
        costWood = 0,
        cooldownTurns = 3,
        icon = "🔍",
        effectType = "reveal"
    },
    Harvest = {
        name = "Harvest",
        nameAr = "حصاد",
        description = "مضاعفة إنتاج إقليم لمدة دورين",
        costGold = 30,
        costFood = 20,
        costWood = 10,
        cooldownTurns = 4,
        icon = "🌾",
        effectType = "productionBoost",
        durationTurns = 2,
        multiplier = 2.0
    },
    Fortify = {
        name = "Fortify",
        nameAr = "تحصين",
        description = "رفع دفاع إقليم ally لمدة دورين",
        costGold = 40,
        costFood = 10,
        costWood = 20,
        cooldownTurns = 3,
        icon = "🛡️",
        effectType = "defenseBoost",
        durationTurns = 2,
        multiplier = 0.5 -- +50% defense
    },
    Sabotage = {
        name = "Sabotage",
        nameAr = "تخريب",
        description = "خفض إنتاج إقليم خصم لدور واحد",
        costGold = 60,
        costFood = 30,
        costWood = 0,
        cooldownTurns = 5,
        icon = "💣",
        effectType = "productionReduction",
        durationTurns = 1,
        multiplier = 0.5 -- -50% production
    },
    ColorShift = {
        name = "Color Shift",
        nameAr = "تغيير لون",
        description = "إعادة رول محدود للألوان في المنطقة",
        costGold = 80,
        costFood = 40,
        costWood = 40,
        cooldownTurns = 6,
        icon = "🎨",
        effectType = "colorShift"
    },
    Shockwave = {
        name = "Shockwave",
        nameAr = "موجة صدمية",
        description = "التوسع من نقطة معينة مرة استثنائية",
        costGold = 100,
        costFood = 50,
        costWood = 50,
        cooldownTurns = 8,
        icon = "💥",
        effectType = "shockwave"
    }
}

-- Active power effects (server-side state)
-- Structure: [powerName] = {turnsRemaining, targetCellId, data, team}
PowerSystem.ActiveEffects = {}

-- Per-team active effects (for team-specific powers like Harvest, Fortify, Sabotage)
-- Structure: [teamName] = { [powerName] = {turnsRemaining, targetCellId, data} }
PowerSystem.TeamEffects = {}

-- Get power config
function PowerSystem:getPower(powerName)
    return PowerSystem.Powers[powerName]
end

-- Get all powers
function PowerSystem:getAllPowers()
    return PowerSystem.Powers
end

-- Check if player can afford a power
function PowerSystem:canAfford(teamResources, powerName)
    local power = PowerSystem.Powers[powerName]
    if not power then return false end
    return (teamResources.Gold or 0) >= power.costGold
        and (teamResources.Food or 0) >= power.costFood
        and (teamResources.Wood or 0) >= power.costWood
end

-- Check if power is on cooldown (global)
function PowerSystem:isOnCooldown(powerName)
    local effect = PowerSystem.ActiveEffects[powerName]
    if not effect then return false end
    return effect.turnsRemaining > 0
end

-- Check if a team-specific power effect is active
function PowerSystem:isTeamEffectActive(teamName, powerName)
    if not PowerSystem.TeamEffects[teamName] then return false end
    local effect = PowerSystem.TeamEffects[teamName][powerName]
    if not effect then return false end
    return effect.turnsRemaining > 0
end

-- Get remaining cooldown turns (global)
function PowerSystem:getCooldownRemaining(powerName)
    local effect = PowerSystem.ActiveEffects[powerName]
    if not effect then return 0 end
    return effect.turnsRemaining or 0
end

-- Get remaining turns for a team effect
function PowerSystem:getTeamEffectRemaining(teamName, powerName)
    if not PowerSystem.TeamEffects[teamName] then return 0 end
    local effect = PowerSystem.TeamEffects[teamName][powerName]
    if not effect then return 0 end
    return effect.turnsRemaining or 0
end

-- Apply power cost (deduct resources)
function PowerSystem:applyCost(teamResources, powerName)
    local power = PowerSystem.Powers[powerName]
    if not power then return false end
    if not PowerSystem:canAfford(teamResources, powerName) then return false end
    
    teamResources.Gold = (teamResources.Gold or 0) - power.costGold
    teamResources.Food = (teamResources.Food or 0) - power.costFood
    teamResources.Wood = (teamResources.Wood or 0) - power.costWood
    return true
end

-- Activate a power effect
function PowerSystem:activatePower(powerName, targetCellId, data)
    local power = PowerSystem.Powers[powerName]
    if not power then return false end
    
    PowerSystem.ActiveEffects[powerName] = {
        turnsRemaining = power.cooldownTurns,
        targetCellId = targetCellId,
        data = data or {},
        activatedAt = tick()
    }
    return true
end

-- Activate a team-specific power effect
function PowerSystem:activateTeamEffect(teamName, powerName, targetCellId, data)
    local power = PowerSystem.Powers[powerName]
    if not power then return false end
    
    if not PowerSystem.TeamEffects[teamName] then
        PowerSystem.TeamEffects[teamName] = {}
    end
    
    PowerSystem.TeamEffects[teamName][powerName] = {
        turnsRemaining = power.durationTurns or power.cooldownTurns,
        targetCellId = targetCellId,
        data = data or {},
        activatedAt = tick()
    }
    return true
end

-- Get production modifier for a cell based on active team effects
-- Returns multiplier for a given resource type on a cell
function PowerSystem:getProductionModifier(teamName, cell)
    local modifier = 1.0
    
    if PowerSystem.TeamEffects[teamName] then
        -- Harvest: boost production
        local harvest = PowerSystem.TeamEffects[teamName].Harvest
        if harvest and harvest.turnsRemaining > 0 then
            modifier = modifier * (harvest.data.multiplier or 2.0)
        end
        
        -- Sabotage: reduce production (applied to enemy cells, checked elsewhere)
    end
    
    return modifier
end

-- Get defense modifier for a cell based on active team effects
function PowerSystem:getDefenseModifier(teamName, cell)
    local modifier = 0
    
    if PowerSystem.TeamEffects[teamName] then
        -- Fortify: boost defense
        local fortify = PowerSystem.TeamEffects[teamName].Fortify
        if fortify and fortify.turnsRemaining > 0 then
            modifier = modifier + (fortify.data.multiplier or 0.5)
        end
    end
    
    return modifier
end

-- Decrement cooldowns and team effects (call at end of each turn)
function PowerSystem:tickCooldowns()
    -- Global cooldowns
    for powerName, effect in pairs(PowerSystem.ActiveEffects) do
        if effect.turnsRemaining > 0 then
            effect.turnsRemaining = effect.turnsRemaining - 1
        end
        if effect.turnsRemaining <= 0 then
            PowerSystem.ActiveEffects[powerName] = nil
        end
    end
    
    -- Team effects
    for teamName, effects in pairs(PowerSystem.TeamEffects) do
        for powerName, effect in pairs(effects) do
            if effect.turnsRemaining > 0 then
                effect.turnsRemaining = effect.turnsRemaining - 1
            end
            if effect.turnsRemaining <= 0 then
                effects[powerName] = nil
            end
        end
        -- Clean up empty effect tables
        if next(effects) == nil then
            PowerSystem.TeamEffects[teamName] = nil
        end
    end
end

-- Get all active cooldowns for UI
function PowerSystem:getAllCooldowns()
    local cooldowns = {}
    for powerName, effect in pairs(PowerSystem.ActiveEffects) do
        cooldowns[powerName] = effect.turnsRemaining
    end
    return cooldowns
end

-- Get all team effects for UI
function PowerSystem:getAllTeamEffects()
    local allEffects = {}
    for teamName, effects in pairs(PowerSystem.TeamEffects) do
        local teamEffectList = {}
        for powerName, effect in pairs(effects) do
            table.insert(teamEffectList, {
                power = powerName,
                turnsRemaining = effect.turnsRemaining,
                targetCellId = effect.targetCellId
            })
        end
        if #teamEffectList > 0 then
            allEffects[teamName] = teamEffectList
        end
    end
    return allEffects
end

-- ============================================================
-- POWER EFFECT EXECUTION (Server-authoritative)
-- ============================================================

-- Execute a power's gameplay effect on the board
-- Returns a description of what happened
function PowerSystem:executePower(board, gameState, teamName, powerName, targetCellId)
    local power = PowerSystem.Powers[powerName]
    if not power then return false, "Invalid power" end
    
    local effectType = power.effectType
    
    if effectType == "Scout" or effectType == "reveal" then
        -- Scout: reveal terrain info (server just logs; client gets info via inspector)
        -- In future, could reveal hidden terrain types
        return true, "Scout activated - terrain revealed"
    
    elseif effectType == "Harvest" then
        -- Harvest: double production for 2 turns on all owned cells
        PowerSystem:activateTeamEffect(teamName, "Harvest", targetCellId, {multiplier = power.multiplier})
        return true, "Harvest activated - production doubled for 2 turns"
    
    elseif effectType == "Fortify" then
        -- Fortify: boost defense for 2 turns
        PowerSystem:activateTeamEffect(teamName, "Fortify", targetCellId, {multiplier = power.multiplier})
        return true, "Fortify activated - defense boosted for 2 turns"
    
    elseif effectType == "Sabotage" then
        -- Sabotage: reduce opponent production for 1 turn
        -- Find opponent teams and apply reduction
        for _, otherTeam in ipairs({"Player", "AI1", "AI2"}) do
            if otherTeam ~= teamName then
                PowerSystem:activateTeamEffect(otherTeam, "Sabotage", targetCellId, {multiplier = power.multiplier})
            end
        end
        return true, "Sabotage activated - opponent production reduced for 1 turn"
    
    elseif effectType == "ColorShift" then
        -- ColorShift: re-roll terrain colors in a 3x3 area around target
        if targetCellId then
            local x, y = self:_parseCellId(targetCellId)
            if x and y then
                local changed = 0
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        local cell = board:getCell(x + dx, y + dy)
                        if cell and cell.owner == "Neutral" then
                            -- Re-roll color for neutral cells only
                            local colors = {"Red", "Blue", "Green", "Yellow", "Purple", "Orange"}
                            cell.color = colors[math.random(1, #colors)]
                            changed = changed + 1
                        end
                    end
                end
                return true, string.format("ColorShift activated - %d neutral cells re-rolled", changed)
            end
        end
        return true, "ColorShift activated"
    
    elseif effectType == "Shockwave" then
        -- Shockwave: capture from a specific point once
        if targetCellId then
            local x, y = self:_parseCellId(targetCellId)
            if x and y then
                local cell = board:getCell(x, y)
                if cell and cell.owner ~= teamName then
                    -- Force capture this cell (bypass normal color rules)
                    cell.owner = teamName
                    -- Add baseYield resources
                    for resType, amount in pairs(cell.baseYield or {}) do
                        gameState.teamResources[teamName][resType] = (gameState.teamResources[teamName][resType] or 0) + amount
                    end
                    return true, "Shockwave activated - cell captured"
                end
            end
        end
        return true, "Shockwave activated"
    end
    
    return true, "Power activated"
end

-- Helper: parse "x,y" cell id
function PowerSystem:_parseCellId(cellId)
    if not cellId then return nil, nil end
    local parts = {}
    for part in string.gmatch(cellId, "([^,]+)") do
        table.insert(parts, part)
    end
    if #parts == 2 then
        return tonumber(parts[1]), tonumber(parts[2])
    end
    return nil, nil
end

return PowerSystem