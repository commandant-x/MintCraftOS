-- Conservative 4-block cells derived only from complete loaded world sections.
-- Unknown and stale cells never become free. No peripheral or world IO here.
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local M={maxPages=64,maxBytes=65536,ttl=5,cell=4}
local function label(s,n) return type(s)=='string' and #s>0 and #s<=(n or 128) and not s:find('%c') end
local function integer(v) return A.finite(v) and v%1==0 and math.abs(v)<=9007199254740991 end
local function point(v) local p=A.vec(v) if not p then return end for _,axis in ipairs({'x','y','z'}) do if math.abs(p[axis])>30000000 then return end end return p end
local function key(x,y,z) return x..':'..y..':'..z end
function M.context(raw,started,finished,previous)
 if type(raw)~='table' or raw.schema~=1 or raw.synthetic==true or raw.valid==false or raw.ok~=true or raw.readOnly~=true or raw.scope~='actual-parent-world-context' or raw.frame~='world' or raw.unit~='block' or
  not label(raw.namespace) or not label(raw.vehicleId) or not label(raw.clockId) or raw.clock~='minecraft_game_tick' or
  not integer(raw.computerId) or raw.computerId<0 or raw.computerId>2147483647 or not integer(raw.serverTick) or raw.serverTick<0 or not integer(raw.observedAtGameTick) or raw.observedAtGameTick<0 or not point(raw.position) or
  not integer(raw.minimumY) or not integer(raw.maximumY) or raw.maximumY<=raw.minimumY or raw.maximumY-raw.minimumY>4096 or math.abs(raw.minimumY)>1000000 or math.abs(raw.maximumY)>1000000 or
  not A.finite(started) or not A.finite(finished) or started<0 or finished<started or finished-started>.5 then return nil,'Invalid actual-world context identity/frame/clock' end
 if previous and previous.namespace==raw.namespace and previous.sourceClockId==raw.clockId and (raw.serverTick<=previous.serverTick or raw.observedAtGameTick<previous.sourceObservedAt) then return nil,'World context clock did not advance' end
 return {schema=1,available=true,source='mintcraft_terrain.context',namespace=raw.namespace,vehicleId=raw.vehicleId,position=A.vec(raw.position),
  frame='world',unit='block',minimumY=raw.minimumY,maximumY=raw.maximumY,sourceClockId=raw.clockId,sourceObservedAt=raw.observedAtGameTick,serverTick=raw.serverTick,
  clock='local_uptime',clockId=C.clockId(),observedAt=started,validUntil=started+1,computerId=raw.computerId}
end
function M.new()
 local self={pages={},count=0,generation=0,reason='No loaded world terrain observed',dynamicCoverage=false}
 function self:reset(namespace,sourceClockId,vehicleId)
  self.pages={} self.count=0 self.namespace=namespace self.sourceClockId=sourceClockId self.vehicleId=vehicleId self.generation=self.generation+1
 end
 function self:accept(raw,context,started,finished)
  if not C.fresh(context,finished) or context.source~='mintcraft_terrain.context' or context.frame~='world' or context.unit~='block' or not point(context.position) or not integer(context.serverTick) or not label(context.namespace) or not label(context.vehicleId) or not label(context.sourceClockId) or not integer(context.minimumY) or not integer(context.maximumY) or not integer(context.sourceObservedAt) then return false,'Fresh actual-world context required' end
  if type(raw)~='table' or raw.schema~=1 or raw.synthetic==true or raw.valid==false or raw.ok~=true or raw.readOnly~=true or raw.scope~='loaded-world-static-section' or raw.complete~=true or
   raw.dynamicCoverage~=false or raw.frame~='world' or raw.unit~='block' or raw.namespace~=context.namespace or raw.vehicleId~=context.vehicleId or
   raw.clock~='minecraft_game_tick' or raw.clockId~=context.sourceClockId or not integer(raw.observedAtGameTick) or raw.observedAtGameTick<context.sourceObservedAt or not integer(raw.serverTick) or raw.serverTick<context.serverTick or
   raw.encoding~='sparse-runs-start:length:value' or raw.edge~=16 or type(raw.runs)~='string' or #raw.runs>40960 or
   not A.finite(started) or not A.finite(finished) or started<0 or finished<started or finished-started>.5 then return false,'Invalid loaded-world section scope/identity/clock' end
  local p=A.vec(raw.origin)
  if not p then return false,'World section origin missing' end
  for _,axis in ipairs({'x','y','z'}) do
   if not integer(p[axis]) or p[axis]%16~=0 or math.abs(p[axis]+8-context.position[axis])+8>128 then return false,'Section outside observed local world range' end
  end
  if p.y<context.minimumY or p.y+16>context.maximumY then return false,'Section outside observed world height' end
  if self.namespace~=context.namespace or self.sourceClockId~=context.sourceClockId or self.vehicleId~=context.vehicleId then self:reset(context.namespace,context.sourceClockId,context.vehicleId) end
  local id=key(p.x,p.y,p.z) local old=self.pages[id]
  if old and raw.serverTick<=old.serverTick then return false,'Replayed world section cannot refresh its age' end
  local blocked={} local last,total,offset=0,0,1
  while offset<=#raw.runs do
   local a,b,first,length,value=raw.runs:find('(%d+):(%d+):(%d+);',offset)
   if a~=offset then return false,'Malformed world section runs' end
   first,length,value=tonumber(first),tonumber(length),tonumber(value)
   if not integer(first) or not integer(length) or first<last or length<1 or first+length>4096 or value~=1 then return false,'Invalid world section run bounds/overlap/classification' end
   for i=first,first+length-1 do
    local x,z,y=i%16,math.floor(i/16)%16,math.floor(i/256)
    blocked[math.floor(x/4)+4*math.floor(z/4)+16*math.floor(y/4)+1]=true
   end
   total=total+length last=first+length offset=b+1
  end
  if raw.occupied~=total then return false,'World section occupied count differs' end
  local cells={} for i=1,64 do cells[i]=string.char(blocked[i] and 1 or 0) end
  if not old and self.count>=M.maxPages then
   local victim,at
   for page,record in pairs(self.pages) do if not at or record.observedAt<at then victim,at=page,record.observedAt end end
   self.pages[victim]=nil self.count=self.count-1
  end
  if not old then self.count=self.count+1 end
  self.pages[id]={origin=p,cells=table.concat(cells),namespace=raw.namespace,vehicleId=raw.vehicleId,
   source='mintcraft_terrain.terrainPage',sourceClockId=raw.clockId,sourceObservedAt=raw.observedAtGameTick,serverTick=raw.serverTick,
   clock='local_uptime',clockId=C.clockId(),observedAt=started,validUntil=started+M.ttl}
  self.generation=self.generation+1 self.reason='Observed conservative static world cells; unknown elsewhere; dynamic coverage unavailable' return true
 end
 function self:query(x,y,z,now)
  if not point({x=x,y=y,z=z}) then return 'unknown','Invalid world coordinate' end
  local ox,oy,oz=math.floor(x/16)*16,math.floor(y/16)*16,math.floor(z/16)*16
  local page=self.pages[key(ox,oy,oz)]
  if not page or page.invalidated or not C.fresh(page,now) then return 'unknown','World cell absent/stale or from another boot' end
  local i=math.floor((x-ox)/4)+4*math.floor((z-oz)/4)+16*math.floor((y-oy)/4)+1
  return page.cells:byte(i)==1 and 'blocked' or 'free','Conservative 4-block static cell only'
 end
 function self:boxFree(minimum,maximum,now)
  local low,high=point(minimum),point(maximum) if not low or not high then return false,'Invalid swept world volume' end
  local first,last={},{} local count=1
  for _,axis in ipairs({'x','y','z'}) do
   if high[axis]<=low[axis] then return false,'Empty/inverted swept world volume' end
   first[axis]=math.floor(low[axis]/4) last[axis]=math.ceil(high[axis]/4)-1 count=count*(last[axis]-first[axis]+1)
  end
  if not A.finite(count) or count>4096 then return false,'Swept volume exceeds collision-query budget' end
  for x=first.x,last.x do for y=first.y,last.y do for z=first.z,last.z do
   local state,why=self:query(x*4,y*4,z*4,now) if state~='free' then return false,state..': '..why end
  end end end return true,'Observed static cells only; dynamic obstacles unobserved'
 end
 function self:invalidate(origin,why)
  local p=point(origin) if not p then return false end
  local page=self.pages[key(p.x,p.y,p.z)]
  if page then page.invalidated=true page.reason=why self.generation=self.generation+1 end return true
 end
 function self:suspend(why)
  for _,page in pairs(self.pages) do page.invalidated=true end
  self.reason=why self.generation=self.generation+1
 end
 function self:snapshot(now)
  now=now or os.clock()
  local fresh=0 for _,page in pairs(self.pages) do if not page.invalidated and C.fresh(page,now) then fresh=fresh+1 end end
  return {schema=1,type='atlas-static-terrain',available=fresh>0,source='mintcraft_terrain',frame='world',unit='block',namespace=self.namespace,vehicleId=self.vehicleId,
   sourceClockId=self.sourceClockId,pages=A.copy(self.pages),count=self.count,freshPages=fresh,generation=self.generation,cell=4,
   dynamicCoverage=false,reason=self.reason,clock='local_uptime',clockId=C.clockId(),observedAt=now,validUntil=now+.5}
 end
 return self
end
local function validate(snapshot)
 if type(snapshot)~='table' or snapshot.schema~=1 or snapshot.synthetic==true or snapshot.type~='atlas-static-terrain' or snapshot.frame~='world' or snapshot.unit~='block' or snapshot.cell~=4 or
  snapshot.dynamicCoverage~=false or not label(snapshot.namespace) or not label(snapshot.vehicleId) or not label(snapshot.sourceClockId) or type(snapshot.pages)~='table' then return false,'Invalid terrain archive namespace/frame/schema' end
 local count=0
 for id,page in pairs(snapshot.pages) do
  count=count+1 local p=type(page)=='table' and point(page.origin)
  if count>M.maxPages or not p or page.synthetic==true or p.x%16~=0 or p.y%16~=0 or p.z%16~=0 or id~=key(p.x,p.y,p.z) or
   type(page.cells)~='string' or #page.cells~=64 or page.namespace~=snapshot.namespace or page.vehicleId~=snapshot.vehicleId or
   page.sourceClockId~=snapshot.sourceClockId or not label(page.clockId) or page.clock~='local_uptime' or
   not A.finite(page.observedAt) or page.observedAt<0 or not A.finite(page.validUntil) or page.validUntil~=page.observedAt+M.ttl or
   not integer(page.sourceObservedAt) or not integer(page.serverTick) then return false,'Invalid bounded terrain archive page' end
  for i=1,64 do local value=page.cells:byte(i) if value~=0 and value~=1 then return false,'Invalid terrain cell classification' end end
 end
 if count~=snapshot.count then return false,'Terrain archive page count differs' end
 return true
end
function M.encode(snapshot)
 local value,why=C.clone(snapshot) if not value then return nil,why end
 local ok,err=validate(value) if not ok then return nil,err end
 local success,text=pcall(textutils.serialize,value,{compact=true})
 if not success or type(text)~='string' or #text>M.maxBytes then return nil,'Terrain archive exceeds storage budget' end return text
end
function M.restore(text)
 if type(text)~='string' or #text>M.maxBytes then return nil,'Terrain input exceeds storage budget' end
 local ok,value=pcall(textutils.unserialize,text) if not ok then return nil,'Terrain archive decoding failed' end
 value=C.clone(value) local valid,why=validate(value) if not valid then return nil,why end
 local map=M.new() map:reset(value.namespace,value.sourceClockId,value.vehicleId)
 map.pages=value.pages map.count=value.count
 for _,page in pairs(map.pages) do page.invalidated=true end
 map.reason='Historical terrain only; fresh world observations required' return map
end
return M
