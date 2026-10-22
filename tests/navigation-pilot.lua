package.path='./?.lua;'..package.path
keys={escape=1,enter=2,tab=3,backspace=4,leftCtrl=5,rightCtrl=6,a=7}
local now=10 os.clock=function() return now end
local Pilot=require('apps.navigation.pilot')
local Surface=require('system.graphics.surface')
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local calls,stops,prepares=0,0,0
local request,destination,page
local pilot=Pilot.new({apply=function(value) calls=calls+1 request=value return true end,
 stop=function() stops=stops+1 end,prepare=function() prepares=prepares+1 end,
 page=function(value) page=value end,go=function(value) destination=value return true end})
local state={state='armed',targets={altitude=82},measuredHold={range={minAltitude=65,maxAltitude=105},requestedHeat=10.4,heat=10}}
local pose={timestamp=10,frame='world',inSublevel=true,vehicleId='ship',logicalPose={position={x=100,y=70,z=200}}}
pilot:refresh(state,{altitude=81.8,altitudeRate=0.01,heading=45},pose)
local raster=Surface.new(600,330) pilot:drawPixels(raster,600,330,p)
local measuredGlyph,targetGlyph=false,false
for y=65,91 do if raster.rows[y+1]:sub(7,220):find(string.char(p.text),1,true) then measuredGlyph=true end end
for y=124,151 do if raster.rows[y+1]:sub(7,220):find(string.char(p.accent),1,true) then targetGlyph=true end end
assert(measuredGlyph and targetGlyph,'large altitude numerals were clipped out of the dashboard')
local function draw(w,h)
 pilot:drawPixels(Surface.new(w,h),w,h,p)
 for _,hit in ipairs(pilot.hits) do
  local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'cockpit hit outside viewport')
 end
end
for _,size in ipairs({{156,180},{304,240},{600,330},{958,491}}) do
 draw(table.unpack(size))
 pilot:handlePixels({name='mouse_scroll',args={20,100,100}}) draw(table.unpack(size))
 pilot:handlePixels({name='mouse_scroll',args={-20,100,100}})
end
local function click(id)
 draw(600,330)
 for _,hit in ipairs(pilot.hits) do if hit.id==id then pilot:handlePixels({name='mouse_click',args={1,hit.rect.x+1,hit.rect.y+1}}) return end end
 error('Missing cockpit button '..id)
end
click('height:1') assert(pilot.draft.altitude==83 and calls==0,'height button actuated before Apply')
pilot:refresh(state,{altitude=81.8},pose) assert(pilot.draft.altitude==83,'live telemetry replaced operator draft')
click('apply') assert(calls==1 and request.altitude==83 and request.speed==nil and request.heading==nil,'altitude-only control invented horizontal authority')
click('edit') draw(600,330)
local editor=pilot.editor
assert(#editor.state.model.fields==1)
editor.buffers={[1]='84.5'} assert(editor.commit())
-- Apply through the actual graphical action path, not a direct draft setter.
editor:drawPixels(Surface.new(600,330),600,330,p)
for _,hit in ipairs(editor.state.hits) do if hit.id=='apply' then editor:handlePixels({name='mouse_click',args={1,hit.rect.x+1,hit.rect.y+1+editor.header}}) break end end
assert(calls==2 and request.altitude==84.5 and pilot.mode=='hold','native field not applied to live target')
click('map') draw(600,330)
pilot:handlePixels({name='mouse_click',args={1,pilot.map.x+pilot.map.w/2+20,pilot.map.y+pilot.map.h/2-15}})
assert(pilot.destination.x==120 and pilot.destination.z==185,'map click lost world coordinate transform')
click('go') assert(not destination and pilot.mode=='map','unsteerable balloon accepted route')
state.differentialReady=true state.maxSpeed=2
pilot:refresh(state,{altitude=81.8,heading=45},pose)
click('go') assert(pilot.mode=='confirm' and not destination,'map click started motors without confirmation')
local confirmed=pilot.pending
pilot:refresh(state,{altitude=80},pose)
pilot.editor:drawPixels(Surface.new(600,330),600,330,p)
for _,hit in ipairs(pilot.editor.state.hits) do if hit.id=='go' then pilot.editor:handlePixels({name='mouse_click',args={1,hit.rect.x+1,hit.rect.y+1+pilot.editor.header}}) break end end
assert(destination==confirmed and destination.x==120 and destination.z==185 and destination.altitude==82,'confirmed route parameters not frozen')
click('hold') click('edit') draw(600,330)
pilot.editor.buffers={[1]='invalid'}
pilot.editor:handlePixels({name='mouse_click',args={1,5,5}})
assert(stops==1 and pilot.mode=='hold','invalid field blocked emergency stop')
click('status') assert(pilot.mode=='status')
for _,size in ipairs({{156,180},{304,240},{600,330},{958,491}}) do draw(table.unpack(size)) end
assert(#pilot.editor.state.model.fields==0 and #pilot.editor.state.model.rows>10,'capability view became editable or lost evidence')
assert(calls==2 and prepares==0,'reading capabilities sent commands or started calibration')
pilot:handlePixels({name='mouse_click',args={1,5,5}})
assert(stops==2 and pilot.mode=='hold','capability page blocked urgent STOP')
click('prepare') assert(prepares==1 and calls==2,'opening cockpit repeated calibration')
click('back') assert(page=='flight')
click('map') pose.vehicleId='other-ship' pilot:refresh(state,{altitude=80},pose)
assert(not pilot.origin and not pilot.destination and not pilot.pending and pilot.mode=='hold','map selection crossed vehicle identity')
print('Pilot cockpit: responsive cached dashboard, altitude steps/native edits, explicit apply, bounded X/Z map selection, authority guard, frozen route confirmation and immediate STOP passed')
