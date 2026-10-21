-- Retained layer composition; only damaged rectangles are rasterized.
local M={}
local function intersects(a,b)
  return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
M.intersects=intersects
function M.new()
  local scene={previous={},lastOrder="",stats={rectangles=0,layers=0}}
  function scene:invalidate() self.previous={} self.lastOrder="" end
  function scene:draw(surface,layers)
    assert(#layers<=256,"Too many graphical layers")
    local damage,now,order={},{},{}
    local function add(r)
      if not r or r.w<=0 or r.h<=0 then return end
      local n={x=r.x,y=r.y,w=r.w,h=r.h}
      local i=1
      while i<=#damage do
        local old=damage[i]
        if intersects(old,n) then
          local right,bottom=math.max(old.x+old.w,n.x+n.w),math.max(old.y+old.h,n.y+n.h)
          n.x,n.y=math.min(old.x,n.x),math.min(old.y,n.y)
          n.w,n.h=right-n.x,bottom-n.y
          table.remove(damage,i) i=1 -- Union can intersect an earlier rectangle.
        else i=i+1 end
      end
      damage[#damage+1]=n
    end
    for i,layer in ipairs(layers) do
      assert(not now[layer.id],"Duplicate graphical layer")
      order[i]=tostring(layer.id)
      now[layer.id]={x=layer.x,y=layer.y,w=layer.w,h=layer.h,revision=layer.revision,order=i}
      local old=self.previous[layer.id]
      if not old or old.x~=layer.x or old.y~=layer.y or old.w~=layer.w or old.h~=layer.h or old.revision~=layer.revision or old.order~=i then
        add(old) add(layer)
      end
    end
    for id,old in pairs(self.previous) do if not now[id] then add(old) end end
    local signature=table.concat(order,"|")
    -- Reordered layers damage their bounds, not the entire desktop.
    if self.width~=surface.width or self.height~=surface.height or #damage>64 then
      damage={{x=0,y=0,w=surface.width,h=surface.height}}
    end
    local previousClip=surface.clip
    local before,beforeDirty={},{}
    local ok,err=pcall(function()
      for _,rect in ipairs(damage) do
        for y=math.max(1,rect.y+1),math.min(surface.height,rect.y+rect.h) do
          if not before[y] then before[y],beforeDirty[y]=surface.rows[y],surface.dirty[y] end
        end
        surface:setClip(rect.x,rect.y,rect.w,rect.h)
        local first=1
        for i=#layers,1,-1 do
          local layer=layers[i]
          if layer.opaque~=false and layer.x<=rect.x and layer.y<=rect.y and
            layer.x+layer.w>=rect.x+rect.w and layer.y+layer.h>=rect.y+rect.h then first=i break end
        end
        for i=first,#layers do
          local layer=layers[i]
          if intersects(rect,layer) then layer.draw(surface) self.stats.layers=self.stats.layers+1 end
        end
      end
    end)
    surface.clip=previousClip
    if not ok then self:invalidate() error(err,0) end
    -- Layer overdraw may restore pixels to their original value. Compare final
    -- byte rows so unchanged controls are not transmitted again on every key.
    for y,old in pairs(before) do
      local row=surface.rows[y]
      if row==old then surface.dirty[y]=beforeDirty[y]
      elseif beforeDirty[y] and beforeDirty[y][1]==0 and beforeDirty[y][2]==surface.width then
        surface.dirty[y]=beforeDirty[y]
      else
        local left,right=0,surface.width
        while left<right and old:byte(left+1)==row:byte(left+1) do left=left+1 end
        while right>left and old:byte(right)==row:byte(right) do right=right-1 end
        local pending=beforeDirty[y]
        surface.dirty[y]=nil
        if surface.markDirty then
          -- Detect two short edge changes with a large identical center using
          -- C string comparison. Do not scan every changed pixel in Lua.
          local a,b=left+1,right-1
          while a<math.min(right,left+32) and old:byte(a+1)~=row:byte(a+1) do a=a+1 end
          if a<math.min(right,left+32) then
            while b>math.max(a,right-32) and old:byte(b)~=row:byte(b) do b=b-1 end
          else b=a end
          if b-a>=64 and old:sub(a+1,b)==row:sub(a+1,b) then
            surface:markDirty(y,left,a) surface:markDirty(y,b,right)
          else surface:markDirty(y,left,right) end
          if pending then
            for _,span in ipairs(pending.spans or {{pending[1],pending[2]}}) do surface:markDirty(y,span[1],span[2]) end
          end
        else surface.dirty[y]={math.min(left,pending and pending[1] or left),math.max(right,pending and pending[2] or right)} end
      end
    end
    self.previous,self.lastOrder=now,signature
    self.width,self.height=surface.width,surface.height
    self.stats.rectangles=self.stats.rectangles+#damage
    return #damage
  end
  return scene
end
return M
