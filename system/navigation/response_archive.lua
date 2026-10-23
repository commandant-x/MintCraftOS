-- Historical data can nominate a model; only new service-owned trials can arm it.
local A=require('system.libraries.addon')
local C=require('system.ascendancy.contracts')
local R=require('system.navigation.response_model')
local SafeWrite=require('system.libraries.safe_write')
local M={}
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for key,value in pairs(a) do if not same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end return true
end
local function bindings(rows)
 if type(rows)~='table' or #rows<1 or #rows>32 then return end
 local out={} local seen={}
 for _,row in ipairs(rows) do
  if type(row)~='table' or type(row.id)~='string' or seen[row.id] then return end seen[row.id]=true
  local copy=A.copy(row) copy.validated=nil out[#out+1]=copy
 end
 table.sort(out,function(a,b) return a.id<b.id end) return out
end
local function inertia(value)
 if type(value)~='table' or #value~=3 then return false end
 for i=1,3 do
  if type(value[i])~='table' or #value[i]~=3 then return false end
  for j=1,3 do if not A.finite(value[i][j]) then return false end end
 end
 for i=1,3 do for j=1,3 do if math.abs(value[i][j]-value[j][i])>1e-8*math.max(1,math.abs(value[i][j]),math.abs(value[j][i])) then return false end end end
 local a,b,c=value[1][1],value[1][2],value[1][3]
 local d,e,f=value[2][2],value[2][3],value[3][3]
 return a>0 and a*d-b*b>0 and a*(d*f-e*e)-b*(b*f-e*c)+c*(b*e-d*c)>0
end
function M.physicalChanged(before,after)
 if not before or not after then return 'Physical metadata unavailable' end
 local a,b=inertia(before.inertia),inertia(after.inertia)
 if a~=b or a and (before.units or {}).inertia~=(after.units or {}).inertia then return 'Observed inertia availability/unit changed' end
 if a and b then for i=1,3 do for j=1,3 do
  local scale=math.max(math.abs(before.inertia[i][j]),math.sqrt(before.inertia[i][i]*before.inertia[j][j])*1e-6)
  if math.abs(before.inertia[i][j]-after.inertia[i][j])>scale*.005 then return 'Observed inertia changed' end
 end end end
 local x,y=A.vec(before.centerOfMass),A.vec(after.centerOfMass)
 if (x~=nil)~=(y~=nil) then return 'Center of mass observation availability changed' end
 if x and y then for _,axis in ipairs({'x','y','z'}) do if math.abs(x[axis]-y[axis])>.01 then return 'Observed center of mass changed' end end end
end
function M.physicalReference(snapshot)
 return {inertia=A.copy(snapshot.inertia),centerOfMass=A.copy(snapshot.centerOfMass),units=A.copy(snapshot.units)}
end
function M.verticalBindingsEqual(a,b)
 if type(a)~='table' or type(b)~='table' then return false end
 a=A.copy(a) b=A.copy(b) a.drivetrain=nil b.drivetrain=nil return same(a,b)
end
function M.motorBindingsEqual(a,b)
 return type(a)=='table' and type(b)=='table' and type(a.drivetrain)=='table' and same(a.drivetrain,b.drivetrain)
end
function M.load(path)
 local recovered,problem=SafeWrite.recover(path) if not recovered then return nil,problem end
 if not fs.exists(path) then return nil,'No historical response archive' end
 if fs.isDir(path) or not fs.getSize or fs.getSize(path)>32768 then return nil,'Historical response archive exceeds its storage budget' end
 local h=fs.open(path,'r') if not h then return nil,'Historical response archive unavailable' end
 local ok,text=pcall(h.readAll) pcall(h.close)
 if not ok or type(text)~='string' or #text>32768 then return nil,'Historical response archive read refused' end
 local decoded,value=pcall(textutils.unserialize,text)
 if not decoded then return nil,'Historical response archive malformed' end
 return C.clone(value)
end
function M.candidate(report,channels,snapshot,fingerprint)
 local copy,why=C.clone(report) if not copy then return nil,why end report=copy
 if type(report)~='table' or report.schema~=2 or report.kind~='known-output-characterization-not-flight-certificate' or
  type(report.qualification)~='table' or report.qualification.state~='complete' then return nil,'No historical closed-loop response model' end
 if not snapshot or not snapshot.ok or not snapshot.inventoryComplete or report.vehicleId~=snapshot.vehicleId then return nil,'Response archive vehicle identity/inventory differs' end
 if type(fingerprint)~='string' or #fingerprint~=64 or not fingerprint:match('^[0-9a-f]+$') or fingerprint~=report.structureFingerprint then return nil,'Response archive structure missing/changed' end
 if not A.finite(report.mass) or report.mass<=0 or not A.finite(snapshot.mass) or snapshot.mass<=0 or math.abs(report.mass-snapshot.mass)>report.mass*.005 or
  type(report.massUnit)~='string' or report.massUnit=='' or report.massUnit~=(snapshot.units or {}).mass then return nil,'Response archive mass/unit missing/changed' end
 if not inertia(report.inertia) or not inertia(snapshot.inertia) or type(report.inertiaUnit)~='string' or report.inertiaUnit=='' or report.inertiaUnit~=(snapshot.units or {}).inertia then return nil,'Response archive inertia/unit unmeasured/changed' end
 for i=1,3 do for j=1,3 do
  local scale=math.max(math.abs(report.inertia[i][j]),math.sqrt(report.inertia[i][i]*report.inertia[j][j])*1e-6)
  if math.abs(report.inertia[i][j]-snapshot.inertia[i][j])>scale*.005 then return nil,'Response archive inertia changed' end
 end end
 local before,after=A.vec(report.centerOfMass),A.vec(snapshot.centerOfMass)
 if not before or not after then return nil,'Response archive center of mass unmeasured' end
 for _,axis in ipairs({'x','y','z'}) do if math.abs(before[axis]-after[axis])>.01 then return nil,'Response archive center of mass changed' end end
 local old,new=bindings(report.binding),bindings(channels)
 if not old or not new or not same(old,new) then return nil,'Response archive command binding changed' end
 local provenance=report.model and report.model.provenance
 if type(provenance)~='table' or provenance.clock~='local_uptime' or type(provenance.clockId)~='string' or #provenance.clockId<1 or
  provenance.clockId~=report.observationClockId then return nil,'Response archive derivative provenance missing' end
 local model,issue=R.fit(channels,report.observations,provenance)
 if not model then return nil,issue end
 if not model.motionDomain or not A.finite(model.authority.condition) or model.authority.condition>1000 then return nil,'Historical response motion domain or conditioning is insufficient' end
 local usable=false for _,axis in ipairs(R.axes) do if model.axes[axis].allocatable then usable=true end end
 if not usable then return nil,'Historical responses do not identify an independently controllable axis' end
 return {model=model,observations=report.observations,sourceClockId=provenance.clockId,archivedAt=report.archivedAt},
  'Historical response candidate only; fresh neutral, RX and closed-loop motion/return qualification required'
end
return M
