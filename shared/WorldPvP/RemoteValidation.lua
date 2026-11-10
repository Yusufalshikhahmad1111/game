-- Pure input validation helpers for RemoteEvent boundaries.
local Validation={}

function Validation.integer(value,minValue,maxValue)
    local number=tonumber(value)
    if not number or number~=number or number==math.huge or number==-math.huge then return nil end
    if number%1~=0 then return nil end
    if minValue~=nil and number<minValue then return nil end
    if maxValue~=nil and number>maxValue then return nil end
    return math.floor(number)
end

function Validation.choice(value,allowed)
    if type(value)~="string" or type(allowed)~="table" then return nil end
    if allowed[value] then return value end
    return nil
end

return Validation
