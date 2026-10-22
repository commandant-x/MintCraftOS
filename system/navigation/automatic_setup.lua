-- Passive proposals follow actual kinetic source edges, never nearest shafts.
local addon=require('system.libraries.addon')
local Balloon=require('system.navigation.balloon_setup')
local Drive=require('system.navigation.drivetrain')
local Altitude=require('system.navigation.altitude_model')
local Link=require('system.navigation.link_output')
local M={}
function M.plan(snapshot,control,endpoints)
 local out=addon.copy(control)
 if #(out.channels or {})==0 then
  local p,err=Balloon.plan(snapshot,out,endpoints)
  if not p then return nil,err end
  if not p.reused or p.transmitter=='' then return nil,'Need one existing burner RX frequency and one transmitter; use Vehicle setup' end
  out,err=Balloon.create(out,p,{transmitter=p.transmitter,neutral=0,rescue=0,wiringConfirmed=true,replaceExisting=false})
  if not out then return nil,err end
 end
 -- Legacy duplicate channels can address the same collective receiver.
 if out.balloonSetup and #out.channels>0 and (out.mode~='altitude' or #out.channels>1) then
  local first=out.channels[1] local shared=Link.key(first) local compatible=shared~=nil
  for _,c in ipairs(out.channels) do
   if Link.key(c)~=shared or c.name~=first.name or not c.actuator or c.actuator.role~='buoyancy' or
    not c.mix or not first.mix or c.mix.altitude~=first.mix.altitude or c.rescue~=first.rescue or c.min~=first.min or c.max~=first.max then compatible=false end
   for axis,value in pairs(c.mix or {}) do if axis~='altitude' and value~=0 then compatible=false end end
  end
  if compatible then out.mode='altitude' out.channels={first} end
 end
 if out.mode~='altitude' or not out.balloonSetup then return nil,'Collective burner group required; existing controls preserved' end
 local props={}
 for _,a in ipairs(snapshot.actuators or {}) do if a.geometryValid and math.abs(a.direction.y)<.25 then props[#props+1]=a end end
 local function vertical(reason)
  if out.drivetrain then out.drivetrain.enabled=false end
  return out,'Altitude available; horizontal unavailable: '..reason
 end
 if #props==1 then return vertical('one propeller; no measured independent steering') end
 if out.drivetrain and out.drivetrain.enabled then
  if Drive.validate(out.drivetrain,out.channels) and Drive.observed(out.drivetrain,snapshot) then return out,'Saved motor roles; live tests required' end
  return vertical('saved motor receivers unavailable')
 end
 if #props==0 then return out,'Vertical pilot; no measured horizontal propeller inventory' end
 if #props~=2 then return vertical('no two-group drive mapping') end
 table.sort(props,function(a,b)return a.position.x<b.position.x end)
 local names={} for _,e in ipairs(endpoints) do if e.backend=='frequency' then names[#names+1]=e.name end end
 if #names~=1 then return vertical('select motor transmitter in Motor links') end
 local nodes={} for _,r in ipairs(snapshot.mechanics or {}) do nodes[r.id]=r end
 local d={enabled=true,name=names[1],clutchOff=15,left={},right={}}
 for i,side in ipairs({'left','right'}) do
  local id,seen=props[i].id,{}
  for _=1,128 do
   if not id then break end
   if seen[id] then return vertical('kinetic source cycle; select motor roles once') end seen[id]=true
   local node=nodes[id] if not node then break end
   if node.role~='other' then
    if d[side][node.role] then return vertical('ambiguous '..side..' '..node.role..' chain') end
    local matches={}
    for _,r in ipairs(snapshot.links or {}) do
     local p,q=node.position,r.position
     if r.receiver and math.abs(math.abs(p.x-q.x)+math.abs(p.y-q.y)+math.abs(p.z-q.z)-1)<.01 then matches[#matches+1]=r end
    end
    if #matches~=1 then return vertical('ambiguous RX for '..side..' '..node.role) end
    local r=matches[1]
    d[side][node.role]={first=r.first.item,second=r.second.item,firstColor=r.first.dyedColor,secondColor=r.second.dyedColor}
   end
   id=node.sourceId
  end
 end
 local ok,err=Drive.validate(d,out.channels)
 if not ok then return vertical('incomplete kinetic source chain: '..err) end
 out.drivetrain=d
 return out,'Source-chain roles detected; motion tests required'
end
function M.candidate(report,fingerprint,snapshot)
 if type(report)~='table' or report.schema~=2 or report.state~='complete' then return nil,'No reusable calibration report' end
 if type(fingerprint)~='string' or #fingerprint~=64 or fingerprint~=report.structureFingerprint then return nil,'Structure fingerprint missing/changed: full measurement required' end
 if report.vehicleId~=snapshot.vehicleId or not snapshot.ok or not snapshot.inventoryComplete then return nil,'Vehicle identity/inventory changed' end
 if not addon.finite(report.mass) or report.mass<=0 or not addon.finite(snapshot.mass) or math.abs(report.mass-snapshot.mass)>report.mass*.02 or report.massUnit~=(snapshot.units or {}).mass then return nil,'Mass/unit changed or unmeasured' end
 local model=report.model
 if type(model)~='table' or model.kind~='altitude-table' or not addon.finite(model.r2) or model.r2<.9 or model.r2>1 or type(model.points)~='table' or #model.points<3 then return nil,'Invalid saved altitude model' end
 for i=1,#model.points do local p=model.points[i] if type(p)~="table" then return nil,"Invalid saved altitude point" end end
 local mid=model.points[math.ceil(#model.points/2)]
 if type(mid)~='table' or not Altitude.heatAt(model,mid.altitude) then return nil,'Invalid saved altitude table' end
 local g,d,r=model.gains,model.dynamics,model.measuredRange
 if type(g)~='table' or type(d)~='table' or type(r)~='table' then return nil,'Missing saved dynamics' end
 for _,key in ipairs({'stiffness','damping','heatAcceleration'}) do if not addon.finite(d[key]) or d[key]<=0 then return nil,'Invalid saved dynamics' end end
 if not addon.finite(g.kp) or g.kp<0 or g.kp>2 or g.ki~=0 or not addon.finite(g.kd) or g.kd<0 or g.kd>100 or g.limit~=2 or g.slew~=.25 or g.deadband~=.1 or g.integralLimit~=0 then return nil,'Invalid saved feedback gains' end
 local first,last=model.points[1],model.points[#model.points]
 if r.first~=first.heat or r.last~=last.heat or r.minAltitude~=first.altitude or r.maxAltitude~=last.altitude or last.altitude-first.altitude<4 then return nil,'Invalid measured range' end
 for _,key in ipairs({'hover','neutral','tau'}) do if not addon.finite(model[key]) or model[key]<=0 then return nil,'Invalid saved model parameter' end end
 return addon.copy(model),'Saved table candidate; fresh receiver and flight checks required'
end
function M.motorCandidate(report)
 local rows=report.motorTests
 if type(rows)~='table' or #rows~=60 then return end
 for _,r in ipairs(rows) do
  if type(r)~='table' or (r.side~='left' and r.side~='right') or not addon.finite(r.gear) or r.gear%1~=0 or r.gear<1 or r.gear>15 or (r.reverse~=0 and r.reverse~=15) then return end
  for _,key in ipairs({'forward','yaw','peakSpeed','brakingDistance'}) do if not addon.finite(r[key]) then return end end
 end
 return require('system.navigation.drivetrain').model(rows)
end
return M
