-- Server-side per-player action gate. No Roblox dependencies, so it is easy to test.
local RateLimiter={}
RateLimiter.__index=RateLimiter

function RateLimiter.new()
    return setmetatable({last={}},RateLimiter)
end

function RateLimiter:allow(userId,key,interval,now)
    if userId==nil or key==nil then return false end
    interval=math.max(0,tonumber(interval) or 0)
    now=tonumber(now) or os.clock()
    local bucket=self.last[userId]
    if not bucket then
        bucket={}
        self.last[userId]=bucket
    end
    local previous=bucket[key]
    if previous and now-previous<interval then
        return false
    end
    bucket[key]=now
    return true
end

function RateLimiter:reset(userId)
    self.last[userId]=nil
end

return RateLimiter
