-- shared/WorldPvP/TileMap.lua
-- Pixel/tile world derived from public-domain Natural Earth country shapes.
-- Ownership is per tile; country borders are only the initial land mask.

local Rules = require(script.Parent.Rules)
local CountryMapData = require(script.Parent.CountryMapData)

local TileMap = {}
TileMap.__index = TileMap

local function idAt(x,y)
    return (y-1)*Rules.MapWidth+x
end

local function terrainAt(x,y,countryId)
    local seed=x*73856093+y*19349663
    for i=1,#countryId do seed+=string.byte(countryId,i)*(i*83492791) end
    local v=math.abs(math.sin(seed*0.000001)*43758.5453)%1
    if v>.94 then return "Mountain" end
    if v>.76 then return "Highland" end
    if v>.48 then return "Forest" end
    return "Plains"
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
            local id=idAt(x,y)
            local tile={
                id=id,x=x,y=y,lon=lon,lat=lat,
                isLand=country~=nil,
                countryId=country and country.id or nil,
                terrain=country and terrainAt(x,y,country.id) or "Water",
                ownerId=0,building=nil,isCoastal=false,neighbors={}
            }
            self.tiles[id]=tile
            if tile.isLand then
                self.totalLand+=1
                self.landTiles[#self.landTiles+1]=id
                self.countryTiles[tile.countryId]=self.countryTiles[tile.countryId] or {}
                table.insert(self.countryTiles[tile.countryId],id)
            end
        end
    end

    for _,tile in ipairs(self.tiles) do
        local x,y=tile.x,tile.y
        local dirs={{-1,0},{1,0},{0,-1},{0,1}}
        local water=false
        for _,d in ipairs(dirs) do
            local nx,ny=x+d[1],y+d[2]
            if nx<1 then nx=self.width end
            if nx>self.width then nx=1 end
            if ny>=1 and ny<=self.height then
                local n=self.tiles[idAt(nx,ny)]
                table.insert(tile.neighbors,n.id)
                if not n.isLand then water=true end
            else water=true end
        end
        tile.isCoastal=tile.isLand and water
    end
    return self
end

function TileMap:get(id) return self.tiles[id] end

function TileMap:findSpawnTiles(centerId,radius)
    local c=self.tiles[centerId]
    if not c or not c.isLand then return {} end
    local result={}
    for y=math.max(1,c.y-radius),math.min(self.height,c.y+radius) do
        for x=math.max(1,c.x-radius),math.min(self.width,c.x+radius) do
            local dx,dy=x-c.x,y-c.y
            if dx*dx+dy*dy<=radius*radius then
                local t=self.tiles[idAt(x,y)]
                if t.isLand and t.ownerId==0 then table.insert(result,t.id) end
            end
        end
    end
    return result
end

function TileMap:countryCenterTile(countryId)
    local list=self.countryTiles[countryId]
    if not list or #list==0 then return nil end
    local country=CountryMapData.get(countryId)
    local cx,cy=country.center[1],country.center[2]
    local best,bestD=nil,math.huge
    for _,id in ipairs(list) do
        local t=self.tiles[id]
        local dx,dy=t.lon-cx,t.lat-cy
        local d=dx*dx+dy*dy
        if d<bestD then best,bestD=id,d end
    end
    return best
end

function TileMap:neighbors(id,landOnly)
    local t=self.tiles[id]
    local result={}
    if not t then return result end
    for _,nid in ipairs(t.neighbors) do
        local n=self.tiles[nid]
        if not landOnly or n.isLand then table.insert(result,nid) end
    end
    return result
end

return TileMap
