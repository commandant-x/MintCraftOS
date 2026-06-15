local renderer = require("system.gui.renderer")

local M = {}

function M.run(ctx)
  local app = { path = ctx.args.path or "/home/user" }

  function app:draw(w, h)
    renderer.writeAt(1, 1, renderer.crop("Path: " .. self.path, w), colors.black, colors.lightGray)
    local files = {}
    if fs.exists(self.path) and fs.isDir(self.path) then files = fs.list(self.path) end
    for i = 1, math.min(#files, h - 2) do
      local name = files[i]
      local full = fs.combine(self.path, name)
      local prefix = fs.isDir(full) and "[D] " or "    "
      renderer.writeAt(1, i + 1, renderer.crop(prefix .. name, w), colors.black, colors.lightGray)
    end
  end

  function app:handle(event)
    if event.name == "mouse_click" then
      local _, _, y = table.unpack(event.args)
      local files = fs.list(self.path)
      local name = files[y - 1]
      if name then
        local full = fs.combine(self.path, name)
        if fs.isDir(full) then self.path = full end
      end
      return true
    elseif event.name == "key" and event.args[1] == keys.backspace then
      self.path = fs.getDir(self.path)
      if self.path == "" then self.path = "/" end
      return true
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Files", w = math.min(58, sw - 4), h = math.min(18, sh - 3), x = 6, y = 3, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
