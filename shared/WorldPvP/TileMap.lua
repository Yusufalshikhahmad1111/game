-- High-resolution geographic world raster.
-- Ownership is per land pixel. Eight-way adjacency gives rounded, organic
-- frontiers instead of rigid orthogonal block expansion.
local Rules = require(script.Parent.Rules)
local CountryMapData = require(script.Parent.CountryMapData)

local TileMap = {}
TileMap.__index = TileMap

local DIRECTIONS = {
    {-1,-1},{0,-1},{1,-1},
    {-1,0},         {1,0},
    {-1,1}, {0,1},  {1,1},
}

local function idAt(x,y,width)
    return (y-1)*width+x
end

local function terrainAt(x,y,countryId)
    local seed=x*73856093+y*19349663
    for i=1,#countryId do
        seed+=string.byte(countryId,i)*(i*83492791)
    end
    local value=math.abs(math.sin(seed*0.000001)*43758.5453)%1
    if value>.965 then return "Mountain" end
    if value>.79 then return "Highland" end
    if value>.48 then return "Forest" end
    return "Plains"
end

local function edgeNoise(x,y)
    local value=math.sin(x*127.1+y*311.7)*43758.5453
    return (value-math.floor(value))-.5
end

function TileMap.build()
    local self=setmetatable({},TileMap)
    self.width=Rules.MapWidth
    self.height=Rules.MapHeight
    self.tiles={}
    self.landTiles={}
    self.countryTiles={}
    self.totalLand=0

    for y=1,self.height do
        for x=1,self.width do
            local lon=-180+((x-.5)/self.width)*360
            local lat=85-((y-.5)/self.height)*145
            local country=CountryMapData.findAt(lon,lat)
            local id=idAt(x,y,self.width)
            local tile={
                id=id,x=x,y=y,lon=lon,lat=lat,
                isLand=country~=nil,
                countryId=country and country.id or nil,
                terrain=country and terrainAt(x,y,country.id) or "Water",
                ownerId=0,building=nil,buildingLevel=0,
                isCoastal=false,neighbors=nil,
            }
            self.tiles[id]=tile
            if tile.isLand then
                self.totalLand+=1
                self.landTiles[#self.landTiles+1]=id
                local list=self.countryTiles[tile.countryId]
                if not list then
                    list={}
                    self.countryTiles[tile.countryId]=list
                end
                list[#list+1]=id
            end
        end
    end

    for _,tileId in ipairs(self.landTiles) do
        local tile=self.tiles[tileId]
        local x,y=tile.x,tile.y
        local neighbors={}
        local touchesWater=false
        for _,direction in ipairs(DIRECTIONS) do
            local nx=x+direction[1]
            local ny=y+direction[2]
            if nx<1 then nx=self.width end
            if nx>self.width then nx=1 end
            if ny>=1 and ny<=self.height then
                local neighbor=self.tiles[idAt(nx,ny,self.width)]
                if neighbor.isLand then
                    neighbors[#neighbors+1]=neighbor.id
                else
                    touchesWater=true
                end
            else
                touchesWater=true
            end
        end
        tile.neighbors=neighbors
        tile.isCoastal=touchesWater
    end

    return self
end

function TileMap:get(id)
    if type(id)~="number" or id%1~=0 or id<1 or id>#self.tiles then
        return nil
    end
    return self.tiles[id]
end

function TileMap:findSpawnTiles(centerId,radius)
    local center=self:get(centerId)
    if not center or not center.isLand then return {} end
    local result={}
    for y=math.max(1,center.y-radius-1),math.min(self.height,center.y+radius+1) do
        for x=math.max(1,center.x-radius-1),math.min(self.width,center.x+radius+1) do
            local dx,dy=x-center.x,y-center.y
            local distanceSquared=dx*dx+dy*dy
            local variedRadius=radius+edgeNoise(x,y)*0.48
            if distanceSquared<=variedRadius*variedRadius then
                local tile=self.tiles[idAt(x,y,self.width)]
                if tile.isLand and tile.ownerId==0 then
                    result[#result+1]=tile.id
                end
            end
        end
    end
    if #result==0 and center.ownerId==0 then
        result[1]=center.id
    end
    return result
end

function TileMap:countryCenterTile(countryId)
    local list=self.countryTiles[countryId]
    if not list or #list==0 then return nil end
    local country=CountryMapData.get(countryId)
    if not country then return list[1] end
    local cx,cy=country.center[1],country.center[2]
    local best,bestDistance=nil,math.huge
    for _,id in ipairs(list) do
        local tile=self.tiles[id]
        local dx,dy=tile.lon-cx,tile.lat-cy
        local distance=dx*dx+dy*dy
        if distance<bestDistance then
            best,bestDistance=id,distance
        end
    end
    return best
end

return TileMap
