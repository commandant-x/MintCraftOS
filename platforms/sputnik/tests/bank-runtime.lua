-- Two native node environments with one-tick graph propagation and fixture physics.
-- All frames, actors and feedback here are SYNTHETIC test fixtures.
local function read(path) local h=assert(io.open(path)) local s=h:read('*a') h:close() return s end
local code=read('platforms/sputnik/dist/mintcraft-bank-test.lua')
local sequenceCode=read('platforms/sputnik/dist/mintcraft-test-sequencer.lua')
local function fixture()
 local world={tick=100,z=0,velocity=0,enable=0,bus={},events={},spin={0,0},environment='fixture:world'}
 local states={}
 local function env(name)
  local e=setmetatable({},{__index=_G}) e._G=e e.values={} e.outputs={}
  e.input=function(key) return e.values[key] or 0 end
  e.output=function(key,value) e.outputs[key]=value end
  e.getUniverseTime=function() return world.tick end
  e.getShipMass=function() return 100 end
  e.getPosition=function() return 0,70,world.z end
  e.getOrientation=function() return 0,0,0 end
  e.getDimension=function() return world.environment end
  e.ui={label=function() return {setText=function() end} end,
   checkbox=function() local p={checked=false} p.isChecked=function() return p.checked end return p end,
   textfield=function() local p={value=''} p.getValue=function() return p.value end p.setValue=function(v) p.value=v end return p end,
   itempicker=function() local p={} p.getItem=function() return p.item end return p end}
  e.addElement=function() end e.display=function() end
  e.transmitWirelessRedstone=function(a,b,v)
   assert(v>=0 and v<=15 and v%1==0,'invalid raw command')
   local key=a..','..b
   for i=1,2 do
    if states[i] and key==states[i].reverse and world.bus[key]~=v then assert(world.spin[i]==0,'inverter changed while shaft rotation was observed') end
    if states[i] and key==states[i].run and v==15 then local other=states[i==1 and 2 or 1] if other then assert((world.bus[other.run] or 0)~=15,'two banks engaged in same command tick') end end
   end
   world.bus[key]=v world.events[#world.events+1]={tick=world.tick,name=name,key=key,value=v}
  end
  e.receiveWirelessRedstone=function(a,b)
   local key=a..','..b
   for i=1,2 do if states[i] and states[i].spin==key then return world.spin[i] end end
   return world.bus[key] or 0
  end
  return e
 end
 local coordinator=env('coordinator') coordinator.run=assert(load(sequenceCode,'sequencer','t',coordinator))
 local banks={}
 for i=1,2 do
  banks[i]=env('bank'..i)
  banks[i].run=assert(load(code:gsub('local BANK_DEFAULT=1','local BANK_DEFAULT='..i),'bank'..i,'t',banks[i]))
  banks[i].run()
  local s=banks[i].MintCraftBank
  s.checks.horizontal.checked=true s.checks.failsafe.checked=true
  s.fields.stop.value.value='15' s.fields.test.value.value='14'
  local first=i==1 and 'minecraft:iron_ingot' or 'minecraft:copper_ingot'
  local seconds={'minecraft:gold_ingot','minecraft:diamond','minecraft:emerald','minecraft:quartz'}
  states[i]={}
  for j,role in ipairs({'power','run','reverse','spin'}) do
   local p=s.controls[role] p.first.item=first p.second.item=seconds[j]
   states[i][role]=first..','..seconds[j]
  end
 end
 function world:step()
  self.tick=self.tick+1
  local active,force=0,0
  for i=1,2 do
   local b=states[i] local running=(self.bus[b.run] or 0)==15 and self.bus[b.power]==14
   if running then active=active+1 self.spin[i]=3 force=force+((self.bus[b.reverse] or 0)==15 and -.8 or .8)
   else self.spin[i]=0 end
  end
  assert(active<=1,'two mechanical groups energized together')
  self.velocity=self.velocity+(force-2*self.velocity)*.05 self.z=self.z+self.velocity*.05
  -- Real WGraph copies every old output before evaluating any node.
  local old={}
  for i=1,2 do old[i]={} for k,v in pairs(banks[i].outputs) do old[i][k]=v end end
  local selected,session=coordinator.outputs['Selected group'] or 0,coordinator.outputs.Session or 0
  local consent='minecraft:stone,minecraft:dirt'
  coordinator.values.Enable=self.enable coordinator.values['Enable binding']=consent
  for i=1,2 do
   coordinator.values['Group '..i]=old[i]['Group index'] or 0
   coordinator.values['Ready '..i]=old[i].Ready or 0
   coordinator.values['Bindings '..i]=old[i].Bindings or ''
   coordinator.values['Done '..i]=old[i]['Done session'] or 0
   coordinator.values['Failed '..i]=old[i]['Failed session'] or 0
   banks[i].values={Enable=self.enable,['Enable binding']=consent,['Selected group']=selected,Session=session}
  end
  coordinator.run() banks[1].run() banks[2].run()
 end
 return world,coordinator,banks,states
end
local w,c,b,states=fixture()
for _=1,6 do w:step() end
assert(c.MintCraftSequence.ready and b[1].outputs.Ready==1 and b[2].outputs.Ready==1)
w.enable=15
for _=1,1500 do w:step() if c.outputs['Sequence complete']==1 then break end end
assert(c.outputs['Sequence complete']==1,'automatic two-bank sequence did not finish: '..tostring(c.outputs.Status))
for i=1,2 do
 local job=b[i].MintCraftBank.job assert(job and job.done and job.report.functionalReverseMeasured and not job.report.flightQualified)
 assert(w.bus[states[i].run]==0,'completed bank remained engaged')
end
local prior=#w.events
for _=1,30 do w:step() end
for i=prior+1,#w.events do assert(not (w.events[i].key==states[1].run or w.events[i].key==states[2].run) or w.events[i].value==0,'held lever retriggered calibration') end
-- Emergency Enable low while spinning releases only propulsion, never touches lift.
local w2,c2,b2,s2=fixture() for _=1,6 do w2:step() end w2.enable=15
for _=1,100 do w2:step() if w2.bus[s2[1].run]==15 then break end end
assert(w2.bus[s2[1].run]==15) w2.enable=0 w2:step()
assert(w2.bus[s2[1].run]==0 and w2.bus[s2[1].power]==15)
-- A missing positive shaft reading cannot pass merely because the craft moved.
local w3,c3,b3,s3=fixture() for _=1,6 do w3:step() end
b3[1].receiveWirelessRedstone=function() return 0 end w3.enable=15
for _=1,200 do w3:step() end
assert(c3.outputs['Sequence complete']~=1 and b3[1].MintCraftBank.job.failed)
-- Duplicate channels across banks must block every trial.
local w4,c4,b4,s4=fixture()
b4[2].MintCraftBank.controls.power.first.item=b4[1].MintCraftBank.controls.power.first.item
b4[2].MintCraftBank.controls.power.second.item=b4[1].MintCraftBank.controls.power.second.item
for _=1,8 do w4:step() end w4.enable=15
for _=1,80 do w4:step() end
for _,event in ipairs(w4.events) do assert(event.value~=15 or event.key~=s4[1].run,'duplicate group frequencies armed') end
assert(not b4[1].MintCraftBank.job and not b4[2].MintCraftBank.job)
-- Two mechanically independent members cannot be validated by only one spinning.
local w5,c5,b5,s5=fixture()
local node=b5[1].MintCraftBank node.checks.second.checked=true
node.controls.spin2.first.item='minecraft:lapis_lazuli' node.controls.spin2.second.item='minecraft:quartz'
for _=1,6 do w5:step() end w5.enable=15
for _=1,220 do w5:step() end
assert(c5.outputs['Sequence complete']~=1 and b5[1].MintCraftBank.job.failed,'missing member rotation counted as complete bank feedback')
-- A held Enable at initial startup never starts a bank.
local w6,c6,b6,s6=fixture() w6.enable=15
for _=1,100 do w6:step() end
assert(not b6[1].MintCraftBank.job and not b6[2].MintCraftBank.job)
-- A mutable UI mapping cannot retarget power while the existing bank is running.
local w7,c7,b7,s7=fixture() for _=1,6 do w7:step() end w7.enable=15
for _=1,100 do w7:step() if w7.bus[s7[1].run]==15 then break end end
assert(w7.bus[s7[1].run]==15)
b7[1].MintCraftBank.controls.power.second.item='minecraft:lapis_lazuli' w7:step()
assert(w7.bus[s7[1].run]==0 and not b7[1].MintCraftBank.ready,'live mapping modification retained power')
-- Server identity/clock loss releases the old mapping even before a next pose.
local w8,c8,b8,s8=fixture() for _=1,6 do w8:step() end w8.enable=15
for _=1,100 do w8:step() if w8.bus[s8[1].run]==15 then break end end
assert(w8.bus[s8[1].run]==15) b8[1].getShipMass=function() return 0 end w8:step()
assert(w8.bus[s8[1].run]==0 and not b8[1].MintCraftBank.ready)
-- A motor command may not share the physical Enable frequency.
local w9,c9,b9,s9=fixture()
b9[1].MintCraftBank.controls.power.first.item='minecraft:stone'
b9[1].MintCraftBank.controls.power.second.item='minecraft:dirt'
for _=1,6 do w9:step() end w9.enable=15
for _=1,100 do w9:step() end
assert(not b9[1].MintCraftBank.job and not b9[2].MintCraftBank.job)
print('Native two-bank commissioning: one-tick graph links, sequential real fixture motion + shaft feedback, no simultaneous banks, stop-before-reverse, completion latch, physical STOP, missing feedback and duplicate channel refusal passed; lift untouched')
