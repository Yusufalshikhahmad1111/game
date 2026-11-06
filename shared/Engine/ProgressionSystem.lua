-- shared/Engine/ProgressionSystem.lua (ModuleScript)
-- M5: Progression - XP, Rank, Achievements, Stats (no Pay-to-Win)
local ProgressionSystem = {}

-- Ranks (Bronze -> Dominion)
ProgressionSystem.Ranks = {
    {name = "Bronze", nameAr = "برونزي", xpRequired = 0, color = Color3.fromRGB(205, 127, 50)},
    {name = "Silver", nameAr = "فضي", xpRequired = 500, color = Color3.fromRGB(192, 192, 192)},
    {name = "Gold", nameAr = "ذهبي", xpRequired = 1500, color = Color3.fromRGB(255, 215, 0)},
    {name = "Platinum", nameAr = "بلاتيني", xpRequired = 3000, color = Color3.fromRGB(229, 228, 226)},
    {name = "Master", nameAr = "ماستر", xpRequired = 5000, color = Color3.fromRGB(136, 136, 255)},
    {name = "Dominion", nameAr = "السيادة", xpRequired = 8000, color = Color3.fromRGB(255, 255, 255)}
}

-- Achievements
ProgressionSystem.Achievements = {
    FirstWin = {
        id = "FirstWin",
        name = "First Victory",
        nameAr = "أول انتصار",
        description = "فوز في أول مباراة",
        xpReward = 100,
        icon = "🏆"
    },
    TerritoryKing = {
        id = "TerritoryKing",
        name = "Territory King",
        nameAr = "ملك الأراضي",
        description = "السيطرة على 80% من الخريطة في مباراة واحدة",
        xpReward = 150,
        icon = "🗺️"
    },
    ResourceMaster = {
        id = "ResourceMaster",
        name = "Resource Master",
        nameAr = "سيد الموارد",
        description = "جمع 1000 ذهبية في مباراة واحدة",
        xpReward = 100,
        icon = "🪙"
    },
    AIBeater = {
        id = "AIBeater",
        name = "AI Beater",
        nameAr = "مغلب الذكاء الاصطناعي",
        description = "فوز على صعوبة Hard",
        xpReward = 200,
        icon = "🤖"
    },
    RelicHunter = {
        id = "RelicHunter",
        name = "Relic Hunter",
        nameAr = "صائد القطع النادرة",
        description = "جمع 5 قطع أثرية (Relics)",
        xpReward = 150,
        icon = "🔮"
    },
    Strategist = {
        id = "Strategist",
        name = "Strategist",
        nameAr = "استراتيجي",
        description = "إكمال 10 مباريات",
        xpReward = 200,
        icon = "🧠"
    }
}

-- Player progression state (in-memory for single player, would be DataStore for multiplayer)
ProgressionSystem.PlayerData = {
    xp = 0,
    level = 1,
    rank = "Bronze",
    matchesPlayed = 0,
    matchesWon = 0,
    totalGoldEarned = 0,
    totalRelicsCollected = 0,
    achievementsUnlocked = {},
    stats = {
        totalCaptures = 0,
        totalPowersUsed = 0,
        favoritePower = nil,
        longestWinStreak = 0,
        currentWinStreak = 0
    }
}

-- Get rank for XP
function ProgressionSystem:getRankForXP(xp)
    local rank = ProgressionSystem.Ranks[1]
    for _, r in ipairs(ProgressionSystem.Ranks) do
        if xp >= r.xpRequired then
            rank = r
        end
    end
    return rank
end

-- Get level (simplified: level = rank index + 1)
function ProgressionSystem:getLevel()
    local rank = ProgressionSystem:getRankForXP(ProgressionSystem.PlayerData.xp)
    for i, r in ipairs(ProgressionSystem.Ranks) do
        if r.name == rank.name then
            return i
        end
    end
    return 1
end

-- Add XP
function ProgressionSystem:addXP(amount)
    ProgressionSystem.PlayerData.xp = ProgressionSystem.PlayerData.xp + amount
    local newRank = ProgressionSystem:getRankForXP(ProgressionSystem.PlayerData.xp)
    ProgressionSystem.PlayerData.rank = newRank.name
    return newRank
end

-- Record match played
function ProgressionSystem:recordMatch(won, difficultyModifier)
    local xpGain = won and 100 or 50
    xpGain = math.floor(xpGain * (difficultyModifier or 1.0))
    
    ProgressionSystem.PlayerData.matchesPlayed = ProgressionSystem.PlayerData.matchesPlayed + 1
    if won then
        ProgressionSystem.PlayerData.matchesWon = ProgressionSystem.PlayerData.matchesWon + 1
        ProgressionSystem.PlayerData.stats.currentWinStreak = (ProgressionSystem.PlayerData.stats.currentWinStreak or 0) + 1
        ProgressionSystem.PlayerData.stats.longestWinStreak = math.max(
            ProgressionSystem.PlayerData.stats.longestWinStreak or 0,
            ProgressionSystem.PlayerData.stats.currentWinStreak
        )
    else
        ProgressionSystem.PlayerData.stats.currentWinStreak = 0
    end
    
    -- Check achievements
    local newAchievements = ProgressionSystem:checkAchievements()
    
    -- Add XP
    local newRank = ProgressionSystem:addXP(xpGain)
    
    return {
        xpGained = xpGain,
        newRank = newRank,
        newAchievements = newAchievements
    }
end

-- Check achievements
function ProgressionSystem:checkAchievements()
    local newUnlocks = {}
    local data = ProgressionSystem.PlayerData
    
    for id, achievement in pairs(ProgressionSystem.Achievements) do
        if not data.achievementsUnlocked[id] then
            local unlocked = false
            
            if id == "FirstWin" and data.matchesWon >= 1 then
                unlocked = true
            elseif id == "TerritoryKing" and data.stats.longestWinStreak >= 1 then
                -- Simplified: winning implies good territory control
                unlocked = data.matchesWon >= 1
            elseif id == "ResourceMaster" and data.totalGoldEarned >= 1000 then
                unlocked = true
            elseif id == "AIBeater" and data.matchesWon >= 1 then
                unlocked = true -- In real implementation, check difficulty
            elseif id == "RelicHunter" and data.totalRelicsCollected >= 5 then
                unlocked = true
            elseif id == "Strategist" and data.matchesPlayed >= 10 then
                unlocked = true
            end
            
            if unlocked then
                data.achievementsUnlocked[id] = true
                table.insert(newUnlocks, achievement)
            end
        end
    end
    
    return newUnlocks
end

-- Get player data summary
function ProgressionSystem:getPlayerData()
    return {
        xp = ProgressionSystem.PlayerData.xp,
        level = ProgressionSystem:getLevel(),
        rank = ProgressionSystem.PlayerData.rank,
        matchesPlayed = ProgressionSystem.PlayerData.matchesPlayed,
        matchesWon = ProgressionSystem.PlayerData.matchesWon,
        achievementsUnlocked = ProgressionSystem.PlayerData.achievementsUnlocked,
        stats = ProgressionSystem.PlayerData.stats
    }
end

-- Add gold earned (for ResourceMaster achievement)
function ProgressionSystem:addGoldEarned(amount)
    ProgressionSystem.PlayerData.totalGoldEarned = (ProgressionSystem.PlayerData.totalGoldEarned or 0) + amount
end

-- Add relic collected
function ProgressionSystem:addRelicCollected(amount)
    ProgressionSystem.PlayerData.totalRelicsCollected = (ProgressionSystem.PlayerData.totalRelicsCollected or 0) + amount
end

-- Record power used
function ProgressionSystem:recordPowerUsed(powerName)
    ProgressionSystem.PlayerData.stats.totalPowersUsed = (ProgressionSystem.PlayerData.stats.totalPowersUsed or 0) + 1
    ProgressionSystem.PlayerData.stats.favoritePower = powerName
end

return ProgressionSystem