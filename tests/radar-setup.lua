package.path="./?.lua;"..package.path
package.loaded["system.gui.components"]={}
package.loaded["system.gui.renderer"]={}
package.loaded["system.gui.form"]={new=function() return {scroll=1} end,field=function(object,key,label,kind,options)
  return {label=label,kind=kind,options=options,get=function() return object[key] end,set=function(value) object[key]=value end}
end}
local setup=require("system.navigation.radar_setup")
assert(setup.coordinates("-12, 70, 25","Bloc").x==-11.5)
assert(setup.coordinates("(1; 2; 3)","Centre").z==3)
assert(not setup.coordinates("1 2","Centre"))
assert(not setup.coordinates("1 nope 3","Centre"))
assert(not setup.coordinates("1 2 3 4","Centre"))
local snap={radars={{id="right",capabilities={position=false},rawTrackCount=235,range=1000}}}
local settings={radars={right={positionMode="manual",frame="world",positionX=10,positionY=20,positionZ=30,headingOffset=90,headingSign=-1,fov=60}}}
local wizard=setup.new(snap,"right",settings,false,function() error("implicit save") end,function() return true end)
local candidate=assert(wizard.candidate())
assert(candidate.positionX==10 and candidate.headingOffset==90 and candidate.fov==60)
wizard.entries.right.text="40 50 60"
candidate=assert(wizard.candidate())
assert(candidate.positionX==40 and settings.radars.right.positionX==10,"wizard overwrote persisted config before save")
local fresh=setup.new(snap,"right",{radars={}},false,function() end,function() return true end)
assert(not fresh.candidate(),"wizard invented missing manual coordinates")
fresh.entries.right.text="0 70 0"
candidate=assert(fresh.candidate())
assert(candidate.positionX==0 and candidate.frame=="world" and candidate.headingValidated~=true)
local auto=setup.new({radars={{id="plane",capabilities={position=true},rawPosition={x=1,y=2,z=3},frame="world"}}},"plane",{radars={}},false,function() end,function() return true end)
assert(auto.candidate().positionMode=="api")
print("radar setup coordinate parsing, preserved config and safe defaults passed")
