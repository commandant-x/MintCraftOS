-- Experimental phase indicator only: no Link writes and no balance claim.
-- Replace the architecture constant only when building the named prototype.
local LEGS=2
local s=_G.MintCraftGaitExperiment
if not s then
 s={last=nil,phase=0,armed=false,ready=false,label=ui.label('Essai sur banc: sorties de phase, aucun mouvement qualifie')}
 _G.MintCraftGaitExperiment=s
end
addElement(s.label)
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local emit=output
if false then output('Status','string') end
local enable=input('Enable')
local demand=input('Forward')
local dwell=input('Ticks per phase')
local tick=type(getUniverseTime)=='function' and getUniverseTime() or nil
local fresh=finite(tick) and tick%1==0 and (not s.last or tick==s.last+1)
local valid=finite(enable) and (enable==0 or enable==1) and finite(demand) and demand>=-1 and demand<=1 and finite(dwell) and dwell%1==0 and dwell>=10 and dwell<=200
local reason='OFF: sorties inactives'
if not fresh or not valid then
 s.armed=false;s.ready=false;s.phase=0;s.elapsed=0;reason='Defaut horloge ou entree: remettre Enable a 0'
elseif enable==0 then
 s.armed=false;s.ready=true;s.phase=0;s.elapsed=0
elseif s.ready and not s.armed then
 s.armed=true;s.ready=false;s.phase=0;s.elapsed=0;reason='Marche experimentale: aucune stabilite certifiee'
elseif s.armed then
 if demand~=0 then
  s.elapsed=s.elapsed+1
  if s.elapsed>=dwell then s.elapsed=0;s.phase=(s.phase+(demand>0 and 1 or -1))%LEGS end
 end
 reason='Marche experimentale: aucune stabilite certifiee'
else reason='Remettre Enable a 0 avant activation' end
s.last=finite(tick) and tick or nil
local running=s.armed and demand~=0
local a,b,c,d=0,0,0,0
if running then
 -- Wave sequence: one leg requested in swing at a time. These numbers are
 -- abstract states, never servo angles or proof of a supported contact.
 if s.phase==0 then a=1 elseif s.phase==1 then b=1 elseif s.phase==2 then c=1 else d=1 end
end
s.label.setText(reason)
output('Leg 1 swing',a)
output('Leg 2 swing',b)
output('Leg 3 swing',c)
output('Leg 4 swing',d)
output('Active',s.armed and 1 or 0)
output('Walk qualified',0)
emit('Status',reason)
