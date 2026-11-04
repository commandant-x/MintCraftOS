local e=setmetatable({},{__index=_G});e._G=e;e.values={Phase=.1,['Standing height']=3,Stride=.8,['Foot clearance']=.4,['Lateral amplitude']=.3,['Upper leg']=2,['Lower leg']=2};e.outputs={}
e.input=function(k)return e.values[k] end;e.output=function(k,v)e.outputs[k]=v end;e.ui={label=function()return {setText=function()end} end};e.addElement=function()end
local code=assert(loadfile('platforms/sputnik/experiments/spot-three-axis/spot-preview.lua','t',e))
code();assert(e.outputs['Geometry valid']==1 and e.outputs['Walk qualified']==0)
for _,leg in ipairs({'FL','FR','RL','RR'}) do for _,part in ipairs({'roll','hip','knee'}) do assert(type(e.outputs[leg..' '..part..' degrees'])=='number') end end
e.values['Standing height']=100;code();assert(e.outputs['Geometry valid']==0 and e.outputs['Walk qualified']==0 and e.outputs['FL knee degrees']==0)
print('Spot preview: twelve angle outputs, invalid geometry rejection, zero physical qualification; no actuator writes')
