local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")
local packages = require("system.package.package_manager")

local M = {}

function M.run(ctx)
  packages.setContext(ctx.system)
  local app = {
    selected = nil,
    scroll = 1,
    message = "Select a package",
  }

  local actions = {
    { id = "install", label = "Install" },
    { id = "remove", label = "Remove" },
    { id = "refresh", label = "Refresh" },
  }

  local function rows()
    local installed = {}
    for _, pkg in ipairs(packages.installed()) do installed[pkg.id] = true end
    local out = {}
    for _, pkg in ipairs(packages.available()) do
      pkg.installed = installed[pkg.id] or false
      table.insert(out, pkg)
    end
    return out
  end

  function app:draw(w, h)
    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("PACKAGE        VERSION   STATE", w), colors.black, colors.gray)
    local list = rows()
    for i = 1, math.min(#list, h - 6) do
      local pkg = list[self.scroll + i - 1]
      if pkg then
        local bg = pkg.id == self.selected and colors.cyan or colors.lightGray
        local state = pkg.installed and "installed" or "available"
        renderer.writeAt(1, i + 2, renderer.crop(pkg.name .. "        " .. pkg.version .. "   " .. state, w), colors.black, bg)
      end
    end
    local selected
    for _, pkg in ipairs(list) do if pkg.id == self.selected then selected = pkg end end
    if selected then
      renderer.writeAt(1, h - 2, renderer.crop(selected.description or "", w), colors.gray, colors.lightGray)
    end
    renderer.writeAt(1, h, renderer.crop(self.message, w), colors.gray, colors.lightGray)
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    local action = ui.toolbarHit(self.toolbar, x, y)
    if action == "install" and self.selected then
      local ok, msg = packages.install(self.selected)
      self.message = tostring(msg)
      if ctx.notifications then ctx.notifications:push(ok and "success" or "error", "Store", tostring(msg), 4) end
      return true
    elseif action == "remove" and self.selected then
      local ok, msg = packages.remove(self.selected)
      self.message = tostring(msg)
      if ctx.notifications then ctx.notifications:push(ok and "success" or "warn", "Store", tostring(msg), 4) end
      return true
    elseif action then
      self.message = "Refreshed"
      return true
    end
    if y >= 3 then
      local pkg = rows()[self.scroll + y - 3]
      if pkg then self.selected = pkg.id return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Store", w = math.min(70, sw - 4), h = math.min(18, sh - 3), x = 6, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
