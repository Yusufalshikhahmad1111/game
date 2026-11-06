-- shared/Engine/MatchModifierSystem.lua (ModuleScript)
-- M5: Match Modifiers - pre-match settings that change starting conditions
local MatchModifierSystem = {}

-- Available match modifiers
MatchModifierSystem.Modifiers = {
    Classic = {
        name = "Classic",
        nameAr = "كلاسيكي",
        description = "الوضع القياسي без تعديلات",
        icon = "⚖️",
        startingGoldMultiplier = 1.0,
        startingFoodMultiplier = 1.0,
        startingWoodMultiplier = 1.0,
        resourceMultiplier = 1.0,
        eventFrequency = 1.0
    },
    RichIslands = {
        name = "Rich Islands",
        nameAr = "جزر غنية",
        description = "موارد ابتدائية مزدوجة وإنتاج أعلى",
        icon = "💎",
        startingGoldMultiplier = 2.0,
        startingFoodMultiplier = 2.0,
        startingWoodMultiplier = 2.0,
        resourceMultiplier = 1.5,
        eventFrequency = 0.8
    },
    HarshWinter = {
        name = "Harsh Winter",
        nameAr = "شتاء قاسٍ",
        description = "إنتاج أقل وت lento أكثر",
        icon = "❄️",
        startingGoldMultiplier = 0.7,
        startingFoodMultiplier = 0.7,
        startingWoodMultiplier = 0.7,
        resourceMultiplier = 0.8,
        eventFrequency = 1.2
    },
    RelicRush = {
        name = "Relic Rush",
        nameAr = "سباق القطع النادرة",
        description = "مزيد من المواقع النادرة (Relics)",
        icon = "🔮",
        startingGoldMultiplier = 1.0,
        startingFoodMultiplier = 1.0,
        startingWoodMultiplier = 1.0,
        resourceMultiplier = 1.0,
        eventFrequency = 1.0,
        relicChanceBoost = 2.0
    },
    Chaos = {
        name = "Chaos",
        nameAr = "فوضى",
        description = "أحداث متكررة وتغيرات سريعة",
        icon = "🌪️",
        startingGoldMultiplier = 1.0,
        startingFoodMultiplier = 1.0,
        startingWoodMultiplier = 1.0,
        resourceMultiplier = 1.0,
        eventFrequency = 2.0
    }
}

-- Current match modifier
MatchModifierSystem.CurrentModifier = "Classic"

-- Get modifier config
function MatchModifierSystem:getModifier(modifierName)
    return MatchModifierSystem.Modifiers[modifierName] or MatchModifierSystem.Modifiers.Classic
end

-- Get all modifiers
function MatchModifierSystem:getAllModifiers()
    return MatchModifierSystem.Modifiers
end

-- Set current modifier (called before match start)
function MatchModifierSystem:setModifier(modifierName)
    if MatchModifierSystem.Modifiers[modifierName] then
        MatchModifierSystem.CurrentModifier = modifierName
        return true
    end
    return false
end

-- Get current modifier
function MatchModifierSystem:getCurrentModifier()
    return MatchModifierSystem:getModifier(MatchModifierSystem.CurrentModifier)
end

-- Get starting resources based on modifier
function MatchModifierSystem:getStartingResources()
    local modifier = MatchModifierSystem:getCurrentModifier()
    return {
        Gold = math.floor(100 * modifier.startingGoldMultiplier),
        Food = math.floor(100 * modifier.startingFoodMultiplier),
        Wood = math.floor(100 * modifier.startingWoodMultiplier),
        Relic = 0
    }
end

-- Get resource production multiplier
function MatchModifierSystem:getResourceMultiplier()
    return MatchModifierSystem:getCurrentModifier().resourceMultiplier
end

-- Get event frequency multiplier
function MatchModifierSystem:getEventFrequency()
    return MatchModifierSystem:getCurrentModifier().eventFrequency
end

return MatchModifierSystem