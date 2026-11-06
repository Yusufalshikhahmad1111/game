-- shared/Engine/EventSystem.lua (ModuleScript)
-- M5: World Events - random map-wide events that change gameplay
local EventSystem = {}

-- Available world events
EventSystem.Events = {
    MeteorShower = {
        name = "Meteor Shower",
        nameAr = "زخّات النيازك",
        description = "المناجم تصبح أغلى لمدة دورتين",
        icon = "☄️",
        durationTurns = 2,
        effectType = "resourceCostIncrease",
        targetTerrain = "Mine",
        multiplier = 2.0
    },
    GreatRain = {
        name = "Great Rain",
        nameAr = "الأمطار الغزيرة",
        description = "إنتاج الطعام يزيد بنسبة 30%",
        icon = "🌧️",
        durationTurns = 2,
        effectType = "productionBoost",
        targetTerrain = "Plains",
        multiplier = 1.3
    },
    Wildfire = {
        name = "Wildfire",
        nameAr = "حريق غابات",
        description = "بعض الغابات تصبح أقل إنتاجاً",
        icon = "🔥",
        durationTurns = 2,
        effectType = "productionReduction",
        targetTerrain = "Forest",
        multiplier = 0.5
    },
    HighTide = {
        name = "High Tide",
        nameAr = "المد العالي",
        description = "الموانئ تصبح استراتيجية",
        icon = "🌊",
        durationTurns = 3,
        effectType = "strategicValueBoost",
        targetTerrain = "Harbor",
        multiplier = 1.5
    },
    LostCaravan = {
        name = "Lost Caravan",
        nameAr = "القافلة المفقودة",
        description = "تظهر مكافأة نادرة في منطقة عشوائية",
        icon = "🐪",
        durationTurns = 1,
        effectType = "relicSpawn",
        targetTerrain = nil,
        multiplier = 1.0
    }
}

-- Active events state
EventSystem.ActiveEvents = {}

-- Get event config
function EventSystem:getEvent(eventName)
    return EventSystem.Events[eventName]
end

-- Get all events
function EventSystem:getAllEvents()
    return EventSystem.Events
end

-- Check if an event is active
function EventSystem:isActive(eventName)
    local event = EventSystem.ActiveEvents[eventName]
    return event ~= nil and event.turnsRemaining > 0
end

-- Get remaining turns for an event
function EventSystem:getRemainingTurns(eventName)
    local event = EventSystem.ActiveEvents[eventName]
    if not event then return 0 end
    return event.turnsRemaining or 0
end

-- Activate an event
function EventSystem:activateEvent(eventName)
    local event = EventSystem.Events[eventName]
    if not event then return false end
    
    EventSystem.ActiveEvents[eventName] = {
        turnsRemaining = event.durationTurns,
        activatedAt = tick()
    }
    return true
end

-- Decrement event durations (call at end of each turn)
function EventSystem:tickDurations()
    for eventName, event in pairs(EventSystem.ActiveEvents) do
        if event.turnsRemaining > 0 then
            event.turnsRemaining = event.turnsRemaining - 1
        end
        if event.turnsRemaining <= 0 then
            EventSystem.ActiveEvents[eventName] = nil
        end
    end
end

-- Get all active events for UI
function EventSystem:getAllActiveEvents()
    local active = {}
    for eventName, event in pairs(EventSystem.ActiveEvents) do
        table.insert(active, {
            name = eventName,
            nameAr = EventSystem.Events[eventName].nameAr,
            icon = EventSystem.Events[eventName].icon,
            turnsRemaining = event.turnsRemaining
        })
    end
    return active
end

-- Get production modifier for a terrain type (if an event affects it)
function EventSystem:getProductionModifier(terrainType, productionType)
    local modifier = 1.0
    for eventName, event in pairs(EventSystem.ActiveEvents) do
        local eventConfig = EventSystem.Events[eventName]
        if eventConfig.targetTerrain == terrainType then
            if eventConfig.effectType == "productionBoost" or eventConfig.effectType == "productionReduction" then
                modifier = modifier * eventConfig.multiplier
            end
        end
    end
    return modifier
end

return EventSystem