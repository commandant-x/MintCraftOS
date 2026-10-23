package.path='./?.lua;'..package.path
local C=require('apps.navigation.capabilities')
local function text(rows,title)
 for _,r in ipairs(rows) do if r.title==title then return r.description end end
 error('missing '..title)
end
-- Presentation must not initiate any acquisition or command.
peripheral=setmetatable({},{__index=function() error('peripheral access from capability presentation') end})
local state={state='armed',timestamp=10,reason='Maintien',targets={altitude=82},measuredHold={active=true,heat=10,requestedHeat=10.4},differentialReady=false,differentialReason='Un moteur sans direction',
 kinematics={available=true,vehicleId='ship',observedAt=9.9,validUntil=10.4,frame='world',body={frame='body_orientation_at_last_pose'},response={forward=.2,right=.1,vertical=0,pitch=1,yaw=2,roll=3},responseUnits={translation='block/s2',rotation='deg/s2'}}}
local pose={frame='world',vehicleId='ship',timestamp=10,inSublevel=true}
local telemetry={timestamp=10,altitude=81.8,heading=45}
local r=C.rows(state,telemetry,pose,10)
assert(text(r,'Maintien vertical automatique'):find('ACTIF',1,true))
assert(text(r,'Guidage differentiel')=='Un moteur sans direction')
assert(text(r,'Observations six axes'):find('aucune certification',1,true))
assert(text(r,'Translation laterale / attitude'):find('non qualifie',1,true))
assert(text(r,'ATLAS / atterrissage'):find('sans terrain',1,true))
state.differentialReady=true
assert(text(C.rows(state,telemetry,pose,10),'Guidage differentiel'):find('DISPONIBLE',1,true))
-- Old state and measurements cannot continue displaying active authority.
r=C.rows(state,telemetry,pose,11)
assert(text(r,'Maintien vertical automatique'):find('perime',1,true))
assert(text(r,'Guidage differentiel'):find('perime',1,true))
assert(not text(r,'Consignes altitude'):find('81.80',1,true))
assert(text(r,'Observations six axes'):find('perime',1,true))
pose.vehicleId='other'
assert(text(C.rows(state,telemetry,pose,10),'Observations six axes'):find('Indisponibles',1,true))
pose.vehicleId='ship' state.kinematics.responseUnits.rotation='rpm'
assert(text(C.rows(state,telemetry,pose,10),'Observations six axes'):find('Indisponibles',1,true))
state.motorExperiments={groups={}} for i=1,100 do state.motorExperiments.groups[i]={usable=true,command={side='left',gear=5,reverse=0},reason='observe'} end
r=C.rows(state,telemetry,pose,10)
assert(#r<=30 and text(r,'Donnees moteur'):find('4/4',1,true),'unbounded experiment rendering')
state.measuredHold.adaptation={phase='learning',bias=-2,reason='masse changee'}
state.horizontalDiagnostic={issue='Moteur bloque'}
r=C.rows(state,telemetry,pose,10)
assert(text(r,'Adaptation de masse'):find('ne recertifie pas',1,true))
assert(text(r,'Navigation suspendue')=='Moteur bloque')
state.mechanicalDiagnostic={available=true,observedAt=10,validUntil=12,qualifiedRoots=2,reason='Observe'}
assert(text(C.rows(state,telemetry,pose,10),'Retour mecanique moteur'):find('couverture partielle',1,true))
assert(text(C.rows(state,telemetry,pose,13),'Retour mecanique moteur'):find('perime',1,true))
assert(#C.rows(nil,nil,nil,10)>0)
print('Navigation capabilities: cache-only bounded presentation, vertical-only readiness, stale/foreign/unit guards, diagnostics do not certify axes and terrain/landing limitations passed')
