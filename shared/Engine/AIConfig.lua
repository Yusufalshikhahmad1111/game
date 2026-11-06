-- shared/Engine/AIConfig.lua (ModuleScript)
local AIConfig = {}

-- Personality weights for utility evaluation
-- Each personality weights different factors when choosing a color
AIConfig.Personalities = {
    Warlord = {
        name = "Warlord",
        description = "Focuses on expansion and attack",
        weights = {
            territoryGain = 2.0,      -- How many cells to capture
            resourceGain = 0.5,       -- Resources gained
            strategicValue = 1.0,     -- Value of captured cells
            threatReduction = 1.5,    -- Reducing opponent expansion
            capitalSecurity = 0.5,    -- Protecting own capital
            futureExpansion = 1.0,    -- Opening new paths
            opponentOpportunity = 1.0 -- Denying opponent moves
        }
    },
    Merchant = {
        name = "Merchant",
        description = "Focuses on resources and economic value",
        weights = {
            territoryGain = 0.5,
            resourceGain = 2.0,
            strategicValue = 0.5,
            threatReduction = 0.5,
            capitalSecurity = 0.5,
            futureExpansion = 0.5,
            opponentOpportunity = 0.5
        }
    },
    Guardian = {
        name = "Guardian",
        description = "Focuses on capital, fortress, and fortification",
        weights = {
            territoryGain = 0.5,
            resourceGain = 0.5,
            strategicValue = 2.0,
            threatReduction = 1.0,
            capitalSecurity = 2.0,
            futureExpansion = 0.5,
            opponentOpportunity = 0.5
        }
    },
    Trickster = {
        name = "Trickster",
        description = "Cuts opponent lines and creates tactical situations",
        weights = {
            territoryGain = 1.0,
            resourceGain = 0.5,
            strategicValue = 1.0,
            threatReduction = 2.0,
            capitalSecurity = 0.5,
            futureExpansion = 1.5,
            opponentOpportunity = 2.0
        }
    }
}

-- Difficulty levels
AIConfig.Difficulties = {
    Easy = {
        name = "Easy",
        description = "Greedy one-step evaluation",
        lookaheadSteps = 1,
        randomness = 0.3, -- 30% chance to pick suboptimal move
        personality = "Warlord"
    },
    Normal = {
        name = "Normal",
        description = "One-step + tactical lookahead",
        lookaheadSteps = 1,
        randomness = 0.15,
        personality = "Merchant"
    },
    Hard = {
        name = "Hard",
        description = "Two-step evaluation + personality weights",
        lookaheadSteps = 2,
        randomness = 0.05,
        personality = "Guardian"
    }
}

-- Default AI assignment per team
AIConfig.DefaultAIs = {
    AI1 = { personality = "Warlord", difficulty = "Normal" },
    AI2 = { personality = "Merchant", difficulty = "Hard" }
}

-- Get personality config
function AIConfig.getPersonality(personalityName)
    return AIConfig.Personalities[personalityName] or AIConfig.Personalities.Warlord
end

-- Get difficulty config
function AIConfig.getDifficulty(difficultyName)
    return AIConfig.Difficulties[difficultyName] or AIConfig.Difficulties.Normal
end

-- Get AI config for a team
function AIConfig.getAIConfig(team)
    return AIConfig.DefaultAIs[team] or { personality = "Warlord", difficulty = "Normal" }
end

return AIConfig