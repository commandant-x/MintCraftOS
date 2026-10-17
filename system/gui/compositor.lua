local M = {}

function M.new(resolveTarget, onOutputFailure)
  local surface, parent, width, height
  local previous = {}
  local frame = {}
  local failedTarget, fallbackTarget
  local function outputFailure(target, problem)
    previous = {}
    local native = term.native and term.native() or target
    term.redirect(native)
    if target == native then error(problem, 0) end
    failedTarget, fallbackTarget = target, native
    surface, parent = nil, nil
    if onOutputFailure then pcall(onOutputFailure, target, problem) end
    return native
  end
  local stats = { frames = 0, rows = 0, cells = 0 }
  return {
    invalidate = function() previous = {} failedTarget = nil end,
    stats = function() return { frames = stats.frames, rows = stats.rows, cells = stats.cells } end,
    draw = function(_, render)
      local target = resolveTarget and resolveTarget() or term.current()
      if target == failedTarget then target = fallbackTarget end
      local sized, w, h = pcall(target.getSize)
      if not sized then
        target = outputFailure(target, w)
        w, h = target.getSize()
      end
      if parent ~= target then
        parent, width, height = target, w, h
        surface = window.create(parent, 1, 1, w, h, false)
        previous = {}
      elseif width ~= w or height ~= h then
        surface.reposition(1, 1, w, h)
        width, height = w, h
        previous = {}
      end
      surface.setVisible(false)
      term.redirect(surface)
      local ok, err = pcall(render)
      term.redirect(target)
      if not ok then error(err, 0) end
      -- Read the local surface outside the output guard: these are renderer faults.
      for y = 1, h do
        local row = frame[y] or {}
        row[1], row[2], row[3] = surface.getLine(y)
        frame[y] = row
      end
      local cx, cy, blink
      local flushed, failure = pcall(function()
        cx, cy = target.getCursorPos()
        blink = target.getCursorBlink()
        target.setCursorBlink(false)
        for y = 1, h do
          local text, fg, bg = frame[y][1], frame[y][2], frame[y][3]
          local old = previous[y]
          if not old or old[1] ~= text or old[2] ~= fg or old[3] ~= bg then
            target.setCursorPos(1, y)
            target.blit(text, fg, bg)
            stats.rows, stats.cells = stats.rows + 1, stats.cells + #text
          end
          if not old then old = {} previous[y] = old end
          old[1], old[2], old[3] = text, fg, bg
        end
        target.setCursorPos(cx, cy)
        target.setCursorBlink(blink)
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
