local env=setmetatable({},{__index=_G});env._G=env;env.outputs={};env.elements={}
env.ui={checkbox=function(label)local o={value=false};o.isChecked=function()return o.value end;o.setChecked=function(v)o.value=v end;return o end,label=function(text)return {} end}
env.addElement=function(x)env.elements[#env.elements+1]=x end
env.output=function(k,v)env.outputs[k]=v end
local code=assert(loadfile('platforms/sputnik/experiments/spot-quadruped/controller/operator-node.lua','t',env))
code();assert(env.outputs.Enable==0 and env.outputs.Start==0)
env.MintSpotOperator.enable.setChecked(true);env.MintSpotOperator.start.setChecked(true);code();assert(env.outputs.Enable==1 and env.outputs.Start==1)
env.MintSpotOperator.enable.setChecked(false);env.MintSpotOperator.start.setChecked(false);code();assert(env.outputs.Enable==0 and env.outputs.Start==0)
print('Sputnik operator controls: default OFF, enable/start and reset verified in Lua')
