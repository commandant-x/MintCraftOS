function M.signals(meta,values,quant)
 local desiredForce,estimatedForce={},{};local difference=0
 for i,m in ipairs(meta) do
  local g=m.group;desiredForce[i]=values[i]*m.unit
  estimatedForce[i]=quant.spool and Physics.force(quant.spool[g.id],m.pressure,m.axial,m.thrust,m.airflow)*g.members or desiredForce[i]
  difference=difference+desiredForce[i]-estimatedForce[i]
 end
 local slow=0;for _,m in ipairs(meta) do slow=math.max(slow,-.05/math.log(1-m.alpha)) end
 local qmodel={columns={},scale={1,1,1,.1,.1,.1}};local requested={}
 for i,m in ipairs(meta) do
  local g=m.group;local signal,slope
  if g.kind=='linear' or g.kind=='surface' then signal=values[i];slope=1
  else
   local lead=quant.recovering and 1 or math.max(0,(-.05/math.log(1-m.alpha))/(slow/1.4)-1)
   local force=clip(desiredForce[i]+lead*(desiredForce[i]-estimatedForce[i]-difference/#meta)+(quant.verticalFast and 3 or 1)*difference/#meta,0,15*m.unit)
   local rpm=force<=0 and 0 or force/(g.members*m.thrust*m.pressure)+math.max(0,m.axial)/m.airflow
   if quant.refRate and not quant.recovering then
    local referenceAxial=m.axial+.5*(quant.trackingFast and 1 or .5)*(quant.refRate.z*g.x-quant.refRate.x*g.z)
    rpm=rpm+(math.max(0,referenceAxial)-math.max(0,m.axial))/m.airflow
   end
   rpm=clip(rpm,0,g.source);signal=Physics.signal(g.source,rpm)
   slope=-m.thrust*m.pressure*g.source/(signal<1 and 8 or 16)*g.members/(math.max(1e-12,m.unit))
  end
  requested[tostring(g.id)]=clip(signal,0,15)
  local response={}
  for j=1,6 do response[j]=meta[i].column[j]*slope end
  local neutral=math.floor(requested[tostring(g.id)]+.5)
  qmodel.columns[i]={id=tostring(g.id),neutral=neutral,low=-neutral,high=15-neutral,response=response}
 end
 -- Coupled error diffusion, exact in blocks of eight; fixed work for 32 groups.
 local equal,lo,hi=true,math.huge,-math.huge
 for i,m in ipairs(meta) do
  local g=m.group;local base=meta[1].group;local wanted=requested[tostring(g.id)]
  lo=math.min(lo,wanted);hi=math.max(hi,wanted)
  equal=equal and g.kind==base.kind and g.source==base.source and g.sails==base.sails and g.members==base.members
 end
 if equal and hi-lo<.08 then
  local wanted=(lo+hi)/2;local lower=math.floor(wanted)
  quant.collective=(quant.collective or 0)+(wanted-lower)
  local value=lower;if quant.collective>=1 then value=math.min(15,lower+1);quant.collective=quant.collective-1 end
  local out={};for _,m in ipairs(meta) do out[tostring(m.group.id)]=value end
  quant.error=nil;quant.clipped=false;return out
 end
 local target={};for j=1,6 do target[j]=quant.error and quant.error[j] or 0 end
 local choices,selected={},{}
 for i,c in ipairs(qmodel.columns) do
  local wanted=requested[c.id];choices[i]={math.floor(wanted),math.ceil(wanted)};selected[c.id]=math.floor(wanted+.5)
  for j=1,6 do target[j]=target[j]+c.response[j]/qmodel.scale[j]*(wanted-selected[c.id]) end
 end
 for first=1,#meta,8 do
  local last=math.min(#meta,first+7);local base={}
  for j=1,6 do base[j]=target[j] end
  for i=first,last do local c=qmodel.columns[i];for j=1,6 do base[j]=base[j]+c.response[j]/qmodel.scale[j]*(selected[c.id]-c.neutral) end end
  local best,bestError,bestCost
  for mask=0,2^(last-first+1)-1 do
   local residual={};for j=1,6 do residual[j]=base[j] end
   local values={};local cost=0
   for i=first,last do local c=qmodel.columns[i]
    local value=choices[i][math.floor(mask/2^(i-first))%2+1];values[c.id]=value
    cost=cost+1e-10*(value-requested[c.id])^2
    for j=1,6 do residual[j]=residual[j]-c.response[j]/qmodel.scale[j]*(value-c.neutral) end
   end
   for j=1,6 do cost=cost+residual[j]^2 end
   if not bestCost or cost<bestCost then best,bestError,bestCost=values,residual,cost end
  end
  for id,value in pairs(best) do selected[id]=value end;target=bestError
 end
 quant.clipped=false
 for j=1,6 do if math.abs(target[j])>64 then quant.clipped=true end;target[j]=clip(target[j],-64,64) end
 quant.error=target;quant.scale=qmodel.scale
 return selected
end

