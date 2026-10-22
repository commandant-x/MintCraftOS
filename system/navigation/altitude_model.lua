-- Actual settled height table + independently checked restoring/damping model.
-- Never infer horizontal control, manual takeover, or physical rescue behaviour.
local addon=require('system.libraries.addon')
local M={}
function M.heatAt(model,height)
 local points=type(model)=='table' and model.points
 if type(points)~='table' or #points<3 or #points>15 or not addon.finite(height) then return nil,'Measured altitude table unavailable' end
 for i,p in ipairs(points) do
  if not addon.finite(p.altitude) or not addon.finite(p.heat) or p.heat<1 or p.heat>15 or p.heat%1~=0 or
    i>1 and (p.altitude<=points[i-1].altitude or p.heat<=points[i-1].heat) then return nil,'Invalid measured altitude table' end
 end
 if height<points[1].altitude or height>points[#points].altitude then return nil,'Target outside measured altitude range' end
 for i=2,#points do
  local a,b=points[i-1],points[i]
  if height<=b.altitude then return a.heat+(b.heat-a.heat)*(height-a.altitude)/(b.altitude-a.altitude) end
 end
end
local function fit(rows)
 if #rows<20 then return nil end
 local mean={0,0,0,0}
 for _,r in ipairs(rows) do for i=1,4 do mean[i]=mean[i]+r[i]/#rows end end
 local matrix={{0,0,0,0},{0,0,0,0},{0,0,0,0}}
 local scale={0,0,0}
 for _,r in ipairs(rows) do for i=1,3 do scale[i]=scale[i]+(r[i]-mean[i])^2 end end
 for i=1,3 do scale[i]=math.sqrt(scale[i]) if scale[i]<1e-8 then return nil end end
 for _,r in ipairs(rows) do for i=1,3 do
  local x=(r[i]-mean[i])/scale[i]
  for j=1,3 do matrix[i][j]=matrix[i][j]+x*(r[j]-mean[j])/scale[j] end
  matrix[i][4]=matrix[i][4]+x*(r[4]-mean[4])
 end end
 for i=1,3 do
  local pivot=i for j=i+1,3 do if math.abs(matrix[j][i])>math.abs(matrix[pivot][i]) then pivot=j end end
  matrix[i],matrix[pivot]=matrix[pivot],matrix[i]
  local d=matrix[i][i] if math.abs(d)<1e-5 then return nil end
  for j=i,4 do matrix[i][j]=matrix[i][j]/d end
  for k=1,3 do if k~=i then local f=matrix[k][i] for j=i,4 do matrix[k][j]=matrix[k][j]-f*matrix[i][j] end end end
 end
 local out={matrix[1][4]/scale[1],matrix[2][4]/scale[2],matrix[3][4]/scale[3],mean[4]}
 for i=1,3 do out[4]=out[4]-out[i]*mean[i] end
 for _,v in ipairs(out) do if not addon.finite(v) then return nil end end
 return out
end
function M.analyze(samples,levels,options)
 local points={}
 for heat=options.first,options.last do
  local level=levels[heat]
  if not level or not level.settled or not addon.finite(level.altitude) then return nil,'Every heat level needs a measured stable height' end
  if #points>0 and level.altitude-points[#points].altitude<0.5 then return nil,'Stable heights not distinctly increasing; ground contact, inertia or non-monotonic response: retain measurements' end
  points[#points+1]={heat=heat,altitude=level.altitude,spread=level.altitudeSpread}
 end
 local rows={}
 for i=2,#samples do
  local a,b=samples[i-1],samples[i] local dt=b.time-a.time
  if a.signal==b.signal and dt>=0.2 and dt<=1 then
   rows[#rows+1]={(a.altitude+b.altitude)/2,(a.rate+b.rate)/2,b.signal,(b.rate-a.rate)/dt}
  end
 end
 local model=fit(rows)
 if not model then return nil,'Height/speed/heat dynamics not identifiable; stable heights retained' end
 local mean=0 for _,r in ipairs(rows) do mean=mean+r[4]/#rows end
 local residual,total=0,0
 for _,r in ipairs(rows) do
  residual=residual+(r[4]-model[1]*r[1]-model[2]*r[2]-model[3]*r[3]-model[4])^2
  total=total+(r[4]-mean)^2
 end
 local r2=total>1e-8 and 1-residual/total or 0
 if r2<0.9 then return nil,'Height response too noisy/nonlinear for automatic hold; stable heights retained' end
 local train,hold={},{}
 for i,r in ipairs(rows) do if i<=math.floor(#rows*0.7) then train[#train+1]=r else hold[#hold+1]=r end end
 local cross=fit(train) if not cross then return nil,'Independent dynamics validation unavailable' end
 local mse=0 for _,r in ipairs(hold) do mse=mse+(r[4]-cross[1]*r[1]-cross[2]*r[2]-cross[3]*r[3]-cross[4])^2 end
 if math.sqrt(mse/math.max(1,#hold))>0.01+0.2*math.sqrt(total/#rows) then return nil,'Height response changed during sweep' end
 local stiffness,damping,force=-model[1],-model[2],model[3]
 if stiffness<=1e-5 or damping<=0 or force<=0 then return nil,'No restoring altitude/damped heat response identified' end
 local kp=0.25*stiffness/force
 local kd=math.max(0,(2*math.sqrt(1.25*stiffness)-damping)/force)
 if not addon.finite(kp) or not addon.finite(kd) or kp>2 or kd>100 then return nil,'Measured response outside supported hold sensitivity' end
 -- Settled heights and dynamic equilibrium must agree; a transient at zero
 -- velocity is not sufficient evidence for an automatic equilibrium controller.
 for _,p in ipairs(points) do
  local predicted=(force*p.heat+model[4])/stiffness
  if math.abs(predicted-p.altitude)>math.max(0.5,0.05*(points[#points].altitude-points[1].altitude)) then
   return nil,'Stable-height table disagrees with dynamic equilibrium; repeat measurements'
  end
 end
 local neutral=math.floor((options.first+options.last)/2)
 return {kind='altitude-table',points=points,hover=neutral,neutral=neutral,tau=1/damping,r2=r2,
  dynamics={stiffness=stiffness,damping=damping,heatAcceleration=force},
  measuredRange={first=options.first,last=options.last,minAltitude=points[1].altitude,maxAltitude=points[#points].altitude},
  gains={kp=kp,ki=0,kd=kd,limit=2,slew=0.25,integralLimit=0,deadband=0.1},
  note='Measured altitude interpolation + restoring/damping feedback. No horizontal route or metre-accuracy guarantee.'}
end
return M
