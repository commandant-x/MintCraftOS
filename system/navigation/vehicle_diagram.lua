local pixels=require("system.gui.subpixel")
local renderer=require("system.gui.renderer")
local M={}
function M.draw(w,h,analysis,profile,side)
  local height=math.max(2,h-7)
  local canvas=pixels.new(w,height,colors.black)
  local cx,cy=canvas.width/2,canvas.height/2
  local radius=1
  local points={}
  for i,row in ipairs(analysis.rows) do
    if row.position then
      local x=side and row.position.z-profile.com.z or row.position.x-profile.com.x
      local y=side and row.position.y-profile.com.y or row.position.z-profile.com.z
      radius=math.max(radius,math.abs(x),math.abs(y))
      points[#points+1]={x=x,y=y,index=i,row=row}
    end
  end
  local scale=math.max(1,math.min(cx-4,cy-4))/radius
  canvas:line(cx,1,cx,canvas.height,colors.gray)
  canvas:line(1,cy,canvas.width,cy,colors.gray)
  for _,point in ipairs(points) do
    point.px=math.floor(cx+point.x*scale)
    point.py=math.floor(cy-point.y*scale)
    canvas:line(cx,cy,point.px,point.py,colors.lightGray)
    local palette={lift=colors.lime,propulsion=colors.red,stabilization=colors.cyan,yaw=colors.yellow,strafe=colors.magenta,mixed=colors.lightBlue}
    local color=palette[point.row.role] or colors.lightGray
    local force=point.row.force
    local dx,dy=side and force.z or force.x,side and force.y or force.z
    canvas:line(point.px,point.py,point.px+dx*6,point.py-dy*6,color)
    canvas:rect(point.px-2,point.py-2,5,5,color)
  end
  if profile.comVerified then canvas:rect(cx-1,cy-1,3,3,colors.orange) end
  canvas:draw(1,4)
  for _,point in ipairs(points) do
    local x=math.max(1,math.min(w,math.floor((point.px-1)/2)+1))
    local y=math.max(4,math.min(3+height,math.floor((point.py-1)/3)+4))
    renderer.writeAt(x,y,renderer.crop(tostring(point.index),w-x+1),colors.white,colors.black)
  end
  renderer.writeAt(1,3,renderer.crop(side and "Body side: +Z right / +Y up | orange COM" or "Body top: +X right / +Z up | orange COM",w),colors.cyan)
  if #points==0 then renderer.writeAt(1,5,renderer.crop("No verified actuator geometry / COM",w),colors.orange,colors.black) end
end
return M
