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
      for _,old in ipairs(damage) do
        if intersects(old,n) then
          local right,bottom=math.max(old.x+old.w,n.x+n.w),math.max(old.y+old.h,n.y+n.h)
          old.x,old.y=math.min(old.x,n.x),math.min(old.y,n.y)
          old.w,old.h=right-old.x,bottom-old.y
          return
        end
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
    local ok,err=pcall(function()
      for _,rect in ipairs(damage) do
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
    self.previous,self.lastOrder=now,signature
    self.width,self.height=surface.width,surface.height
    self.stats.rectangles=self.stats.rectangles+#damage
    return #damage
  end
  return scene
end
return M
