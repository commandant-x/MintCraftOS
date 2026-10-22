package.path='./?.lua;'..package.path
local C=require('system.navigation.command_catalogue')
local A=require('system.libraries.addon')
local snapshot={ok=true,inventoryComplete=true,vehicleId='ship',frame='body_plot',observedAt=10,validUntil=12,
 burners={},links={},actuators={{id='prop'}},mechanics={
 {id='prop',sourceId='clutch',rpm=-32,theoreticalRPM=-32,role='other'},
 {id='clutch',sourceId='gear',rpm=0,theoreticalRPM=32,disengaged=false,overstressed=true,role='clutch'},
 {id='gear',rpm=32,theoreticalRPM=32,role='gear'}}}
local function build(s,now) return C.build({channels={},balloonSetup={vehicleId='ship'}},s or snapshot,{},now or 10) end
local out=build() local g=out.kineticGraph
assert(out.available and g.roots[1].pathComplete and g.roots[1].steps==3 and #g.nodes==3)
assert(g.nodes[1].rpm==-32 and g.nodes[1].theoreticalRPM==-32)
assert(g.nodes[2].overstressed and g.nodes[2].zeroDespiteTheoreticalRotation and g.nodes[2].disengaged==false)
assert(g.nodes[2].commandBinding:find('unqualified',1,true),'physical anomaly inferred a command binding')
assert(out.equipment[3].theoreticalRPM==32,'raw equipment omitted the theoretical RPM')
g.nodes[1].sourceId='foreign' assert(snapshot.mechanics[1].sourceId=='clutch')
local cycle=A.copy(snapshot) cycle.mechanics[3].sourceId='prop'
g=build(cycle).kineticGraph assert(not g.roots[1].pathComplete and g.roots[1].reason:find('cycle',1,true))
local missing=A.copy(snapshot) missing.mechanics[3].sourceId='unloaded-node'
g=build(missing).kineticGraph assert(not g.roots[1].pathComplete and g.roots[1].missingId=='unloaded-node')
local empty=A.copy(snapshot) empty.mechanics={}
g=build(empty).kineticGraph assert(#g.nodes==0 and not g.roots[1].pathComplete and g.reason=='No mechanical nodes exposed')
-- Shared exact source edges are deduplicated, never replaced by spatial neighbors.
local shared=A.copy(snapshot) shared.actuators[2]={id='prop2'} shared.mechanics[4]={id='prop2',sourceId='clutch',rpm=32,theoreticalRPM=32}
g=build(shared).kineticGraph assert(#g.nodes==4 and #g.roots==2 and g.roots[2].pathComplete)
-- Publication and traversal budgets are independent and explicit.
local deep=A.copy(snapshot) deep.mechanics={} deep.actuators={{id='n1'}}
for i=1,150 do deep.mechanics[i]={id='n'..i,sourceId=i<150 and 'n'..(i+1) or nil,rpm=1,theoreticalRPM=1} end
g=build(deep).kineticGraph assert(#g.nodes==64 and g.truncated and not g.roots[1].pathComplete)
local many=A.copy(snapshot) many.actuators={} for i=1,50 do many.actuators[i]={id='prop'} end
g=build(many).kineticGraph assert(#g.roots==16 and g.truncated)
assert(not build(snapshot,13).available,'stale physical graph refreshed the parent')
fs=setmetatable({},{__index=function() error('filesystem acquisition') end})
peripheral=setmetatable({},{__index=function() error('peripheral acquisition') end})
assert(build())
assert(require('system.ascendancy.contracts').clone(build(deep)))
print('Kinetic catalogue: actual source edges, signed/theoretical RPM, physical flags without bank inference, false clutch state, missing/cyclic paths, shared-node deduplication and read-only budgets passed')
