local M = {}

function M.new(resolveTarget, onOutputFailure, options)
  local surface, parent, width, height
  local pixel, preference = nil, options and options.mode or "text"
  local pixelWidth, pixelHeight
  local previous = {}
  local frame = {}
  local failedTarget, fallbackTarget
  local function outputFailure(target, problem)
    if options and options.onGraphicsFailure then pcall(options.onGraphicsFailure,problem) end
    if pixel then pixel:close() pixel=nil end
    previous = {}
    local native = term.native and term.native() or target
    if type(native.setFrozen)=="function" then pcall(native.setFrozen,false) end
    if type(native.setGraphicsMode)=="function" then pcall(native.setGraphicsMode,0) end
    term.redirect(native)
    if target == native then error(problem, 0) end
    failedTarget, fallbackTarget = target, native
    surface, parent = nil, nil
    if onOutputFailure then pcall(onOutputFailure, target, problem) end
    return native
  end
  local stats = { frames = 0, rows = 0, cells = 0 }
  return {
    configure = function(_, mode)
      assert(mode=="text" or mode=="auto" or mode=="pixel16", "Invalid rendering mode")
      if pixel then pixel:close() end
      pixel, parent, preference, previous=nil,nil,mode,{}
    end,
    setBackendOptions=function(_,value)
      options=options or {} options.backendOptions=value
      if pixel then pixel.optimized=value.optimized pixel.batchRows=value.batchRows end
    end,
    close = function() if pixel then pixel:close() end end,
    capabilities=function()
      local result={backend="TEXT",textWidth=width,textHeight=height,probed=false}
      if pixel then
        for key,value in pairs(pixel.caps) do result[key]=value end
        result.probed=true result.error=pixel.lastError
      end
      return result
    end,
    invalidate = function() previous = {} failedTarget = nil end,
    stats = function()
      return { frames=stats.frames, rows=stats.rows, cells=stats.cells,
        backend=pixel and pixel.caps.backend or "TEXT",pixelWidth=pixelWidth,pixelHeight=pixelHeight,
        generation=pixel and pixel.generation,
        bytes=pixel and pixel.bytes or 0,regions=pixel and pixel.regions or 0,
        lastDrawSeconds=pixel and pixel.lastDrawSeconds,lastError=pixel and pixel.lastError,
        presentRequests=pixel and pixel.requests or 0,skippedPresents=pixel and pixel.skippedPresents or 0,
        presentedFrames=pixel and pixel.frames or 0,drawCalls=pixel and pixel.drawCalls or 0,
        dirtyLines=pixel and pixel.lines or 0,maxDrawSeconds=pixel and pixel.maxDrawSeconds or 0,
        compositionSeconds=stats.compositionSeconds,prepareSeconds=stats.prepareSeconds,
        maxCompositionSeconds=stats.maxCompositionSeconds,maxPrepareSeconds=stats.maxPrepareSeconds }
    end,
    draw = function(_, render)
      local target = resolveTarget and resolveTarget() or term.current()
      if target == failedTarget then target = fallbackTarget end
      local sized, w, h = pcall(target.getSize)
      if not sized then
        target = outputFailure(target, w)
        w, h = target.getSize()
      end
      if parent ~= target then
        if pixel then pixel:close() end
        pixel=nil pixelWidth,pixelHeight=nil,nil
        if preference~="text" then
          pixel=require("system.graphics.backend").new(target,preference,options and options.backendOptions)
          pixelWidth,pixelHeight=pixel.caps.pixelWidth,pixel.caps.pixelHeight
          if pixel.mode==0 and pixel.lastError and options and options.onGraphicsFailure then
            pcall(options.onGraphicsFailure,pixel.lastError)
          end
        else
          -- Peripheral graphics state survives a computer reboot. A fresh text
          -- buffer must never inherit an indexed physical palette.
          if type(target.setFrozen)=="function" then pcall(target.setFrozen,false) end
          if type(target.setGraphicsMode)=="function" then
            local reset,problem=pcall(target.setGraphicsMode,0)
            if not reset then target=outputFailure(target,problem) w,h=target.getSize() end
          end
        end
        parent, width, height = target, w, h
        local bufferParent=parent
        if pixel and pixel.mode~=0 then bufferParent=require("system.graphics.legacy").parent(parent,pixel.mode) end
        local created,result=pcall(window.create,bufferParent,1,1,w,h,false)
        if not created and pixel and pixel.mode~=0 then
          pixel.lastError=tostring(result) pixel:close() previous={}
          if options and options.onGraphicsFailure then pcall(options.onGraphicsFailure,result) end
          created,result=pcall(window.create,parent,1,1,w,h,false)
        end
        if not created then error(result,0) end
        surface=result
        if pixel and pixel.mode~=0 then require("system.graphics.legacy").buffer(surface) end
        previous = {}
      elseif width ~= w or height ~= h then
        if pixel then
          pixel:close()
          pixel=require("system.graphics.backend").new(target,preference,options and options.backendOptions)
          pixelWidth,pixelHeight=pixel.caps.pixelWidth,pixel.caps.pixelHeight
        end
        surface.reposition(1, 1, w, h)
        width, height = w, h
        previous = {}
      end
      if pixel and pixel.mode~=0 then
        local valid,pw,ph=pcall(target.getSize,pixel.mode)
        if not valid then
          pixel.lastError=tostring(pw) pixel:close() previous={}
          if options and options.onGraphicsFailure then pcall(options.onGraphicsFailure,pw) end
        elseif pw~=pixelWidth or ph~=pixelHeight then
          pixel:close() pixel=require("system.graphics.backend").new(target,preference,options and options.backendOptions)
          pixelWidth,pixelHeight=pixel.caps.pixelWidth,pixel.caps.pixelHeight
          previous={}
        end
      end
      if pixel and pixel.mode~=0 and options and options.beforeRender then
        local started=os.clock()
        local ok,err=pcall(options.beforeRender,pixel)
        stats.prepareSeconds=os.clock()-started
        stats.maxPrepareSeconds=math.max(stats.maxPrepareSeconds or 0,stats.prepareSeconds)
        if not ok then
          pixel.lastError=tostring(err) pixel:close() previous={}
          if options.onGraphicsFailure then pcall(options.onGraphicsFailure,err) end
        end
      end
      surface.setVisible(false)
      term.redirect(surface)
      local renderStarted=os.clock()
      local ok, err = pcall(render)
      stats.renderSeconds=os.clock()-renderStarted
      term.redirect(target)
      if not ok then
        if options and options.onGraphicsFailure then pcall(options.onGraphicsFailure,err) end
        error(err, 0)
      end
      -- Read the local surface outside the output guard: these are renderer faults.
      local nativeShell=pixel and pixel.mode~=0 and options and options.nativeShell and options.backendOptions and options.backendOptions.optimized
      for y = 1, nativeShell and 0 or h do
        local row = frame[y] or {}
        row[1], row[2], row[3] = surface.getLine(y)
        frame[y] = row
      end
      local cx, cy, blink
      local flushed, failure = pcall(function()
        cx, cy = target.getCursorPos()
        blink = target.getCursorBlink()
        target.setCursorBlink(false)
        for y = 1, nativeShell and 0 or h do
          local text, fg, bg = frame[y][1], frame[y][2], frame[y][3]
          local old = previous[y]
          if not old or old[1] ~= text or old[2] ~= fg or old[3] ~= bg then
            if pixel and pixel.mode~=0 and not (options and options.pixelRender) then
              require("system.graphics.legacy").row(pixel.surface,y,text,fg,bg,w,h)
            elseif not pixel or pixel.mode==0 then
              target.setCursorPos(1, y)
              target.blit(text, fg, bg)
            end
            stats.rows, stats.cells = stats.rows + 1, stats.cells + #text
          end
          if not old then old = {} previous[y] = old end
          old[1], old[2], old[3] = text, fg, bg
        end
        target.setCursorPos(cx, cy)
        target.setCursorBlink(blink)
        if pixel and pixel.mode~=0 then
          local drawn,problem=true,nil
          if options and options.pixelRender then
            local started=os.clock()
            drawn,problem=pcall(options.pixelRender,pixel)
            stats.compositionSeconds=(stats.renderSeconds or 0)+os.clock()-started
            stats.maxCompositionSeconds=math.max(stats.maxCompositionSeconds or 0,stats.compositionSeconds)
          end
          local ok,err
          if drawn then ok,err=pixel:present()
          else pixel.lastError=tostring(problem) pixel:close() ok,err=false,problem end
          if not ok then
            -- Rebuild complete rescue UI lazily; successful native frames need no
            -- text desktop, taskbar or physical-buffer row comparison.
            if nativeShell then
              term.redirect(surface)
              local rendered,reason=pcall(render,true)
              term.redirect(target)
              if not rendered then error(reason,0) end
              for y=1,h do frame[y]={surface.getLine(y)} end
            end
            previous={}
            for y=1,h do target.setCursorPos(1,y) target.blit(table.unpack(frame[y])) end
            target.setCursorPos(cx,cy) target.setCursorBlink(blink)
            if options and options.onGraphicsFailure then pcall(options.onGraphicsFailure,err) end
          end
        end
      end)
      if not flushed then
        if cx and cy then pcall(target.setCursorPos, cx, cy) end
        if blink ~= nil then pcall(target.setCursorBlink, blink) end
        outputFailure(target, failure)
        return false, failure
      end
      stats.frames = stats.frames + 1
      return true
    end,
  }
end

return M
