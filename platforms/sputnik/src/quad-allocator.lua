-- Four upward force actuators: preserve the requested collective before moments.
-- No axis certificate is created by this algebra; all bounds remain explicit.
function M.solve(model,wanted)
 if type(model)~='table' or type(model.columns)~='table' or type(model.scale)~='table' or #model.columns~=4 or type(wanted)~='table' then return nil,'Quad allocation invalide' end
 for j=1,6 do if not finite(wanted[j]) or not finite(model.scale[j]) or model.scale[j]<=0 then return nil,'Demande non finie' end end
 local a={{},{},{}};local gram={{0,0,0},{0,0,0},{0,0,0}};local capacity={}
 for i,c in ipairs(model.columns) do
  if type(c)~='table' or type(c.response)~='table' or c.low~=0 or c.high~=15 then return nil,'Colonne invalide' end
  for j=1,6 do if not finite(c.response[j]) then return nil,'Reponse non finie' end end
  local u=c.response[3];if not finite(u) or u<=0 then return nil,'Poussee indisponible' end
  a[1][i]=1;a[2][i]=c.response[4]/u;a[3][i]=c.response[6]/u;capacity[i]=15*u
 end
 for j=1,3 do for k=1,3 do for i=1,4 do gram[j][k]=gram[j][k]+a[j][i]*a[k][i] end end end
 local x,y,z=gram[1][1],gram[2][2],gram[3][3];local b,c,d=gram[1][2],gram[1][3],gram[2][3]
 local det=x*y*z+2*b*c*d-x*d*d-y*c*c-z*b*b
 if not finite(det) or det<=1e-15 then return nil,'Geometrie sans autorite independante' end
 local inv={{(y*z-d*d)/det,(c*d-b*z)/det,(b*d-c*y)/det},{(c*d-b*z)/det,(x*z-c*c)/det,(b*c-x*d)/det},{(b*d-c*y)/det,(b*c-x*d)/det,(x*y-b*b)/det}}
 local base,moment,null={},{},{};local cap=0
 for i=1,4 do
  local w,m=0,0
  for j=1,3 do w=w+a[j][i]*inv[j][1];m=m+a[j][i]*(inv[j][2]*wanted[4]+inv[j][3]*wanted[6]) end
  base[i]=w;moment[i]=m;cap=cap+capacity[i]
  local k={};for n=1,4 do if n~=i then k[#k+1]=n end end
  null[i]=(i%2==1 and 1 or -1)*((a[2][k[2]]-a[2][k[1]])*(a[3][k[3]]-a[3][k[1]])-(a[2][k[3]]-a[2][k[1]])*(a[3][k[2]]-a[3][k[1]]))
 end
 local norm=0;for i=1,4 do norm=math.max(norm,math.abs(null[i])) end
 for i=1,4 do null[i]=null[i]/norm end
 local function fit(collective,fraction,unit)
  local lo,hi=-math.huge,math.huge;local f={}
  for i=1,4 do
   f[i]=base[i]*collective+moment[i]*fraction
   local maximum=unit and 1 or capacity[i]
   if math.abs(null[i])>1e-12 then
    local x,y=-f[i]/null[i],(maximum-f[i])/null[i]
    lo=math.max(lo,math.min(x,y));hi=math.min(hi,math.max(x,y))
   elseif f[i]<-1e-9 or f[i]>maximum+1e-9 then return nil end
  end
  if lo>hi+1e-9 then return nil end
  local t=clip(0,lo,hi)
  for i=1,4 do f[i]=clip(f[i]+t*null[i],0,unit and 1 or capacity[i]) end
  return f
 end
 if not fit(1,0,true) then return nil,'Equilibre effectif hors support' end
 local collective=clip(wanted[3],0,cap);local fraction=1;local forces=fit(collective,0)
 if not forces then
  local lo,hi=0,collective
  for _=1,16 do local mid=(lo+hi)/2;if fit(mid,0) then lo=mid else hi=mid end end
  collective=lo
 end
 forces=fit(collective,1)
 if not forces then
  local lo,hi=0,1
  for _=1,16 do local mid=(lo+hi)/2;if fit(collective,mid) then lo=mid else hi=mid end end
  forces=fit(collective,lo)
 end
 if not forces then return nil,'Repartition bornees indisponible' end
 if model.attitudePriority then
  local f,r,norm={},{wanted[3],wanted[4]*10,wanted[6]*10},{};local peak=math.max(gram[2][2],gram[3][3])*100/gram[1][1]
  for i=1,4 do
   f[i]=peak>100 and clip(base[i]*wanted[3]+moment[i],0,capacity[i]) or 0
   norm[i]=1+100*(a[2][i]^2+a[3][i]^2)
   r[1]=r[1]-f[i];r[2]=r[2]-10*a[2][i]*f[i];r[3]=r[3]-10*a[3][i]*f[i]
  end
  for iteration=1,96 do
   local largest=0
   for i=1,4 do
    local change=clip(f[i]+(r[1]+10*a[2][i]*r[2]+10*a[3][i]*r[3])/norm[i],0,capacity[i])-f[i]
    f[i]=f[i]+change;largest=math.max(largest,math.abs(change))
    r[1]=r[1]-change;r[2]=r[2]-10*a[2][i]*change;r[3]=r[3]-10*a[3][i]*change
   end
   if largest<1e-9 then break end
  end
  forces=f
 end

 local values,delta,actual={},{},{};local residual=0;local saturated=false
 for i,col in ipairs(model.columns) do values[i]=clip(forces[i]/col.response[3],0,15);delta[col.id]=values[i];saturated=saturated or values[i]<1e-6 or values[i]>15-1e-6 end
 for j=1,6 do actual[j]=0;for i,col in ipairs(model.columns) do actual[j]=actual[j]+col.response[j]*values[i] end;residual=math.max(residual,math.abs(actual[j]-wanted[j])/model.scale[j]) end
 return values,{delta=delta,actual=actual,normalizedResidual=residual,saturated=saturated}
end
