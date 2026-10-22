-- Equipment-only native projection. Geometry comes from VehicleDiagram.model.
local Diagram=require('system.navigation.vehicle_diagram')
local primitives=require('system.graphics.primitives')
local ui=require('system.graphics.widgets')
local M={}
function M.draw(s,w,h,p,model,options)
 local hits={} options=options or {}
 if h<100 then return hits end
 local area={x=4,y=43,w=math.max(1,w-8),h=math.max(1,h-65)}
 ui.label(s,4,29,(model.fresh and 'LIVE ' or 'STALE / SAVED ')..'equipment only; hull unavailable',w-8,p.muted,p.panel)
 local center=model.com or {x=0,y=0,z=0}
 local selected=model.points[options.index or 1]
 if (options.zoom or 1)>1 and selected then center=selected.position end
 local view=options.view or 'top' local ox,oy=Diagram.project(center,view)
 local radius=1
 for _,point in ipairs(model.points) do local x,y=Diagram.project(point.position,view) radius=math.max(radius,math.abs(x-ox),math.abs(y-oy)) end
 local factor=math.max(1,math.min(area.w/2-5,area.h/2-5))/radius*math.max(1,math.min(8,options.zoom or 1))
 local cx,cy=area.x+area.w/2,area.y+area.h/2
 local clip=s:setClip(area.x,area.y,area.w,area.h)
 s:rect(area.x,area.y,area.w,area.h,p.desktop)
 primitives.line(s,cx,area.y,cx,area.y+area.h-1,p.border)
 primitives.line(s,area.x,cy,area.x+area.w-1,cy,p.border)
 local colors={thruster=5,burner=14,RX=9,TX=2}
 for i,point in ipairs(model.points) do
  local x,y=Diagram.project(point.position,view) x,y=math.floor(cx+(x-ox)*factor),math.floor(cy-(y-oy)*factor)
  local color=colors[point.kind] or p.text
  if point.force then local dx,dy=Diagram.project(point.force,view) primitives.line(s,x,y,x+dx*10,y-dy*10,color) end
  s:rect(x-2,y-2,5,5,color)
  if i==(options.index or 1) then primitives.rect(s,x-4,y-4,9,9,p.text) end
  if x>=area.x and x<area.x+area.w and y>=area.y and y<area.y+area.h then hits[#hits+1]={x=x,y=y,index=i,id=point.id} end
 end
 if model.com then local x,y=Diagram.project(model.com,view) s:rect(math.floor(cx+(x-ox)*factor)-2,math.floor(cy-(y-oy)*factor)-2,5,5,1) end
 s:setClip(clip.x,clip.y,clip.w,clip.h)
 ui.label(s,4,h-19,selected and (selected.kind..' '..tostring(selected.id)) or 'No selected equipment',w-8,p.muted,p.panel)
 return hits
end
return M
