package.path='./?.lua;'..package.path
local H=require('system.navigation.hull_geometry')
local function page(n,total,runs)
 return {schema=1,ok=true,readOnly=true,vehicleId='ship',frame='body_plot',units='block',token='real-scan',page=n or 0,pages=total or 1,
  origin={x=-16,y=0,z=32},startedTick=100,observedTick=110,coverageComplete=true,palette={{block='minecraft:oak_planks',state='oak_planks'}},runs=runs or '0:16:1;256:1:1;4095:1:1;'}
end
local s=H.new('ship') assert(H.accept(s,page())) assert(s.state=='complete' and s.count==18 and s.coverage)
local b=H.blocks(s) assert(#b==18 and b[1].x==-16 and b[16].x==-1 and b[17].y==1 and b[18].x==-1 and b[18].y==15 and b[18].z==47)
for _,mutate in ipairs({function(p)p.vehicleId='other'end,function(p)p.frame='world'end,function(p)p.readOnly=false end,
 function(p)p.origin.x=0/0 end,function(p)p.runs='0:2:1;1:1:1;'end,function(p)p.runs='4095:2:1;'end,function(p)p.runs='0:1:2;'end,
 function(p)p.runs='junk0:1:1;'end,function(p)p.page=1 end,function(p)p.observedTick=99 end}) do
 local t=H.new('ship') local p=page() mutate(p) assert(not H.accept(t,p)) assert(t.count==0 and #t.pages==0,'bad page partially committed')
end
s=H.new('ship') assert(H.accept(s,page(0,2,'0:1:1;'))) local p=page(1,2,'0:1:1;') p.token='new' assert(not H.accept(s,p)) assert(s.count==1)
p=page(1,2,'0:1:1;') p.coverageComplete=false assert(not H.accept(s,p))
s=H.new('ship') p=page() p.coverageComplete=false assert(H.accept(s,p)) assert(not s.coverage and H.label(s):find('partial',1,true))
s=H.new('ship') s.count=H.MAX_BLOCKS assert(not H.accept(s,page()))
-- Raster uses surveyed volume, with real 3D faces, all orthographic views and rotation.
colors={} for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
local D=require('system.navigation.vehicle_diagram') local N=require('system.navigation.equipment_pixels') local Surface=require('system.graphics.surface')
s=H.new('ship') assert(H.accept(s,page()))
local m=D.model({}, {}, {ok=true,vehicleId='ship',frame='body_plot',inventoryComplete=true,hull=s,actuators={},burners={},links={}})
assert(#m.blocks==18 and #m.points==0)
for _,view in ipairs({'top','side','front','iso'}) do for turn=0,3 do
 local canvas=Surface.new(200,150) local hits,pick=N.draw(canvas,200,150,{desktop=15,panel=7,muted=8,text=0,border=8},m,{view=view,turn=turn})
 assert(#hits==0 and type(pick)=='function') local pixels=0
 for y=44,120 do pixels=pixels+#canvas.rows[y]:gsub(string.char(15),'') end
 assert(pixels>0,'actual hull absent from raster')
 for _,row in ipairs(canvas.rows) do assert(#row==200,'raster escaped canvas') end
end end
local cut=Surface.new(200,150)
N.draw(cut,200,150,{desktop=15,panel=7,muted=8,text=0,border=8},m,{view='iso',slice=0})
assert(#require('system.navigation.hull_pixels').sorted==16,'cutaway retained hidden upper layers or lost lower interior')
local p=page() p.token='solid-cube' p.runs=''
for y=0,2 do for z=0,2 do p.runs=p.runs..(256*y+16*z)..':3:1;' end end
s=H.new('ship') assert(H.accept(s,p))
local cube=D.model({}, {}, {ok=true,vehicleId='ship',frame='body_plot',inventoryComplete=true,hull=s,actuators={},burners={},links={}})
N.draw(cut,200,150,{desktop=15,panel=7,muted=8,text=0,border=8},cube,{view='iso'})
assert(#require('system.navigation.hull_pixels').sorted==19,'occluded solid voxels unnecessarily rasterized')
N.draw(cut,200,150,{desktop=15,panel=7,muted=8,text=0,border=8},cube,{view='iso',slice=0})
assert(#require('system.navigation.hull_pixels').sorted==9,'cutaway failed to expose internal faces')
assert(H.label(nil):find('unavailable',1,true))
print('hull: lossless sections, exact XYZ, palette/run/frame/clock/identity validation, partial coverage, bounded memory and 2D/3D rotated voxel raster passed')
