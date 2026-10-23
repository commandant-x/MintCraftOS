-- Passive identification during existing attitude trials, with no extra pulse.
-- Empirical lateral dynamics: a_h - a_y*u_h/u_y = B*u_h/u_y + D*v_h + wind.
local A=require('system.libraries.addon')
local G=require('system.navigation.geometry')
local C=require('system.ascendancy.contracts')
local M={}
local function rotate(v,q)
 return G.transform(v,{position={x=0,y=0,z=0},rotationPoint={x=0,y=0,z=0},scale={x=1,y=1,z=1},orientation=q})
end
function M.new(vehicleId,reference)
 local q=G.orientation(reference) if not q then return nil,'Tilt reference orientation unavailable' end
 local self={vehicleId=vehicleId,upBody=G.bodyVector({x=0,y=1,z=0},q),n=0,x={0,0,0,0},y={0,0},xx={},xy={},yy={0,0},
  extent={0,0},rates={0,0},ratio={0,0},reason='Need independent tilt and velocity observations'}
 for i=1,4 do self.xx[i]={0,0,0,0} self.xy[i]={0,0} end
 function self:observe(k,pose,ack,now)
  if ack~=true or self.n>=4096 or not C.fresh(k,now) or k.available~=true or k.vehicleId~=self.vehicleId or k.frame~='world' or
   not k.units or k.units.acceleration~='block/s2' or k.units.velocity~='block/s' or not pose or pose.vehicleId~=self.vehicleId or pose.inSublevel~=true or pose.frame~='world' or
   not A.finite(pose.timestamp) or pose.timestamp>now or now-pose.timestamp>.5 then return end
  if self.last and k.observedAt<=self.last then return end self.last=k.observedAt
  local orientation=G.orientation(pose.logicalPose and pose.logicalPose.orientation)
  local p,v,a=A.vec(k.position),A.vec(k.velocity),A.vec(k.acceleration)
  local up=orientation and rotate(self.upBody,orientation)
  if not p or not v or not a or not up or up.y<.95 then return end
  self.origin=self.origin or p
  local x={up.x/up.y,up.z/up.y,v.x,v.z}
  local y={a.x-a.y*x[1],a.z-a.y*x[2]}
  for _,value in ipairs(x) do if not A.finite(value) then return end end
  for _,value in ipairs(y) do if not A.finite(value) then return end end
  local n=self.n+1 local dx,dy={},{}
  for i=1,4 do dx[i]=x[i]-self.x[i] self.x[i]=self.x[i]+dx[i]/n end
  for j=1,2 do dy[j]=y[j]-self.y[j] self.y[j]=self.y[j]+dy[j]/n self.yy[j]=self.yy[j]+dy[j]*(y[j]-self.y[j]) end
  for i=1,4 do
   for j=1,4 do self.xx[i][j]=self.xx[i][j]+dx[i]*(x[j]-self.x[j]) end
   for j=1,2 do self.xy[i][j]=self.xy[i][j]+dx[i]*(y[j]-self.y[j]) end
  end
  self.n=n
  self.ratio[1]=math.max(self.ratio[1],math.abs(x[1])) self.ratio[2]=math.max(self.ratio[2],math.abs(x[2]))
  self.extent[1]=math.max(self.extent[1],math.abs(p.x-self.origin.x)) self.extent[2]=math.max(self.extent[2],math.abs(p.z-self.origin.z))
  self.rates[1]=math.max(self.rates[1],math.abs(v.x)) self.rates[2]=math.max(self.rates[2],math.abs(v.z))
 end
 function self:fit()
  if self.n<128 then return nil,'Fewer than 128 passive tilt/velocity observations' end
  local scale,matrix={},{}
  for i=1,4 do
   scale[i]=math.sqrt(math.max(0,self.xx[i][i]))
   if scale[i]<1e-6 then return nil,'Tilt/velocity feature did not vary independently' end
  end
  for i=1,4 do
   matrix[i]={}
   for j=1,4 do matrix[i][j]=self.xx[i][j]/(scale[i]*scale[j]) end
   for j=1,2 do matrix[i][4+j]=self.xy[i][j]/scale[i] end
  end
  local smallest,largest=math.huge,0
  for pivot=1,4 do
   local best=pivot for i=pivot+1,4 do if math.abs(matrix[i][pivot])>math.abs(matrix[best][pivot]) then best=i end end
   local divisor=matrix[best][pivot]
   if math.abs(divisor)<1e-4 then return nil,'Passive tilt fit is rank-deficient or ill-conditioned' end
   smallest,largest=math.min(smallest,math.abs(divisor)),math.max(largest,math.abs(divisor))
   matrix[pivot],matrix[best]=matrix[best],matrix[pivot]
   for j=pivot,6 do matrix[pivot][j]=matrix[pivot][j]/divisor end
   for i=1,4 do if i~=pivot then local factor=matrix[i][pivot] for j=pivot,6 do matrix[i][j]=matrix[i][j]-factor*matrix[pivot][j] end end end
  end
  if largest/smallest>1000 then return nil,'Passive tilt fit condition exceeds measured-model limit' end
  local coefficients,noise={},{}
  for j=1,2 do
   local row={} local intercept=self.y[j] local explained=0
   for i=1,4 do row[i]=matrix[i][4+j]/scale[i] intercept=intercept-row[i]*self.x[i] explained=explained+row[i]*self.xy[i][j] end
   row[5]=intercept coefficients[j]=row
   noise[j]=math.sqrt(math.max(0,(self.yy[j]-explained)/(self.n-5)))
   if not A.finite(noise[j]) then return nil,'Nonfinite passive tilt statistics' end
   for _,value in ipairs(row) do if not A.finite(value) then return nil,'Nonfinite passive tilt coefficient' end end
  end
  local a,b=coefficients[1],coefficients[2] local determinant=a[1]*b[2]-a[2]*b[1]
  if math.abs(determinant)<1e-5 then return nil,'Tilt response has no independent lateral allocation' end
  for j=1,2 do
   local effect=math.abs(coefficients[j][1])*self.ratio[1]+math.abs(coefficients[j][2])*self.ratio[2]
   if effect<.01 or noise[j]*3>effect*.5 or self.ratio[j]<.002 or self.rates[j]<.02 or self.extent[j]<.5 then return nil,'Passive lateral motion domain or response/noise ratio insufficient' end
  end
  return {schema=1,kind='passive-measured-tilt-response',vehicleId=self.vehicleId,frame='world',clockId=C.clockId(),clock='local_uptime',
   samples=self.n,coefficients=coefficients,noise=noise,ratio=A.copy(self.ratio),extent=A.copy(self.extent),maxRate=A.copy(self.rates),upBody=A.copy(self.upBody),
   units={acceleration='block/s2',velocity='block/s',tilt='up-horizontal/up-vertical'},scope='observed-local-tilt-domain; separate closed-loop qualification required'}
 end
 return self
end
return M
