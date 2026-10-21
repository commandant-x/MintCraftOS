local pixels=require("system.gui.subpixel")
local renderer=require("system.gui.renderer")
local addon=require("system.libraries.addon")
local M={}
local function finiteVector(v)
  local p=addon.vec(v)
  return p and math.max(math.abs(p.x),math.abs(p.y),math.abs(p.z))<=1000000 and p or nil
end
-- All positions share the Sable plot frame. No proximity-based wiring or hull is invented.
function M.model(analysis,profile,snapshot)
  local out={points={},fresh=false,source="Saved geometry",com=profile.comVerified and finiteVector(profile.com) or nil}
  local function add(kind,row,force)
    local position=finiteVector(row.position)
    if position then out.points[#out.points+1]={kind=kind,id=row.id,position=position,force=force,row=row} end
  end
  if snapshot and snapshot.frame=="body_plot" and snapshot.vehicleId then
    out.source="Bridge "..tostring(snapshot.vehicleId)
    out.fresh=snapshot.ok==true
    out.complete=snapshot.inventoryComplete==true
    out.com=finiteVector(snapshot.centerOfMass)
    for _,r in ipairs(snapshot.actuators or {}) do add("thruster",r,r.geometryValid and finiteVector(r.direction) or nil) end
    for _,r in ipairs(snapshot.burners or {}) do add("burner",r) end
    for _,r in ipairs(snapshot.links or {}) do add(r.receiver and "RX" or "TX",r) end
  else
    for _,r in ipairs(analysis.rows or {}) do add("thruster",r,r.force) end
    for _,r in ipairs(profile.bridgeBurners or {}) do add("burner",r) end
    for _,r in ipairs(profile.bridgeLinks or {}) do add(r.receiver and "RX" or "TX",r) end
  end
  table.sort(out.points,function(a,b) return a.kind==b.kind and tostring(a.id)<tostring(b.id) or a.kind<b.kind end)
  return out
end
function M.project(p,view)
  if view=="side" then return p.z,p.y end
  if view=="front" then return p.x,p.y end
  if view=="iso" then return (p.x-p.z)*0.70710678,p.y*0.81649658+(p.x+p.z)*0.40824829 end
  return p.x,p.z
end
function M.details(model,index)
  local p=model.points[index]
  local rows={model.source,(model.fresh and "LIVE" or "STALE / saved; not live feedback"),"Equipment only: hull / shafts / nested sublevels unavailable."}
  if not p then rows[#rows+1]="No component selected" return rows end
  local r=p.row
  rows[#rows+1]=tostring(index).."/"..#model.points.." "..p.kind.." "..tostring(p.id)
  rows[#rows+1]=string.format("Plot XYZ: %.3f / %.3f / %.3f",p.position.x,p.position.y,p.position.z)
  if p.force then rows[#rows+1]=string.format("Force direction XYZ: %.3f / %.3f / %.3f",p.force.x,p.force.y,p.force.z) end
  if p.kind=="thruster" then
    rows[#rows+1]="Block: "..tostring(r.block or "unknown")
    rows[#rows+1]="Active: "..tostring(r.active).." / thrust: "..tostring(r.thrust).." (bridge units)"
    rows[#rows+1]="Output binding unverified; physical calibration required."
  elseif p.kind=="burner" then
    rows[#rows+1]="Signal: "..tostring(r.signal).."/15 / gas: "..tostring(r.gasOutput)
    rows[#rows+1]="Balloon associated: "..tostring(r.hasBalloon).." / gas active: "..tostring(r.gasActive)
    rows[#rows+1]="Balloon: "..tostring(r.balloonId or "unknown")
    rows[#rows+1]="Association: "..tostring(r.associationState or "unknown")
    rows[#rows+1]="Capacity: "..tostring(r.capacity).." / lift: "..tostring(r.lift)
  else
    for _,key in ipairs({"first","second"}) do
      local f=r[key] or {}
      rows[#rows+1]=key..": "..tostring(f.item).." / color "..tostring(f.dyedColor)
    end
    rows[#rows+1]="Signal: "..tostring(r.signal).." / actuator wiring unknown"
  end
  if model.com then rows[#rows+1]=string.format("COM XYZ: %.3f / %.3f / %.3f",model.com.x,model.com.y,model.com.z) end
  return rows
end
function M.draw(w,h,analysis,profile,side,options)
  options=options or {}
  local model=M.model(analysis,profile,options.snapshot)
  local view=options.view or (side and "side" or "top")
  local height=math.max(2,h-7)
  local canvas=pixels.new(w,height,colors.black)
  local cx,cy=canvas.width/2,canvas.height/2
  local points,radius={},1
  local center=model.com or {x=0,y=0,z=0}
  -- Zoom follows the selected component so off-centre equipment remains inspectable.
  local selected=model.points[options.index or 1]
  if (options.zoom or 1)>1 and selected then center=selected.position end
  local ox,oy=M.project(center,view)
  for i,p in ipairs(model.points) do
    local x,y=M.project(p.position,view)
    x,y=x-ox,y-oy
    radius=math.max(radius,math.abs(x),math.abs(y))
    points[#points+1]={x=x,y=y,index=i,component=p}
  end
  local scale=math.max(1,math.min(cx-4,cy-4))/radius*math.max(1,math.min(8,options.zoom or 1))
  canvas:line(cx,1,cx,canvas.height,colors.gray)
  canvas:line(1,cy,canvas.width,cy,colors.gray)
  for _,point in ipairs(points) do
    point.px=math.floor(cx+point.x*scale)
    point.py=math.floor(cy-point.y*scale)
    local p=point.component
    local color=({thruster=colors.lime,burner=colors.red,RX=colors.cyan,TX=colors.magenta})[p.kind]
    if p.force then
      local dx,dy=M.project(p.force,view)
      canvas:line(point.px,point.py,point.px+dx*6,point.py-dy*6,color)
    end
    canvas:rect(point.px-1,point.py-1,3,3,color)
    if point.index==(options.index or 1) then
      canvas:rect(point.px-2,point.py-2,1,5,colors.white)
      canvas:rect(point.px+2,point.py-2,1,5,colors.white)
    end
  end
  if model.com then
    local x,y=M.project(model.com,view)
    canvas:rect(math.floor(cx+(x-ox)*scale)-1,math.floor(cy-(y-oy)*scale)-1,3,3,colors.orange)
  end
  canvas:draw(1,4)
  for _,point in ipairs(points) do
    local x=math.floor((point.px-1)/2)+1
    local y=math.floor((point.py-1)/3)+4
    if x>=1 and x<=w and y>=4 and y<4+height then
      renderer.writeAt(x,y,renderer.crop(tostring(point.index),w-x+1),colors.white,colors.black)
    end
  end
  renderer.writeAt(1,3,renderer.crop(view.." | "..(model.fresh and (model.complete and "LIVE" or "LIVE partial") or "STALE/saved").." | equipment only; no hull",w),colors.cyan)
  local text=selected and (tostring(options.index or 1).."/"..#model.points.." "..selected.kind.." "..selected.id) or "No measured equipment; install bridge / Rescan"
  renderer.writeAt(1,h-3,renderer.crop(text,w),colors.white,colors.black)
  renderer.writeAt(1,h-2,renderer.crop("Lime thruster / red burner / cyan RX / magenta TX / orange COM",w),colors.lightGray,colors.black)
  return model
end
return M
