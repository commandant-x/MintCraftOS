local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")

local M = {}

local function sizeLabel(bytes)
  bytes = tonumber(bytes) or 0
  if bytes >= 1024 * 1024 then
    return string.format("%.1f MB", bytes / 1024 / 1024)
  elseif bytes >= 1024 then
    return string.format("%.1f KB", bytes / 1024)
  end
  return tostring(bytes) .. " B"
end

local function diskStats()
  if not fs.getFreeSpace then return "Disk: unavailable" end
  local free = fs.getFreeSpace("/")
  local capacity = fs.getCapacity and fs.getCapacity("/") or nil
  if capacity and capacity > 0 then
    local used = capacity - free
    local pct = math.floor((used / capacity) * 100 + 0.5)
    return "Disk: " .. sizeLabel(used) .. "/" .. sizeLabel(capacity) .. " " .. pct .. "%"
  end
  return "Disk free: " .. sizeLabel(free)
end

local function memoryStats()
  if not collectgarbage then return "RAM: unavailable" end
  local ok, kb = pcall(collectgarbage, "count")
  if not ok then return "RAM: unavailable" end
  return string.format("RAM Lua: %.1f KB", kb)
end

function M.run(ctx)
  local app = { selectedPid = nil, scroll = 1 }
  local actions = {
    { id = "kill", label = "Kill" },
    { id = "refresh", label = "Refresh" },
  }

  function app:draw(w, h)
    local rows = ctx.listProcesses()
    local total = #rows
    local ready = 0
    for _, p in ipairs(rows) do
      if p.state == "ready" then ready = ready + 1 end
    end
    local cpuEstimate = total > 0 and math.floor((ready / total) * 100 + 0.5) or 0

    self.toolbar = ui.toolbar(1, 1, w, actions)
    renderer.writeAt(1, 2, renderer.crop("MintCraft Task Manager", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("CPU est. CC: " .. cpuEstimate .. "%  Proc: " .. tostring(total), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop(memoryStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop(diskStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(1, 7, renderer.crop("PID STATE    APP        NAME", w), colors.black, colors.gray)

    for i = 1, math.min(#rows, h - 7) do
      local p = rows[self.scroll + i - 1]
      if p then
        local bg = p.pid == self.selectedPid and colors.cyan or colors.lightGray
        renderer.writeAt(1, i + 7, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. tostring(p.appId or "-") .. "   " .. p.name, w), colors.black, bg)
      end
    end
    if self.selectedPid then
      for _, p in ipairs(rows) do
        if p.pid == self.selectedPid then
          local perms = table.concat(p.permissions or {}, ",")
          renderer.writeAt(1, h - 1, renderer.crop("Window: " .. tostring(p.windowId or "-") .. " Started: " .. tostring(p.startedAt or "-"), w), colors.gray, colors.lightGray)
          renderer.writeAt(1, h, renderer.crop("Perms: " .. (perms ~= "" and perms or "-") .. " Err: " .. tostring(p.error or "-"), w), colors.gray, colors.lightGray)
          break
        end
      end
    end
  end

  function app:handle(event)
    if event.name == "mouse_scroll" then
      self.scroll = math.max(1, self.scroll + event.args[1])
      return true
    end
    if event.name ~= "mouse_click" then return false end
    local _, x, y = table.unpack(event.args)
    local action = ui.toolbarHit(self.toolbar, x, y)
    if action == "kill" and self.selectedPid then
      local ok, err = ctx.kill(self.selectedPid)
      if ctx.notifications then ctx.notifications:push(ok and "success" or "error", "Task Manager", ok and "Killed" or tostring(err), 3) end
      return true
    elseif action then
      return true
    end
    if y >= 8 then
      local rows = ctx.listProcesses()
      local p = rows[self.scroll + y - 8]
      if p then self.selectedPid = p.pid return true end
    end
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Task Manager", w = math.min(58, sw - 4), h = math.min(16, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
