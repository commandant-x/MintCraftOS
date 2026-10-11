local pixels=require("system.gui.subpixel")
local geometry=require("system.navigation.geometry")
local addon=require("system.libraries.addon")
local filters=require("system.navigation.radar_filter")
local M={}
local categoryPalette={players=colors.lightBlue,mobs=colors.orange,vessels=colors.white,projectiles=colors.red,other=colors.lightGray}
local unitCircle={}
for step=0,48 do local a=step*math.pi/24 unitCircle[#unitCircle+1]={math.sin(a),math.cos(a)} end
function M.horizon(w,h,pitch,roll)
  local canvas=pixels.new(w,h,colors.black)
  if not addon.finite(pitch) or not addon.finite(roll) then return canvas end
  local cx,cy=canvas.width/2,canvas.height/2
  local a=math.rad(roll)
  local s,c=math.sin(a),math.cos(a)
  local shift=math.max(-30,math.min(30,pitch))*canvas.height/60
  for y=1,canvas.height do
    for x=1,canvas.width do
      local d=(y-cy)*c+(x-cx)*s+shift
      canvas:pixel(x,y,math.abs(d)<0.7 and colors.white or d<0 and colors.lightBlue or colors.gray)
    end
  end
  for _,degree in ipairs({-20,-10,10,20}) do
    local dy=degree*canvas.height/60-shift
    local half=degree%20==0 and canvas.width/5 or canvas.width/8
    canvas:line(cx-half*c+dy*s,cy+dy*c+half*s,cx+half*c+dy*s,cy+dy*c-half*s,colors.white)
  end
  canvas:line(cx-6,cy,cx-2,cy,colors.yellow)
  canvas:line(cx+2,cy,cx+6,cy,colors.yellow)
  canvas:line(cx,cy-2,cx,cy+2,colors.yellow)
  return canvas
end
function M.radar(w,h,snap,radarId,selected,view)
  view=view or {}
  local canvas=pixels.new(w,h,colors.black)
  local radar
  for _,row in ipairs(snap.radars or {}) do if row.id==radarId then radar=row break end end
  radar=radar or (snap.radars or {})[1]
  if view.network then
    local minX,maxX,minZ,maxZ,altitude
    for _,row in ipairs(snap.radars or {}) do if row.position and addon.finite(row.range) and row.range>0 then
      local p,r=row.position,row.range
      minX=math.min(minX or math.huge,p.x-r) maxX=math.max(maxX or -math.huge,p.x+r)
      minZ=math.min(minZ or math.huge,p.z-r) maxZ=math.max(maxZ or -math.huge,p.z+r)
      altitude=altitude or p.y
    end end
    if minX then radar={position={x=(minX+maxX)/2,y=altitude,z=(minZ+maxZ)/2},range=math.max(maxX-minX,maxZ-minZ)/2*(view.three and 1.5 or 1.05)} end
  end
  local hits,labels={},{}
  if not radar or not radar.position or not addon.finite(radar.range) or radar.range<=0 then return canvas,hits,labels,"Radar world frame/range unavailable" end
  local cx,cy=(canvas.width+1)/2,(canvas.height+1)/2
  local radius=math.max(2,math.min(canvas.width,canvas.height)/2-2)
  local range=radar.range/(view.zoom or 1)
  local heading=0
  if view.relative then heading=radar.heading end
  if heading==nil then return canvas,hits,labels,"Heading unavailable" end
  local headingRadians=math.rad(heading)
  local sh,ch=math.sin(headingRadians),math.cos(headingRadians)
  local yaw,pitch=math.rad(view.yaw or 30),math.rad(view.pitch or 45)
  local sy,cyaw,sp,cp=math.sin(yaw),math.cos(yaw),math.sin(pitch),math.cos(pitch)
  local function project(position)
    if not addon.vec(position) then return end
    local dx,dy,dz=position.x-radar.position.x,position.y-radar.position.y,position.z-radar.position.z
    local x,y,z=dx*ch-dz*sh,dy,dx*sh+dz*ch
    if view.three then
      x,z=x*cyaw-z*sy,x*sy+z*cyaw
      y,z=y*cp-z*sp,y*sp+z*cp
      return cx+x/range*radius,cy-y/range*radius,z
    end
    return cx+x/range*radius,cy+(view.relative and -1 or 1)*z/range*radius,y
  end
  local function segment(a,b,color)
    local x1,y1=project(a) local x2,y2=project(b)
    if x1 and x2 then canvas:line(x1,y1,x2,y2,color) end
  end
  local o=radar.position
  local function circle(position,r,color)
    local previous
    for _,point in ipairs(unitCircle) do
      local p={x=position.x+point[1]*r,y=position.y,z=position.z+point[2]*r}
      if previous then segment(previous,p,color) end previous=p
    end
  end
  if view.three then
    circle(o,range,colors.gray)
    for _,d in ipairs({{range,0,0},{0,range,0},{0,0,range}}) do segment(o,{x=o.x+d[1],y=o.y+d[2],z=o.z+d[3]},colors.gray) end
  else
    for _,factor in ipairs({0.5,1}) do circle(o,range*factor,colors.gray) end
    canvas:line(cx-radius,cy,cx+radius,cy,colors.gray)
    canvas:line(cx,cy-radius,cx,cy+radius,colors.gray)
  end
  local function beam(station)
    if not addon.finite(station.heading) or not addon.finite(station.fov) or station.running==false then return end
    local centre=station.position
    local elevations={0}
    local heights={0}
    if view.three and addon.finite(station.halfHeight) then heights={-station.halfHeight,station.halfHeight}
    elseif view.three and addon.finite(station.verticalFov) then elevations={-station.verticalFov/2,station.verticalFov/2} end
    local rims={}
    local planes=math.max(#heights,#elevations)
    for ring=1,planes do
      local height=heights[ring] or 0
      local e=math.rad(elevations[ring] or 0)
      local start={x=centre.x,y=centre.y+height,z=centre.z}
      local previous
      rims[ring]={}
      for step=0,24 do
        local a=math.rad(station.heading-station.fov/2+station.fov*step/24)
        local p={x=centre.x+math.sin(a)*station.range*math.cos(e),y=centre.y+height+math.sin(e)*station.range,z=centre.z+math.cos(a)*station.range*math.cos(e)}
        if previous then segment(previous,p,colors.lime) else segment(start,p,colors.lime) end
        if step%6==0 then segment(start,p,colors.green) end
        previous=p rims[ring][step+1]=p
      end
      segment(start,previous,colors.lime)
    end
    if rims[2] then for _,index in ipairs({1,7,13,19,25}) do segment(rims[1][index],rims[2][index],colors.green) end end
    local a=math.rad(station.heading)
    segment(centre,{x=centre.x+math.sin(a)*station.range,y=centre.y,z=centre.z+math.cos(a)*station.range},colors.yellow)
  end
    for _,station in ipairs(snap.radars or {}) do if station.position and addon.finite(station.range) then
      circle(station.position,station.range,station.running==false and colors.gray or station.remote and colors.blue or colors.green)
      beam(station)
      local x,y=project(station.position)
      if x and x>=1 and x<=canvas.width and y>=1 and y<=canvas.height then
        canvas:rect(math.floor(x)-1,math.floor(y)-1,3,3,colors.cyan)
        if view.network then labels[#labels+1]={x=math.ceil(x/2)+2,y=math.ceil(y/3),text=station.name,color=colors.cyan} end
      end
    end end
  local zone=snap.zone
  if zone and zone.alerts and addon.finite(zone.radius) and addon.vec({x=zone.x,y=zone.y,z=zone.z}) then
    circle({x=zone.x,y=zone.y,z=zone.z},zone.radius,colors.orange)
  end
  if not view.three and not view.relative then labels[#labels+1]={x=math.max(1,math.floor(cx/2)),y=1,text="N (-Z)",color=colors.white} end
  for _,target in ipairs(snap.targets or {}) do
    if filters.visible(target,view.filters) then
    local x,y=project(target.position)
    if x and x>=2 and y>=2 and x<canvas.width and y<canvas.height then
      local color=target.stale and colors.gray or target.id==selected and colors.yellow or target.synthetic and colors.orange or target.friendly and colors.lime or categoryPalette[filters.category(target)]
      local previous
      for _,point in ipairs(target.history or {}) do
        if previous then segment(previous,point.position,colors.lightGray) end previous=point.position
      end
      canvas:rect(math.floor(x)-1,math.floor(y)-1,3,3,color)
      hits[#hits+1]={id=target.id,x=math.ceil(x/2),y=math.ceil(y/3),w=3,h=2}
      labels[#labels+1]={id=target.id,x=math.ceil(x/2)+2,y=math.ceil(y/3),text=target.label,color=color}
    end
    end
  end
  canvas:line(cx-3,cy,cx+3,cy,colors.cyan)
  canvas:line(cx,cy-3,cx,cy+3,colors.cyan)
  return canvas,hits,labels,string.format("View %.0fm | %s",range,view.three and "schematic 3D" or "world 2D")
end
return M
