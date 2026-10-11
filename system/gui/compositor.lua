local M = {}

function M.new()
  local surface, parent, width, height
  local previous = {}
  local stats = { frames = 0, rows = 0, cells = 0 }
  return {
    invalidate = function() previous = {} end,
    stats = function() return { frames = stats.frames, rows = stats.rows, cells = stats.cells } end,
    draw = function(_, render)
      local target = term.current()
      local w, h = target.getSize()
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
      local nextFrame = {}
      local cx, cy = target.getCursorPos()
      local blink = target.getCursorBlink()
      local flushed, failure = pcall(function()
        target.setCursorBlink(false)
        for y = 1, h do
          local text, fg, bg = surface.getLine(y)
          nextFrame[y] = { text, fg, bg }
          local old = previous[y]
          if not old or old[1] ~= text or old[2] ~= fg or old[3] ~= bg then
            target.setCursorPos(1, y)
            target.blit(text, fg, bg)
            stats.rows, stats.cells = stats.rows + 1, stats.cells + #text
          end
        end
      end)
      target.setCursorPos(cx, cy)
      target.setCursorBlink(blink)
      if not flushed then previous = {} error(failure, 0) end
      previous = nextFrame
      stats.frames = stats.frames + 1
    end,
  }
end

return M
