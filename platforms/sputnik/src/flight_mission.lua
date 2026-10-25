-- Local declared-map navigation. Unknown terrain is never declared clear.
local M={schema=1,maxPoints=64,maxZones=16}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
M.distance=distance
function M.parse(text,zones)
 if type(text)~='string' or #text>12000 then return nil,'Liste trop longue/invalide' end
 local out={};local width=zones and 6 or 4
 for line in text:gmatch('[^;\r\n]+') do
  local row={} for v in (line..','):gmatch('(.-),') do row[#row+1]=tonumber(v) or false end
  if not zones and #row==3 then row[4]=0 end
  if #row~=width then return nil,'Point x,y,z[,vitesse] / zone xmin,ymin,zmin,xmax,ymax,zmax' end
  for _,v in ipairs(row) do if not finite(v) or math.abs(v)>30000000 then return nil,'Coordonnee invalide' end end
  if zones then
   if row[1]>=row[4] or row[2]>=row[5] or row[3]>=row[6] then return nil,'Boite interdite invalide' end
   out[#out+1]=row
  else if row[4]<0 then return nil,'Vitesse positive ou 0 automatique' end;out[#out+1]={x=row[1],y=row[2],z=row[3],speed=row[4]} end
  if #out>(zones and M.maxZones or M.maxPoints) then return nil,'Budget de points/zones depasse' end
 end
 return out
end
function M.blocked(a,b,zones,margin)
 for _,box in ipairs(zones) do
  local low,high=0,1
  for i,key in ipairs({'x','y','z'}) do
   local d=b[key]-a[key];local minimum,maximum=box[i]-margin,box[i+3]+margin
   if math.abs(d)<1e-9 then if a[key]<minimum or a[key]>maximum then low=2;break end
   else local t1,t2=(minimum-a[key])/d,(maximum-a[key])/d;if t1>t2 then t1,t2=t2,t1 end;low=math.max(low,t1);high=math.min(high,t2) end
  end
  if low<=high and high>=0 and low<=1 then return true end
 end
 return false
end
-- Incremental visibility search: at most 64 candidate edges per control tick.
function M.planner(start,goal,zones,margin)
 local nodes={start,goal};local distances={[1]=0};local previous,closed={},{}
 for _,box in ipairs(zones) do for mask=0,7 do
  local p={};for i,key in ipairs({'x','y','z'}) do p[key]=box[math.floor(mask/2^(i-1))%2==0 and i or i+3]+(math.floor(mask/2^(i-1))%2==0 and -1 or 1)*(margin+.05) end
  nodes[#nodes+1]=p
 end end
 local s={nodes=nodes,done=false,reason='Calcul route: terrain non observe',current=nil,next=1}
 function s:step()
  for _=1,64 do
   if not self.current then
    local best,cost
    for i,p in ipairs(nodes) do if not closed[i] and distances[i] and (not cost or distances[i]+distance(p,goal)<cost) then best,cost=i,distances[i]+distance(p,goal) end end
    if not best then self.done=true;self.failed=true;self.reason='Aucune route parmi les zones declarees';return end
    if best==2 then
     local path={};local i=2;while i do table.insert(path,1,nodes[i]);i=previous[i] end
     self.path=path;self.done=true;self.reason='Route calculee sur zones declarees uniquement';return
    end
    self.current=best;closed[best]=true;self.next=1
   end
   local j=self.next;self.next=j+1
   if j>#nodes then self.current=nil
   elseif not closed[j] and j~=self.current and not M.blocked(nodes[self.current],nodes[j],zones,margin) then
    local d=distances[self.current]+distance(nodes[self.current],nodes[j])
    if not distances[j] or d<distances[j] then distances[j]=d;previous[j]=self.current end
   end
  end
 end
 return s
end
function M.new(route,zones,margin,home)
 local s={route=route,zones=zones,margin=margin,home=home,index=1,phase='PREFLIGHT',trace={},events={},paused=false,completed=false}
 function s:event(text) self.events[#self.events+1]=text;if #self.events>64 then table.remove(self.events,1) end end
 function s:pause(why) self.paused=true;self:event(why or 'Pause');self.phase='HOLDING' end
 function s:resume() if not self.completed then self.paused=false;self:event('Reprise demandee') end end
 function s:step(p,v)
  if #self.trace==0 or distance(p,self.trace[#self.trace])>=.5 then self.trace[#self.trace+1]={x=p.x,y=p.y,z=p.z};if #self.trace>256 then table.remove(self.trace,1) end end
  if self.paused or self.completed then return nil end
  local goal=self.route[self.index]
  if not goal then self.completed=true;self.phase='MISSION_COMPLETE';self:event('Arrivee: maintien, pas atterrissage');return nil end
  if not self.planner then self.planner=M.planner(p,goal,self.zones,self.margin);self.segment=2 end
  if not self.planner.done then self.planner:step();self.phase='PREFLIGHT';return nil end
  if self.planner.failed then self:pause(self.planner.reason);return nil end
  local target=self.planner.path[self.segment]
  if not target then self.index=self.index+1;self.planner=nil;return nil end
  if M.blocked(p,target,self.zones,self.margin) then self.planner=nil;self:event('Recalcul depuis position observee');self.phase='PREFLIGHT';return nil end
  local d=distance(p,target);local speed=math.sqrt(v.x^2+v.y^2+v.z^2)
  if d<=.5 and speed<=.1 then self.segment=self.segment+1;return nil end
  self.phase=math.abs(target.y-p.y)>1 and 'CLIMB' or d<3 and 'APPROACH' or 'CRUISE'
  local origin=self.planner.path[self.segment-1]
  local heading
  if self.surface then
   local base=Geometry.atan2(target.x-origin.x,target.z-origin.z)
   local cross=(target.x-p.x)*math.cos(base)-(target.z-p.z)*math.sin(base)
   heading=d<2 and math.deg(Geometry.atan2(target.x-p.x,target.z-p.z)) or math.deg(base)+math.max(-30,math.min(30,math.deg(math.atan(cross/2))))
  end
  return {x=target.x,y=target.y,z=target.z,speed=goal.speed,heading=heading}
 end
 return s
end
return M
