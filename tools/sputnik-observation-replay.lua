-- Imported MCLOG text is data only. The explicitly supplied local controller is code.
local cfg=assert(MINTCRAFT_REPLAY)
local function read(path) local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local function field(v) return {getValue=function() return v end,setValue=function(x) v=x end,setText=function() end} end
local env=setmetatable({},{__index=function(_,k) if type(k)=='string' and k:match('^MintCraft') then return nil end;return _G[k] end});env._G=env
-- No radio or game API is provided to re-evaluated code.
env.ui={label=field,textfield=function() return field('') end};env.addElement=function() end;env.input=function() return 0 end;env.output=function() end
local modules=assert(load(read(cfg.controller)..'\nreturn _G.MintCraftFlightModules','decision-replay','t',env))()
local V,F=modules[7],modules[10];local groups={};for _,line in ipairs(cfg.log.groups) do groups[#groups+1]=assert(V.decode(line)) end
local parts={};for value in (cfg.log.settings..';'):gmatch('(.-);') do parts[#parts+1]=value end
local config={profile=tonumber(parts[2]),gravity=tonumber(parts[3]),climb=tonumber(parts[4]),tilt=tonumber(parts[5]),margin=tonumber(parts[6]),braking=tonumber(parts[7]),steering=parts[11]~='0',protected={}}
local out=assert(io.open(cfg.output,'w'));out:write('tick,id,recorded_signal,reevaluated_signal,mode,scope\n')
local core,lastSignals,mode,target,heading
for _,row in ipairs(cfg.log.frames) do
 if row.active==0 then core=nil
 else
  local pose={tick=row.tick,mass=row.mass,ix=row.ix,iy=row.iy,iz=row.iz,x=row.x,y=row.y,z=row.z,pitch=row.pitch,yaw=row.yaw,roll=row.roll,vx=row.vx,vy=row.vy,vz=row.vz,dimension=row.dimension,gravity=config.gravity}
  if not core then
   local why;core,why=F.new(groups,pose,config)
   if not core then out:write(row.tick..',0,,,REFUSED,warm-start:'..tostring(why):gsub('[,\r\n]',';')..'\n')
   else lastSignals=core.initialSignals;mode=row.mode;target=row.target;core.target.y=row.target end
  else
   -- Only vertical/manual intent is reconstructible without accepted route packets.
   local supported=row.mode=='HOLD' or row.mode=='ALTITUDE' or row.mode=='MANUAL' or row.mode=='PAUSE' or row.mode=='CANCEL'
   if not supported then out:write(row.tick..',0,,,'..tostring(row.mode)..',unsupported-intent\n');core=nil
   else
    core.scale=row.scale or 1;core.target.y=row.target
    local signals,why=core:step(pose,{forward=row.forward or 0,left=row.left or 0,vertical=row.vertical or 0},lastSignals)
    if not signals then out:write(row.tick..',0,,,FAULT,'..tostring(why):gsub('[,\r\n]',';')..'\n');core=nil
    else
     for _,g in ipairs(row.groups) do out:write(table.concat({row.tick,g.id,g.level or '',signals[tostring(g.id)] or '',row.mode,'recorded-poses;not-counterfactual'},',')..'\n') end
     lastSignals=signals
    end
   end
  end
 end
end
out:close()
print('Decision re-evaluation completed; recorded trajectory is fixed and no hardware was accessed')
