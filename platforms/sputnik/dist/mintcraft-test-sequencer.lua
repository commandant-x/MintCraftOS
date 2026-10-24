-- One server-owned sequence, one selected bank at a time. No actuator writes.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local s=_G.MintCraftSequence
if not s then
 s={low=0,ready=false,count=ui.textfield(80),label=ui.label('Enable physique 0 requis avant chaque sequence')}
 s.count.setValue('2') _G.MintCraftSequence=s
end
addElement(s.count) addElement(s.label)
local emit=output
if false then output('Status','string') end
local consent=input('Enable binding','string')
local enable=input('Enable')
local groups={input('Group 1'),input('Group 2'),input('Group 3'),input('Group 4'),input('Group 5'),input('Group 6'),input('Group 7'),input('Group 8')}
local ready={input('Ready 1'),input('Ready 2'),input('Ready 3'),input('Ready 4'),input('Ready 5'),input('Ready 6'),input('Ready 7'),input('Ready 8')}
local bindings={input('Bindings 1','string'),input('Bindings 2','string'),input('Bindings 3','string'),input('Bindings 4','string'),input('Bindings 5','string'),input('Bindings 6','string'),input('Bindings 7','string'),input('Bindings 8','string')}
local done={input('Done 1'),input('Done 2'),input('Done 3'),input('Done 4'),input('Done 5'),input('Done 6'),input('Done 7'),input('Done 8')}
local failed={input('Failed 1'),input('Failed 2'),input('Failed 3'),input('Failed 4'),input('Failed 5'),input('Failed 6'),input('Failed 7'),input('Failed 8')}
local tick=type(getUniverseTime)=='function' and getUniverseTime() or nil
local mass=type(getShipMass)=='function' and getShipMass() or nil
if not finite(tick) or tick<=0 or not finite(mass) or mass<=0 then
 s.label.setText('Config client: nb groupes 1..8; etat serveur via Display Link MC_SEQUENCE')
 if s.armed then s.armed=false s.ready=false s.low=0 s.index=0 emit('Selected group',0) emit('Session',0) end
 return
end
local count=tonumber(s.count.getValue()) local valid=finite(count) and count%1==0 and count>=1 and count<=8 and type(consent)=='string' and #consent>0 and #consent<=386
local signatures={} local seen={}
if type(consent)=='string' then seen[consent]=true end
if valid then
 for i=1,count do
  if groups[i]~=i or ready[i]~=1 or type(bindings[i])~='string' or #bindings[i]<1 or #bindings[i]>2048 then valid=false break end
  local n=0
  for pair in bindings[i]:gmatch('[^|]+') do
   n=n+1 if seen[pair] then valid=false break end seen[pair]=true
  end
  if n~=4 and n~=5 then valid=false end signatures[i]=bindings[i]
 end
end
local signature=valid and (consent..';'..table.concat(signatures,';')) or ''
local function abort(why) s.index=0 s.armed=false s.ready=false s.low=0 s.reason=why end
local advancing=not s.tick or tick>s.tick
if s.tick and tick<s.tick then abort('Horloge serveur en regression') end s.tick=tick
if finite(enable) and enable==0 and advancing then
 s.index=0 s.session=0 s.armed=false s.low=s.low+1
 if s.low>=2 then s.ready=true end
 s.reason=valid and 'Pret: lever Enable pour lancer les essais' or 'Configurer chaque banc et ses liaisons uniques; laisser Enable a 0'
elseif not finite(enable) or enable<0 or enable>15 then abort('Enable/STOP invalide')
elseif enable>0 then
 s.low=0
 if not valid then abort('Configuration/retours Ready incomplets ou frequences partagees')
 elseif s.armed then
  if s.signature~=signature or s.runCount~=count then abort('Configuration modifiee pendant la sequence')
  else
   for i=1,count do if failed[i]==s.session then abort('Echec du groupe '..i..'; reprendre Enable 0') break end end
   if s.armed and done[s.index]==s.session then
    s.index=s.index+1
    if s.index>count then s.index=0 s.armed=false s.ready=false s.reason='Sequence terminee: sens A/B et arrets mesures; aucun autopilote arme' end
   end
  end
 elseif s.ready and advancing then
  s.session=tick s.index=1 s.armed=true s.ready=false s.signature=signature s.runCount=count
 else s.reason=s.reason or 'Enable 0 requis avant chaque sequence' end
 if s.armed then s.reason='Essai groupe '..s.index..' / '..count..'; sustentation non commandee' end
end
if type(display)=='function' then pcall(display,'MC_SEQUENCE',s.reason or 'Inactif') end
s.label.setText(s.reason or 'Inactif')
output('Selected group',s.index or 0)
output('Session',s.armed and s.session or 0)
output('Sequence complete',s.index==0 and not s.ready and not s.armed and s.session and s.session>0 and s.reason and s.reason:find('Sequence terminee',1,true) and 1 or 0)
emit('Status',s.reason or 'Inactif')
output('Flight qualified',0)
