local Surface=require("system.graphics.surface")
local M={}
local serial=0
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
function M.new(t,preference,options)
  options=options or {}
  serial=serial+1
  local caps=M.detect(t)
  local b={target=t,caps=caps,mode=0,generation=serial,frames=0,bytes=0,regions=0,lastError=nil,paletteBackup={},requests=0,skippedPresents=0,lines=0,drawCalls=0,maxDrawSeconds=0,
    optimized=options.optimized~=false,batchRows=options.batchRows or 8,palettePending=false}
  assert(b.batchRows==1 or b.batchRows==4 or b.batchRows==8 or b.batchRows==16 or b.batchRows==32,"Invalid batch size")
  local function submit(x,y,rows)
    b.drawCalls=b.drawCalls+1
    return t.drawPixels(x,y,rows)
  end
  function b:palette(index,rgb)
    assert(self.mode==2 and index>=16 and index<=255 and index%1==0,"Extended palette unavailable")
    if not self.paletteBackup[index] then self.paletteBackup[index]={t.getPaletteColor(index)} end
    t.setPaletteColor(index,rgb) self.palettePending=true
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
    self.requests=self.requests+1
    if self.mode==0 then return false,self.lastError end
    if self.optimized and not next(self.surface.dirty) and not self.palettePending then
      self.skippedPresents=self.skippedPresents+1
      return true
    end
    local started=os.clock()
    local frozen,freezeRead=false,false
    local ok,err=pcall(function()
      if caps.freeze then frozen=t.getFrozen() freezeRead=true t.setFrozen(true) end
      local y=1
      while y<=self.surface.height do
        local d=self.surface.dirty[y]
        if not d then y=y+1
        else
          local spans=self.optimized and d.spans or nil
          spans=spans or {{d[1],d[2]}}
          local count=1
          if self.optimized then
            while count<self.batchRows and y+count<=self.surface.height do
              local n=self.surface.dirty[y+count]
              if not n or n[1]~=d[1] or n[2]~=d[2] then break end
              local other=n.spans or {{n[1],n[2]}}
              local compatible=#other==#spans
              if compatible then
                for i,v in ipairs(spans) do if v[1]~=other[i][1] or v[2]~=other[i][2] then compatible=false break end end
              end
              if not compatible then break end
              count=count+1
            end
          end
          for _,span in ipairs(spans) do
            local rows={}
            for i=0,count-1 do rows[i+1]=self.surface.rows[y+i]:sub(span[1]+1,span[2]) end
            if count>1 then
              local accepted=pcall(submit,span[1],y-1,rows)
              if not accepted then
                -- Older targets may support byte rows but reject multi-row calls.
                self.batchRows=1
                for i,row in ipairs(rows) do
                  submit(span[1],y+i-2,{row})
                end
              end
            else submit(span[1],y-1,rows) end
            self.bytes=self.bytes+(span[2]-span[1])*count
            self.regions=self.regions+1
          end
          self.lines=self.lines+count y=y+count
        end
      end
    end)
    if caps.freeze and freezeRead then
      local restored,problem=pcall(t.setFrozen,frozen)
      if not restored then ok,err=false,problem end
    end
    if not ok then
      self.surface.dirty={} self.palettePending=false
      self.lastError=tostring(err) self:close() return false,self.lastError
    end
    self.surface.dirty={} self.palettePending=false self.frames=self.frames+1
    self.lastDrawSeconds=os.clock()-started self.maxDrawSeconds=math.max(self.maxDrawSeconds,self.lastDrawSeconds)
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
      submit(0,0,{string.char(15)})
      b.surface=surface b.mode=mode caps.pixelWidth,caps.pixelHeight=w,h
      caps.backend=mode==2 and "PIXEL256" or "PIXEL16"
    end)
    if ok then return b end
    b.lastError=tostring(err) b:close()
  end
  return b
end
return M
