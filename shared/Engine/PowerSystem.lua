-- shared/Engine/PowerSystem.lua (ModuleScript)
-- M5: Dominion Powers - server-authoritative special abilities
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
        icon = "🔍"
    },
    Harvest = {
        name = "Harvest",
        nameAr = "حصاد",
        description = "مضاعفة إنتاج إقليم لمدة دورين",
        costGold = 30,
        costFood = 20,
        costWood = 10,
        cooldownTurns = 4,
        icon = "🌾"
    },
    Fortify = {
        name = "Fortify",
        nameAr = "تحصين",
        description = "رفع دفاع إقليم ally لمدة دورين",
        costGold = 40,
        costFood = 10,
        costWood = 20,
        cooldownTurns = 3,
        icon = "🛡️"
    },
    Sabotage = {
        name = "Sabotage",
        nameAr = "تخريب",
        description = "خفض إنتاج إقليم خصم لدور واحد",
        costGold = 60,
        costFood = 30,
        costWood = 0,
        cooldownTurns = 5,
        icon = "💣"
    },
    ColorShift = {
        name = "Color Shift",
        nameAr = "تغيير لون",
        description = "إعادة رول محدود للألوان في المنطقة",
        costGold = 80,
        costFood = 40,
        costWood = 40,
        cooldownTurns = 6,
        icon = "🎨"
    },
    Shockwave = {
        name = "Shockwave",
        nameAr = "موجة صدمية",
        description = "التوسع من نقطة معينة مرة استثنائية",
        costGold = 100,
        costFood = 50,
        costWood = 50,
        cooldownTurns = 8,
        icon = "💥"
    }
}

-- Active power effects (server-side state)
PowerSystem.ActiveEffects = {} -- [powerName] = {turnsRemaining, targetCellId, data}

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

-- Check if power is on cooldown
function PowerSystem:isOnCooldown(powerName)
    local effect = PowerSystem.ActiveEffects[powerName]
    if not effect then return false end
    return effect.turnsRemaining > 0
end

-- Get remaining cooldown turns
function PowerSystem:getCooldownRemaining(powerName)
    local effect = PowerSystem.ActiveEffects[powerName]
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

-- Decrement cooldowns (call at end of each turn)
function PowerSystem:tickCooldowns()
    for powerName, effect in pairs(PowerSystem.ActiveEffects) do
        if effect.turnsRemaining > 0 then
            effect.turnsRemaining = effect.turnsRemaining - 1
        end
        if effect.turnsRemaining <= 0 then
            PowerSystem.ActiveEffects[powerName] = nil
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

return PowerSystem