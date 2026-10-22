-- Cached voxel raster, with actual depth order and three cube faces in 3D.
local Hull=require('system.navigation.hull_geometry')
local Surface=require('system.graphics.surface')
local M={}
local blocksKey,blocks,center,occupied,cacheKey,cache
function M.blocks(scan)
 if not scan then return {} end
 local key=scan.token..':'..scan.nextPage
 if key~=blocksKey then
  blocks=Hull.blocks(scan) blocksKey=key center=nil occupied={}
  if #blocks>0 then
   local ax,ay,az,bx,by,bz=math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
   for _,v in ipairs(blocks) do occupied[v.x..':'..v.y..':'..v.z]=true ax,ay,az=math.min(ax,v.x),math.min(ay,v.y),math.min(az,v.z) bx,by,bz=math.max(bx,v.x+1),math.max(by,v.y+1),math.max(bz,v.z+1) end
   center={x=(ax+bx)/2,y=(ay+by)/2,z=(az+bz)/2}
  end
 end
 return blocks,center,occupied
end
local function quad(s,points,color)
 local low,high=math.huge,-math.huge
 for _,p in ipairs(points) do low=math.min(low,p[2]) high=math.max(high,p[2]) end
 for y=math.max(s.clip.y,math.ceil(low)),math.min(s.clip.y+s.clip.h-1,math.floor(high)) do
  local xs={}
  for i,a in ipairs(points) do local b=points[i%#points+1]
   if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2]) end
  end
  table.sort(xs)
  if #xs>=2 then local left=math.ceil(xs[1]) s:rect(left,y,math.floor(xs[#xs])-left+1,1,color) end
 end
end
function M.draw(s,model,project,view,turn,area,cx,cy,ox,oy,factor,slice)
 local key=table.concat({model.hull.token,model.hull.nextPage,s.width,s.height,view,turn or 0,cx,cy,ox,oy,factor,slice or 'all'},':')
 local sorted={}
 if key~=cacheKey then
  cache=Surface.new(s.width,s.height,15) cache:setClip(area.x,area.y,area.w,area.h)
  local function solid(x,y,z) return (not slice or y<=slice) and model.occupied and model.occupied[x..':'..y..':'..z] end
  local dirs={{{1,0},{0,1}},{{0,-1},{1,0}},{{-1,0},{0,-1}},{{0,1},{-1,0}}}
  local right,left=table.unpack(dirs[(turn or 0)%4+1])
  for _,b in ipairs(model.blocks or {}) do
   if not slice or b.y<=slice then
   local x,y=project({x=b.x+0.5,y=b.y+0.5,z=b.z+0.5})
   local rx,rz=b.x,b.z
   for _=1,turn or 0 do rx,rz=-rz,rx end
   local depth=view=='iso' and (rx+rz+b.y) or view=='side' and rx or view=='front' and rz or b.y
   local top=not solid(b.x,b.y+1,b.z)
   local l=not solid(b.x+left[1],b.y,b.z+left[2]) local r=not solid(b.x+right[1],b.y,b.z+right[2])
   local visible=view=='iso' and (top or l or r) or view=='side' and r or view=='front' and l or view=='top' and top
   if visible then sorted[#sorted+1]={b=b,x=cx+(x-ox)*factor,y=cy-(y-oy)*factor,depth=depth,top=top,left=l,right=r} end
  end
   end
  table.sort(sorted,function(a,b) return a.depth<b.depth end)
  for _,v in ipairs(sorted) do
   local wood=v.b.material.block:find('wood',1,true) or v.b.material.block:find('planks',1,true) or v.b.material.block:find('log',1,true)
   if v.x>=area.x-factor*2 and v.x<area.x+area.w+factor*2 and v.y>=area.y-factor*2 and v.y<area.y+area.h+factor*2 then
    if view=='iso' and factor>=2 then
     local x,y=v.x,v.y local a,b=factor*0.70710678,factor*0.40824829 local h=factor*0.81649658
     if v.top then quad(cache,{{x-a,y-h/2},{x,y-h/2-b},{x+a,y-h/2},{x,y-h/2+b}},wood and 4 or 8) end
     if v.left then quad(cache,{{x-a,y-h/2},{x,y-h/2+b},{x,y+h/2+b},{x-a,y+h/2}},wood and 12 or 7) end
     if v.right then quad(cache,{{x,y-h/2+b},{x+a,y-h/2},{x+a,y+h/2},{x,y+h/2+b}},wood and 1 or 8) end
    else cache:rect(math.floor(v.x-factor/2),math.floor(v.y-factor/2),math.max(1,math.ceil(factor)),math.max(1,math.ceil(factor)),wood and 12 or 8) end
   end
  end
  cacheKey=key M.sorted=sorted
 end
 for y=area.y,area.y+area.h-1 do s:span(area.x,y,cache.rows[y+1]:sub(area.x+1,area.x+area.w)) end
 local pickRows=M.sorted
 return function(x,y)
  -- Reverse painter order, testing each projected voxel silhouette.
  for i=#pickRows,1,-1 do
   local v=pickRows[i] local dx,dy=math.abs(x-v.x),y-v.y
   if view=='iso' and factor>=2 then
    local a,b,h=factor*.70710678,factor*.40824829,factor*.81649658
    if dx<=a and dy>=-h/2-b+dx/a*b and dy<=h/2+b-dx/a*b then return v.b end
   elseif dx<=math.max(1,factor/2) and math.abs(dy)<=math.max(1,factor/2) then return v.b end
  end
 end
end
return M
