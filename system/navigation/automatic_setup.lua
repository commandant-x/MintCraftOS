-- Passive proposals follow actual kinetic source edges, never nearest shafts.
local addon=require('system.libraries.addon')
local Balloon=require('system.navigation.balloon_setup')
local Drive=require('system.navigation.drivetrain')
local Altitude=require('system.navigation.altitude_model')
local Link=require('system.navigation.link_output')
local M={}
function M.plan(snapshot,control,endpoints)
 local out=addon.copy(control)
 local groups=require('system.navigation.equipment_groups').discover(snapshot)
 local names={} for _,e in ipairs(endpoints) do if e.backend=='frequency' then names[#names+1]=e.name end end
 local burnerLink,burnerIssue=require('system.navigation.equipment_groups').burnerLink(groups)
 if not burnerLink and #groups.burnerIds>0 then
  local selected={} for _,id in ipairs((out.balloonSetup or {}).burnerIds or {}) do selected[id]=true end
  for _,id in ipairs(groups.burnerIds) do if not selected[id] then return nil,'Cannot group burner '..id..': '..tostring(burnerIssue),groups end end
 end
 local freshVehicle=out.balloonSetup and out.balloonSetup.vehicleId~=snapshot.vehicleId
 if #(out.channels or {})==0 then
  if not burnerLink or #names~=1 then return nil,burnerIssue or 'Need detected burner receivers and one transmitter',groups end
  local plan={vehicleId=snapshot.vehicleId,burnerIds=groups.burnerIds,endpoints=names,frequency=burnerLink}
  local err
  out,err=Balloon.create(out,plan,{transmitter=names[1],neutral=0,rescue=0,wiringConfirmed=true,replaceExisting=false})
  if not out then return nil,err,groups end
 else
  local first=out.channels[1] local compatible=first.backend=='frequency' and first.mix~=nil
  for _,c in ipairs(out.channels) do
   if c.backend~='frequency' or c.name~=first.name or not c.actuator or c.actuator.role~='buoyancy' or
    not c.mix or not first.mix or c.mix.altitude~=first.mix.altitude or c.rescue~=first.rescue or c.min~=first.min or c.max~=first.max then compatible=false end
   for axis,value in pairs(c.mix or {}) do if axis~='altitude' and value~=0 then compatible=false end end
  end
  if compatible and (burnerLink or Link.key(first) and #out.channels>0) then
   local specs={} for _,c in ipairs(out.channels) do for _,f in ipairs(Link.specs(c) or {}) do specs[#specs+1]={first=f.first,second=f.second,firstColor=f.firstColor,secondColor=f.secondColor} end end
   local combined=burnerLink or Link.combine(specs)
   if combined then
    first.link=combined out.mode='altitude' out.channels={first}
    if burnerLink then out.balloonSetup={vehicleId=snapshot.vehicleId,burnerIds=addon.copy(groups.burnerIds),wiringConfirmed=true} end
   end
  end
 end
 if out.mode~='altitude' or not out.balloonSetup then return nil,'Collective burner group required; existing controls preserved',groups end
 if freshVehicle and out.drivetrain then out.drivetrain.enabled=false end
 -- A burner/motor frequency conflict cannot be isolated by software.
 local heatKeys={}
 for _,c in ipairs(out.channels) do for _,k in ipairs(Link.keys(c)) do heatKeys[k]=true end end
 for _,g in ipairs(groups.motors) do for _,f in pairs(g.roles) do
  if heatKeys[Link.key({link=f})] then return nil,'Burner and motor share a frequency; separate their commands',groups end
 end end
 local function vertical(reason)
  if out.drivetrain then out.drivetrain.enabled=false end
  return out,'Altitude available; horizontal unavailable: '..reason,groups
 end
 if #groups.unmappedMotors==0 and #groups.motors==1 then return vertical('one motor command group; no independent steering') end
 local props=0 for _,p in ipairs(snapshot.actuators or {}) do if p.geometryValid and math.abs(p.direction.y)<.25 then props=props+1 end end
 if props==1 then return vertical('one propeller; no measured independent steering') end
 if out.drivetrain and out.drivetrain.enabled then
  if Drive.validate(out.drivetrain,out.channels) and Drive.observed(out.drivetrain,snapshot) then return out,'Saved motor groups; live tests required',groups end
  return vertical('saved motor receivers unavailable')
 end
 if props==0 then return vertical('no measured horizontal propellers') end
 if #names~=1 then return vertical('select motor transmitter') end
 local d,err=require('system.navigation.equipment_groups').drive(groups,names[1])
 if not d then return vertical(err) end
 local ok,issue=Drive.validate(d,out.channels)
 if not ok then return vertical(issue) end
 out.drivetrain=d
 return out,'Motor banks grouped; actual motion tests required',groups
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
