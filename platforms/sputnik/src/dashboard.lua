-- Sputnik node body. Each evaluation is bounded; no files, HTTP or CC APIs.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function read(name,...)
 local fn=_G[name] if type(fn)~='function' then return end
 local ok,a,b,c=pcall(fn,...) if ok then return a,b,c end
end
local function number(v) return finite(v) and string.format('%.2f',v) or '?' end
if not _G.MintCraftSputnik then
 local state={version='0.1.5',actuation=false,flightQualified=false,clockAvailable=false}
 -- No vehicle UUID, RX association or ownership API is present in the audited host.
 state.capabilities={telemetry=true,numericNavigation=false,wirelessLinks=true,numericRadio=true,
  filesystem=false,http=false,authentication=false,completeGeometry=false,qualifiedAutopilot=false}
 _G.MintCraftSputnik=state
 if type(ui)=='table' and type(addElement)=='function' then
  state.title=ui.label('MintCraft Sputnik 0.1.5 | lecture seule')
  state.position=ui.label('Position ?') state.motion=ui.label('Vitesse ?')
  state.attitude=ui.label('Attitude ?') state.physical=ui.label('Masse ?')
  state.notice=ui.label('Pilotage qualifie indisponible: identite/RX non exposes')
  state.peripherals=ui.label('Peripheriques: Scan pour relever les IDs, jamais auto-selectionnes')
  state.scan=ui.button('Scan lecture seule',180)
 end
end
local s=_G.MintCraftSputnik
local x,y,z=read('getPosition') local vx,vy,vz=read('getVelocity')
local pitch,yaw,roll=read('getOrientation') local mass=read('getShipMass')
local dimension=read('getDimension') local ticks=read('getUniverseTime')
local previous=s.lastTicks
s.clockAvailable=finite(ticks) and ticks>0
s.clockFault=s.clockAvailable and previous~=nil and ticks<previous or false
if s.clockAvailable then s.lastTicks=ticks end
s.time=s.clockAvailable and ticks/20 or nil
s.telemetry={position={x=x,y=y,z=z},velocity={x=vx,y=vy,z=vz},pitch=pitch,yaw=yaw,roll=roll,
 mass=finite(mass) and mass>0 and mass or nil,namespace=dimension,source='Sputnik native Lua API',
 sourceClock='cosmonautics_universe_ticks',sourceTick=s.clockAvailable and ticks or nil,
 velocityConvention='Sable root finite difference times 20; not velocity at the rotating Sputnik block',
 identityAvailable=false,fullInertiaAvailable=false}
if s.title then
 s.position.setText('XYZ '..number(x)..' / '..number(y)..' / '..number(z)..' | '..tostring(dimension or '?'))
 s.motion.setText('V xyz '..number(vx)..' / '..number(vy)..' / '..number(vz)..' m/s')
 s.attitude.setText('Pitch / yaw / roll '..number(pitch)..' / '..number(yaw)..' / '..number(roll)..' deg')
 s.physical.setText('Masse '..number(s.telemetry.mass)..' kg | horloge '..(s.clockFault and 'regression' or s.clockAvailable and 'serveur disponible' or 'indisponible cote client'))
 if s.scan.wasClicked() then
  local ids=read('getPeripheralIds') local names={}
  if type(ids)=='table' then
   for i=1,math.min(#ids,32) do names[#names+1]=tostring(ids[i]):sub(1,24)..':'..tostring(read('getPeripheralType',ids[i]) or '?'):sub(1,32) end
   s.peripherals.setText(#ids..' ID(s): '..table.concat(names,', ')..(#ids>32 and ' (32 affiches)' or ''))
  else s.peripherals.setText('Inventaire indisponible dans ce contexte') end
 end
 for _,element in ipairs({s.title,s.position,s.motion,s.attitude,s.physical,s.notice,s.scan,s.peripherals}) do addElement(element) end
end
-- Literal names/types are intentional: Sputnik discovers graph pins from source.
output('Altitude',finite(y) and y or 0)
output('Vertical speed',finite(vy) and vy or 0)
output('Mass',s.telemetry.mass or 0)
output('Telemetry valid',s.clockAvailable and not s.clockFault and s.telemetry.mass~=nil and finite(x) and finite(y) and finite(z) and dimension~='unknown' and 1 or 0)
output('Flight qualified',0)
