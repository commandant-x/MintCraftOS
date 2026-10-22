-- Local airborne equilibrium trim. No excitation, certificate, model fit or writes.
local addon=require('system.libraries.addon')
local M={}
function M.new(snapshot)
 return {mass=snapshot.mass,unit=(snapshot.units or {}).mass,bias=0,active=false,window={}}
end
function M.observe(s,snapshot)
 local mass,unit=snapshot.mass,(snapshot.units or {}).mass
 if not addon.finite(s.mass) or s.mass<=0 then
  if addon.finite(mass) and mass>0 then s.mass,s.unit=mass,unit end
  return false
 end
 if not addon.finite(mass) or mass<=0 or unit~=s.unit then return nil,'Mass observation unavailable or unit changed' end
 if math.abs(mass-s.mass)<=s.mass*0.02 then return false end
 s.referenceMass=s.referenceMass or s.mass s.mass=mass s.active=true
 s.phase,s.reason='learning','Adapting heat at unchanged altitude; no motion tests'
 s.window={} s.stableAt=nil
 return true
end
function M.step(s,model,t,target,ack,requested,now,minimum,maximum)
 minimum,maximum=minimum or 0,maximum or 15
 if not s.active then return end
 if not addon.finite(ack) or ack>now or now-ack>2 then return end
 if not addon.finite(target) or not addon.finite(t.timestamp) or t.timestamp>now or now-t.timestamp>0.5
  or not addon.finite(t.altitude) or not addon.finite(t.altitudeRate) then s.window={} s.phase='learning' return end
 if s.last and t.timestamp<=s.last then return end
 local dt=s.last and t.timestamp-s.last or 0
 s.last=t.timestamp
 if dt<=0 or dt>1.5 then s.window={} s.phase='learning' return end
 dt=math.min(1,dt)
 local error=target-t.altitude
 local kp=math.max(0,(model.gains or {}).kp or 0)
 -- Conservative integral trim of measured height error. Existing rate feedback
 -- remains active; anti-windup preserves the best available heat at saturation.
 local change=math.max(-0.1,math.min(0.1,kp*0.2*error))*dt
 if addon.finite(requested) and ((requested<=minimum and change<0) or (requested>=maximum and change>0)) then change=0 end
 s.bias=math.max(-15,math.min(15,s.bias+change))
 s.saturated=addon.finite(requested) and (requested<=minimum or requested>=maximum) or false
 s.target=target
 if math.abs(error)>0.5 or math.abs(t.altitudeRate)>0.25 then
  s.window={} s.phase='learning'
  s.reason=s.saturated and 'Heat authority exhausted; holding best available output' or 'Learning equilibrium from natural altitude response'
  return
 end
 if s.stableAt and t.timestamp-s.stableAt<0.5 then return end
 s.stableAt=t.timestamp s.window[#s.window+1]={height=t.altitude,rate=t.altitudeRate}
 while #s.window>8 do table.remove(s.window,1) end
 local low,high,sumRate=math.huge,-math.huge,0
 for _,row in ipairs(s.window) do low=math.min(low,row.height) high=math.max(high,row.height) sumRate=sumRate+row.rate end
 if #s.window>=8 and high-low<=0.5 and math.abs(sumRate/#s.window)<=0.1 then
  s.phase,s.reason='holding','Local altitude equilibrium observed; horizontal model remains invalid'
 else s.phase,s.reason='learning','Waiting for measured height/rate stability; no motion tests' end
end
function M.status(s)
 if not s or not s.active then return nil end
 return {phase=s.phase,reason=s.reason,mass=s.mass,referenceMass=s.referenceMass,bias=s.bias,target=s.target,saturated=s.saturated,samples=#s.window}
end
return M
