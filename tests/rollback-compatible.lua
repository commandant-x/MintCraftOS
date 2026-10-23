local nativeLoadfile=loadfile
local called,requested=0,nil
local sha=string.rep('a',40)
local normal='-- MintCraft installer protocol: 2\nlocal files={VERSION="0.18.86\\n",["system/test.lua"]="return true"}\nlocal factory=assert(load("old installer which must not execute","installer","t",_ENV)) factory().install(files)\n'
local body=normal
local compatible="-- MintCraft packed source 2\npayload"
local expectCompatibility=false
local environment={assert=assert,type=type,tostring=tostring,pcall=pcall,print=function() end,
 fs={exists=function() return true end,isDir=function() return false end},
 http={get=function(url) requested=url local response=url:find('/tools/compat/',1,true) and compatible or body local at=1 return {read=function(n) if at>#response then return nil end local part=response:sub(at,at+n-1) at=at+#part return part end,close=function() end} end},
 load=load,math=math,table=table,string=string,loadfile=function(path)
  assert(path=='/system/libraries/installer_v2.lua')
  return function() return {equivalentSourcePreparation=true,install=function(files,options)
   called=called+1 assert(files.VERSION=='0.18.86\n' and files['system/test.lua']=='return true')
   if expectCompatibility then assert(files['system/services/flightd.lua']==compatible,'known Cobalt compatibility fix not selected') end
   options.onProgress('install') return true
  end} end
 end}
local function run(argument) return pcall(assert(nativeLoadfile('tools/rollback-compatible.lua','t',environment)),argument) end
assert(run(sha) and called==1)
assert(requested=='https://raw.githubusercontent.com/commandant-x/MintCraftOS/'..sha..'/install.lua')
requested=nil assert(not run('../main') and not requested and called==1,'invalid commit reached HTTP or installer')
body='-- MintCraft installer protocol: 2\nfs.delete("/home/user")'
assert(not run(sha) and called==1,'old installer escaped the capture environment')
body=normal:gsub('0.18.86','version garbage') assert(not run(sha) and called==1)
body=string.rep('x',4194305) assert(not run(sha) and called==1)
environment.fs.exists=function() return false end
body=normal requested=nil assert(not run(sha) and not requested)
environment.fs.exists=function() return true end
body=normal:gsub('local files={','local files={["system/services/flightd.lua"]="original",',1)
expectCompatibility=true
assert(run('623e07685788b15b811440da3474ca440191fe6e') and called==2)
assert(requested=='https://raw.githubusercontent.com/commandant-x/MintCraftOS/a793160126533187717f1ee8795a234b0221e79c/tools/compat/flightd-0.18.86.packed')
compatible='invalid artifact' assert(not run('623e07685788b15b811440da3474ca440191fe6e') and called==2)
print('Compatible rollback tool: pinned commit URL, restricted payload capture without old installer execution, version/size validation and standalone recovery requirement passed')
