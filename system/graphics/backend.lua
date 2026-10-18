local Surface=require("system.graphics.surface")
local M={}
local function dimensions(t,mode)
  local ok,w,h=pcall(t.getSize,mode)
  if ok and type(w)=="number" and type(h)=="number" and w%1==0 and h%1==0
    and w>0 and h>0 and w*h<=1048576 then return w,h end
end
function M.detect(t)
  local w,h=dimensions(t,0)
  local caps={backend="TEXT",textWidth=w,textHeight=h,
    graphics=type(t.setGraphicsMode)=="function" and type(t.getGraphicsMode)=="function"
      and type(t.drawPixels)=="function",palette=type(t.setPaletteColor)=="function" and type(t.getPaletteColor)=="function",
    freeze=type(t.setFrozen)=="function" and type(t.getFrozen)=="function"}
  if caps.graphics then caps.pixelWidth,caps.pixelHeight=dimensions(t,2) end
  if type(t.isColor)=="function" then local ok,value=pcall(t.isColor) if ok then caps.color=value==true end end
  return caps
end
function M.new(t,preference)
  local caps=M.detect(t)
  local b={target=t,caps=caps,mode=0,frames=0,bytes=0,regions=0,lastError=nil,paletteBackup={}}
  function b:palette(index,rgb)
    assert(self.mode==2 and index>=16 and index<=255 and index%1==0,"Extended palette unavailable")
    if not self.paletteBackup[index] then self.paletteBackup[index]={t.getPaletteColor(index)} end
    t.setPaletteColor(index,rgb)
  end
  function b:close()
    if type(t.setFrozen)=="function" then pcall(t.setFrozen,false) end
    if self.mode==2 then
      for index,values in pairs(self.paletteBackup) do pcall(t.setPaletteColor,index,table.unpack(values)) end
    end
    self.paletteBackup={}
    if type(t.setGraphicsMode)=="function" then pcall(t.setGraphicsMode,0) end
    self.mode=0 self.caps.backend="TEXT"
  end
  function b:present()
    if self.mode==0 then return false,self.lastError end
    local started=os.clock()
    local frozen=false
    local ok,err=pcall(function()
      if caps.freeze then frozen=t.getFrozen() t.setFrozen(true) end
      for y=1,self.surface.height do
        local d=self.surface.dirty[y]
        if d then
          t.drawPixels(d[1],y-1,{self.surface.rows[y]:sub(d[1]+1,d[2])})
          self.bytes=self.bytes+d[2]-d[1] self.regions=self.regions+1
        end
      end
    end)
    if caps.freeze then
      local restored,problem=pcall(t.setFrozen,frozen)
      if not restored then ok,err=false,problem end
    end
    if not ok then self.lastError=tostring(err) self:close() return false,self.lastError end
    self.surface.dirty={} self.frames=self.frames+1 self.lastDrawSeconds=os.clock()-started
    return true
  end
  if preference=="text" or not caps.graphics then return b end
  local modes=preference=="pixel16" and {1} or {2,1}
  for _,mode in ipairs(modes) do
    local ok,err=pcall(function()
      t.setGraphicsMode(mode)
      assert(t.getGraphicsMode()==mode,"Graphics mode not activated")
      local w,h=dimensions(t,mode)
      assert(w and h,"Invalid pixel dimensions")
      local surface=Surface.new(w,h,15)
      -- Probe the actual byte-row overload, not just the presence of the method.
      t.drawPixels(0,0,{string.char(15)})
      b.surface=surface b.mode=mode caps.pixelWidth,caps.pixelHeight=w,h
      caps.backend=mode==2 and "PIXEL256" or "PIXEL16"
    end)
    if ok then return b end
    b.lastError=tostring(err) b:close()
  end
  return b
end
return M
