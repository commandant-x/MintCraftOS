colors={} for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
package.path='./?.lua;'..package.path
local Surface=require('system.graphics.surface')
local Diagram=require('system.navigation.vehicle_diagram')
local Native=require('system.navigation.equipment_pixels')
local model=Diagram.model({}, {}, {ok=true,frame='body_plot',vehicleId='real-fixture',inventoryComplete=true,centerOfMass={x=0,y=0,z=0},actuators={{id='thruster',position={x=2,y=1,z=3},geometryValid=true,direction={x=0,y=0,z=1}}},burners={{id='burner',position={x=-1,y=0,z=2}}},links={}})
local p={desktop=15,panel=7,text=0,muted=8,border=8}
assert(#model.points==2)
for _,view in ipairs({'top','side','front','iso'}) do
 for _,size in ipairs({{154,105},{600,304}}) do
  local w,h=table.unpack(size) local s=Surface.new(w,h)
  local hits=Native.draw(s,w,h,p,model,{view=view,index=1,zoom=1})
  assert(#hits==2,'measured component lost in native projection')
  for _,hit in ipairs(hits) do assert(hit.x>=0 and hit.x<w and hit.y>=0 and hit.y<h and model.points[hit.index].id==hit.id) end
  for _,row in ipairs(s.rows) do assert(#row==w) end
 end
end
local unknown=Diagram.model({}, {}, nil) assert(#unknown.points==0 and not unknown.com,'unknown geometry became an invented hull/COM')
print('native equipment: all projections, real component selection, bounded canvas and unavailable geometry without invented hull passed')
