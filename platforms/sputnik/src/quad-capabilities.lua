-- Structural authority of four fixed vertical actuators, not observed flight proof.
function M.capabilities(model,groups)
 local gram={{0,0,0},{0,0,0},{0,0,0}};local axes={3,4,6}
 for _,c in ipairs(model.columns) do for i=1,3 do for j=1,3 do gram[i][j]=gram[i][j]+c.response[axes[i]]*c.response[axes[j]] end end end
 local valid=true
 for i=1,3 do if not finite(gram[i][i]) or gram[i][i]<=0 then valid=false end end
 if valid then
  local a=gram[1][2]/math.sqrt(gram[1][1]*gram[2][2]);local b=gram[1][3]/math.sqrt(gram[1][1]*gram[3][3]);local c=gram[2][3]/math.sqrt(gram[2][2]*gram[3][3])
  valid=1+2*a*b*c-a*a-b*b-c*c>1e-8
 end
 local caps={}
 for axis,name in ipairs(Response.axes) do
  local positive,negative=0,0
  for _,c in ipairs(model.columns) do positive=positive+math.max(0,c.response[axis]);negative=negative+math.max(0,-c.response[axis]) end
  local independent=valid and (axis==3 or axis==4 or axis==6)
  caps[name]={positive=positive,negative=negative,independent=independent,available=independent and positive>1e-6 and (axis==3 or negative>1e-6)}
 end
 caps.travel=caps.pitch.available and caps.roll.available
 return caps
end
