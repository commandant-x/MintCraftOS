-- Read-only, native flight audit. Does not arm, command or certify any actuator.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function read(name)
 if type(_G[name])~='function' then return end
 local ok,a,b,c=pcall(_G[name]) if ok then return a,b,c end
end
local function number(v) return finite(v) and string.format('%.1f',v) or '?' end
local active=input('Controller active') local valid=input('Keyboard valid')
local forward=input('Forward demand') local left=input('Left demand') local vertical=input('Vertical demand')
local target=input('Target altitude')
local mass=read('getShipMass') local ix,iy,iz=read('getInertiaTensor')
local x,y,z=read('getPosition') local pitch,yaw,roll=read('getOrientation')
local ticks=read('getUniverseTime')
local text='m='..number(mass)..'kg I='..number(ix)..'/'..number(iz)..' A='..number(active)..' K='..number(valid)..' F='..number(forward)..' L='..number(left)..' Y='..number(vertical)..' h='..number(y)..'>'..number(target)
local s=_G.MintCraftFlightTelemetry
if not s then s={label=ui.label('Audit lecture seule: lire le panneau physique serveur')} _G.MintCraftFlightTelemetry=s end
addElement(s.label)
s.label.setText(text..' | editeur peut representer le client, sans masse serveur')
local emit=output
if false then output('Telemetry','string') output('Mass',0) output('Inertia X',0) output('Inertia Z',0) output('Pose valid',0) end
emit('Telemetry',text)
emit('Mass',finite(mass) and mass or 0) emit('Inertia X',finite(ix) and ix or 0) emit('Inertia Z',finite(iz) and iz or 0)
emit('Pose valid',finite(mass) and mass>0 and finite(ix) and ix>0 and finite(iz) and iz>0 and finite(y) and finite(pitch) and finite(yaw) and finite(roll) and finite(ticks) and ticks>0 and 1 or 0)
