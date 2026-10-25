-- Six-axis identification and bounded allocation for explicitly assigned outputs.
-- Pure mathematics: no peripheral access, output writes or client certificates.
local A=require('system.libraries.addon')
local Authority=require('system.navigation.authority')
local G=require('system.navigation.geometry')
local M={}
M.axes={'forward','right','vertical','pitch','yaw','roll'}
local floors={.01,.01,.01,.1,.1,.1}
local function vector(v)
 if type(v)~='table' or #v~=6 then return end
 local out={} for i=1,6 do if not A.finite(v[i]) then return end out[i]=v[i] end return out
end
local function sequence(t,limit)
 if type(t)~='table' or getmetatable(t) or #t<1 or #t>limit then return false end
 local n=0 for k in pairs(t) do if type(k)~='number' or k%1~=0 or k<1 or k>#t then return false end n=n+1 end
 return n==#t
end
local function id(s) return type(s)=='string' and #s>0 and #s<=192 and not s:find('%c') end
-- Coordinate descent solves the normalized box-constrained least-squares
-- problem. The iteration budget is fixed; a residual is always returned.
function M.allocate(model,wanted)
 wanted=vector(wanted)
 if not wanted or type(model)~='table' or not sequence(model.columns,32) or not vector(model.scale) then return nil,'Invalid allocation input' end
 local normalized,residual,outputs,columns,seen={},{},{},{},{}
 for i=1,6 do
  if model.scale[i]<=0 then return nil,'Invalid response scale' end
  normalized[i]=wanted[i]/model.scale[i] residual[i]=normalized[i]
  if not A.finite(normalized[i]) then return nil,'Allocation magnitude outside numeric domain' end
 end
 for j,c in ipairs(model.columns) do
  if type(c)~='table' then return nil,'Malformed actuator column' end
  local values=vector(c.response)
  if not values or not id(c.id) or seen[c.id] or not A.finite(c.low) or not A.finite(c.high) or c.low>0 or c.high<0 or c.high-c.low>15 then return nil,'Invalid actuator bounds' end
  seen[c.id]=true
  local v={} local norm=0
  for i=1,6 do v[i]=values[i]/model.scale[i] norm=norm+v[i]^2 end
  if not A.finite(norm) then return nil,'Response magnitude outside numeric domain' end
  columns[j]={v=v,norm=norm,low=c.low,high=c.high} outputs[j]=0
 end
 -- A regularized six-axis least-squares seed preserves collective directions
 -- when torque columns dwarf translation (e.g. low-inertia multicopters).
 -- Box projection plus the existing descent still enforces actuator bounds.
 local gram,peak={},0
 for i=1,6 do gram[i]={};for k=1,6 do local sum=0;for _,c in ipairs(columns) do sum=sum+c.v[i]*c.v[k] end;gram[i][k]=sum;peak=math.max(peak,math.abs(sum)) end;gram[i][7]=normalized[i] end
 if not A.finite(peak) then return nil,'Response Gram overflow' end
 -- Preserve the established descent solution when the collective is already
 -- well conditioned; a different null-space seed can worsen heterogeneous PWM.
 if gram[3][3]>0 and peak/gram[3][3]>100 then
 for i=1,6 do gram[i][i]=gram[i][i]+math.max(1,peak)*1e-10 end
 for i=1,6 do
  local pivot=i;for row=i+1,6 do if math.abs(gram[row][i])>math.abs(gram[pivot][i]) then pivot=row end end
  gram[i],gram[pivot]=gram[pivot],gram[i]
  local divisor=gram[i][i];for k=i,7 do gram[i][k]=gram[i][k]/divisor end
  for row=1,6 do if row~=i then local factor=gram[row][i];for k=i,7 do gram[row][k]=gram[row][k]-factor*gram[i][k] end end end
 end
 for j,c in ipairs(columns) do local value=0;for i=1,6 do value=value+c.v[i]*gram[i][7] end;outputs[j]=math.max(c.low,math.min(c.high,value));for i=1,6 do residual[i]=residual[i]-c.v[i]*outputs[j] end end
 end
 for _=1,96 do
  local largest=0
  for j,c in ipairs(columns) do
   local dot=0 for i=1,6 do dot=dot+c.v[i]*residual[i] end
   local old=outputs[j]
   local value=c.norm>1e-12 and math.max(c.low,math.min(c.high,old+dot/c.norm)) or 0
   local delta=value-old outputs[j]=value largest=math.max(largest,math.abs(delta))
   for i=1,6 do residual[i]=residual[i]-c.v[i]*delta end
  end
  if largest<1e-8 then break end
 end
 local actual,signals={},{} local error=0 local saturated=false
 for i=1,6 do
  actual[i]=0 for j,c in ipairs(model.columns) do actual[i]=actual[i]+c.response[i]*outputs[j] end
  if not A.finite(actual[i]) then return nil,'Allocated response outside numeric domain' end
  error=math.max(error,math.abs(residual[i]))
 end
 for j,c in ipairs(model.columns) do
  signals[c.id]=outputs[j]
  if math.abs(outputs[j]-c.low)<1e-6 or math.abs(outputs[j]-c.high)<1e-6 then saturated=true end
 end
 return {delta=signals,actual=actual,normalizedResidual=error,saturated=saturated}
end
-- Coupled error diffusion for 16-level hardware. Select integer outputs jointly
-- in response space, rather than rounding each coupled motor independently.
function M.quantize(model,values,state)
 if type(values)~='table' or type(state)~='table' or not model or not sequence(model.columns,32) or not vector(model.scale) then return nil,'Invalid quantizer input' end
 local error=state.error and vector(state.error) or {0,0,0,0,0,0}
 if not error then return nil,'Invalid quantizer history' end
 local columns,selected={},{}
 if state.scale then
  local old=vector(state.scale) if not old then return nil,'Invalid quantizer scale history' end
  for i=1,6 do error[i]=error[i]*old[i]/model.scale[i] end
 end
 for j,col in ipairs(model.columns) do
  if type(col)~='table' or not vector(col.response) or not A.finite(col.neutral) or col.neutral%1~=0 or not A.finite(col.low) or not A.finite(col.high) or col.low%1~=0 or col.high%1~=0 or col.low>0 or col.high<0 or col.low< -15 or col.high>15 then return nil,'Invalid integer output domain' end
  local wanted=values[col.id]
  if not A.finite(wanted) or wanted<col.neutral+col.low-1e-8 or wanted>col.neutral+col.high+1e-8 then return nil,'Quantizer demand outside measured output bounds' end
  local c={low=col.low,high=col.high,values={},norm=0}
  for i=1,6 do
   if not A.finite(model.scale[i]) or model.scale[i]<=0 then return nil,'Invalid quantizer response scale' end
   c.values[i]=col.response[i]/model.scale[i] c.norm=c.norm+c.values[i]^2
   error[i]=error[i]+c.values[i]*(wanted-col.neutral)
   if not A.finite(error[i]) or not A.finite(c.norm) then return nil,'Quantizer numeric domain exceeded' end
  end
  columns[j]=c selected[j]=0
 end
 local clipped=false
 for i=1,6 do if math.abs(error[i])>64 then error[i]=math.max(-64,math.min(64,error[i])) clipped=true end end
 for _=1,16 do
  local changed=false
  for j,c in ipairs(columns) do
   local dot=0 for i=1,6 do dot=dot+c.values[i]*error[i] end
   local nextValue=c.norm>1e-12 and math.max(c.low,math.min(c.high,math.floor(selected[j]+dot/c.norm+.5))) or 0
   local delta=nextValue-selected[j]
   if delta~=0 then changed=true selected[j]=nextValue for i=1,6 do error[i]=error[i]-c.values[i]*delta end end
  end
  if not changed then break end
 end
 local result={}
 for j,col in ipairs(model.columns) do result[col.id]=col.neutral+selected[j] end
 state.error=error state.scale=A.copy(model.scale) state.clipped=clipped
 return result
end
-- Rotate the measured body columns into a single WORLD allocation frame.
-- No forward/up assumption is made about the vehicle's initial orientation.
function M.orient(model,orientation)
 local q=G.orientation(orientation)
 if not q or not model or not sequence(model.columns,32) then return nil,'Known body orientation and measured columns required' end
 local out={columns={},scale={.01,.01,.01,.1,.1,.1},frame='world_acceleration_and_world_rotation_vectors'}
 for _,col in ipairs(model.columns) do
  local values=vector(col.response) if not values then return nil,'Malformed measured response' end
  local function rotate(x,y,z)
   return G.transform({x=x,y=y,z=z},{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q})
  end
  local l,r=rotate(values[2],values[3],values[1]),rotate(values[4],values[5],values[6])
  if not l or not r then return nil,'Response rotation invalid' end
  local c=A.copy(col) c.response={l.z,l.x,l.y,r.x,r.y,r.z}
  out.columns[#out.columns+1]=c
  for i=1,6 do out.scale[i]=math.max(out.scale[i],math.abs(c.response[i])) end
 end
 return out
end
function M.fit(channels,observations,provenance)
 if not sequence(channels,32) or not sequence(observations,64) or type(provenance)~='table' or not id(provenance.vehicleId) or
  provenance.frame~='body_orientation_at_neutral_reference' or provenance.translationUnit~='block/s2' or provenance.rotationUnit~='deg/s2' then return nil,'Explicit vehicle, frame and response units required' end
 local channelIds,groups={},{}
 for _,c in ipairs(channels) do
  if not id(c.id) or channelIds[c.id] then return nil,'Duplicate/invalid assigned output' end
  for _,k in ipairs({'min','max','neutral','rescue'}) do if not A.finite(c[k]) or c[k]%1~=0 or c[k]<0 or c[k]>15 then return nil,'Invalid output domain' end end
  if c.min>c.max or c.neutral<c.min or c.neutral>c.max or c.rescue<c.min or c.rescue>c.max then return nil,'Output outside domain' end
  channelIds[c.id]=c groups[c.id]={}
 end
 for _,o in ipairs(observations) do
  if type(o)~='table' then return nil,'Malformed response observation' end
  local c=channelIds[o.id] local mean,noise=vector(o.response),vector(o.noise)
  if not c or not mean or not noise or not A.finite(o.signal) or o.signal%1~=0 or o.signal==c.neutral or o.signal<c.min or o.signal>c.max or
   not A.finite(o.samples) or o.samples<4 or o.samples>4096 or not A.finite(o.baselineSamples) or o.baselineSamples<4 or o.baselineSamples>4096 or
   not A.finite(o.after) or not A.finite(o.first) or not A.finite(o.last) or o.after<0 or o.first<=o.after or o.last<=o.first or
   o.vehicleId~=provenance.vehicleId or o.singleCommand~=true or o.otherOutputsChanged~=false then return nil,'Complete post-ACK isolated response observations required' end
  if provenance.clockId and (o.clockId~=provenance.clockId or o.clock~=provenance.clock or o.frame~=provenance.frame or o.translationUnit~=provenance.translationUnit or o.rotationUnit~=provenance.rotationUnit) then return nil,'Response provenance differs across derivative intervals' end
  for i=1,6 do if noise[i]<0 then return nil,'Negative measurement spread' end end
  local sign=o.signal>c.neutral and 'positive' or 'negative'
  if groups[o.id][sign] then return nil,'Duplicate response side' end groups[o.id][sign]=o
 end
 local model={schema=1,kind='measured-output-response',vehicleId=provenance.vehicleId,frame=provenance.frame,
  translationUnit=provenance.translationUnit,rotationUnit=provenance.rotationUnit,columns={},scale={0,0,0,0,0,0},
  rejected={},provenance=A.copy(provenance),scope='local-observed-output-domain; closed-loop qualification required'}
 for _,c in ipairs(channels) do
  local g=groups[c.id] local positive,negative=g.positive,g.negative
  local usable=(c.neutral==c.max or positive~=nil) and (c.neutral==c.min or negative~=nil)
  local response,noise={},{}
  for i=1,6 do
   local slopes,spreads={},{}
   for _,o in ipairs({positive or false,negative or false}) do if o then
    local delta=o.signal-c.neutral slopes[#slopes+1]=o.response[i]/delta spreads[#spreads+1]=o.noise[i]/math.abs(delta)
   end end
   local value,spread=slopes[1] or 0,spreads[1] or 0
   if #slopes==2 then
    if math.abs(slopes[1]-slopes[2])>math.max(floors[i],3*(spreads[1]+spreads[2]),.35*math.max(math.abs(slopes[1]),math.abs(slopes[2]))) then usable=false end
    value=(slopes[1]+slopes[2])/2 spread=math.max(spreads[1],spreads[2])
   end
   response[i]=value noise[i]=spread
   if not A.finite(value) or not A.finite(spread) then usable=false end
  end
  if usable then
   -- Never extrapolate to signals not exercised during this characterization.
   local low=negative and negative.signal-c.neutral or 0 local high=positive and positive.signal-c.neutral or 0
   local col={id=c.id,neutral=c.neutral,rescue=c.rescue,low=low,high=high,response=response,noise=noise}
   model.columns[#model.columns+1]=col
   for i=1,6 do model.scale[i]=math.max(model.scale[i],math.abs(response[i])) end
  else model.rejected[#model.rejected+1]={id=c.id,reason='Missing signed observation or contradictory local response'} end
 end
 if #model.columns==0 then return nil,'No consistent measured output column' end
 local matrix={}
 for _,c in ipairs(model.columns) do local values={} for i,axis in ipairs(M.axes) do values[axis]=c.response[i] end matrix[#matrix+1]={id=c.id,values=values} end
 local authority,why=Authority.identify(M.axes,matrix) if not authority then return nil,why end
 model.authority=authority model.axes={}
 local domain={excursion={0,0,0,0,0,0},maxRate={0,0,0,0,0,0},worldExcursion={0,0,0,0,0,0},worldMaxRate={0,0,0,0,0,0},delay=0,sampleInterval=0} local completeDomain=true
 for _,o in ipairs(observations) do
  local extent,rates=vector(o.excursion),vector(o.maxRate)
  local worldExtent,worldRates=vector(o.worldExcursion),vector(o.worldMaxRate)
  if not extent or not rates or not worldExtent or not worldRates then completeDomain=false else
   for i=1,6 do
    if extent[i]<0 or rates[i]<0 or worldExtent[i]<0 or worldRates[i]<0 then completeDomain=false end
    domain.excursion[i]=math.max(domain.excursion[i],extent[i]) domain.maxRate[i]=math.max(domain.maxRate[i],rates[i])
    domain.worldExcursion[i]=math.max(domain.worldExcursion[i],worldExtent[i]) domain.worldMaxRate[i]=math.max(domain.worldMaxRate[i],worldRates[i])
   end
   domain.delay=math.max(domain.delay,o.first-(A.finite(o.appliedAt) and o.appliedAt or o.after))
   domain.sampleInterval=math.max(domain.sampleInterval,(o.last-o.first)/(o.samples-1))
  end
 end
 if completeDomain then model.motionDomain=domain end
 for i=1,6 do model.scale[i]=math.max(floors[i],model.scale[i]) end
 for i,axis in ipairs(M.axes) do
  local observable=authority.axes[axis].independent
  local amplitude=math.max(floors[i],model.scale[i]*.1)
  local worst=0
  for _,sign in ipairs({-1,1}) do
   local demand={0,0,0,0,0,0} demand[i]=sign*amplitude
   local allocation=M.allocate(model,demand)
   worst=math.max(worst,allocation.normalizedResidual)
  end
  local noise=0 for _,c in ipairs(model.columns) do noise=math.max(noise,c.noise[i]) end
  local clear=authority.axes[axis].peak>=math.max(floors[i],3*noise)
  model.axes[axis]={observable=observable and clear,allocatable=observable and clear and worst<=.005,
   testAmplitude=amplitude,residual=worst,noise=noise,
   reason=not observable and 'No independent measured response' or not clear and 'Response below observed noise' or worst>.005 and 'Opposite signed corrections infeasible in observed output bounds' or 'Local bidirectional allocation; closed-loop test still required'}
 end
 return model
end
return M
