local renderer = require("system.gui.renderer")
local ui = require("system.gui.components")
local theme = require("system.gui.theme")
local addon = require("system.libraries.addon")

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
  local sampleTime, sample
  local function metrics()
    local now = os.clock()
    if not sample or now - sampleTime >= 1 then
      local rows = ctx.listProcesses()
      local ready,runtime=0,0
      for _,process in ipairs(rows) do
        if process.state=="ready" then ready=ready+1 end
        runtime=runtime+(process.runtimeMs or 0)
      end
      sample={rows=rows,memory=memoryStats(),disk=diskStats(),ready=ready,runtimeMs=runtime,acquisition=addon.metrics()}
      sampleTime = now
    end
    return sample
  end
  local actions = {
    { id = "kill", label = "Kill" },
    { id = "refresh", label = "Refresh" },
  }

  function app:draw(w, h)
    local snapshot = metrics()
    local rows = snapshot.rows
    local total = #rows

    self.toolbar = ui.toolbar(1, 1, w, actions)
    if h<9 then
      renderer.writeAt(1,2,renderer.crop("Live: "..snapshot.ready.." | CPU unavailable",w),theme.get("windowFg"),theme.get("windowBg"))
      if h>=4 then renderer.writeAt(1,3,renderer.crop(snapshot.memory,w),theme.get("windowFg"),theme.get("windowBg")) end
      if h>=5 then renderer.writeAt(1,4,renderer.crop(snapshot.disk,w),theme.get("windowFg"),theme.get("windowBg")) end
      self.listBottom=0 return
    end
    renderer.writeAt(1, 2, renderer.crop("MintCraft Task Manager", w), theme.get("windowFg"), theme.get("windowBg"))
    renderer.writeAt(2,3,renderer.crop("CPU: unavailable | Live: "..snapshot.ready.." / "..total,w-2),theme.get("windowFg"),theme.get("windowBg"))
    renderer.writeAt(2, 4, renderer.crop(snapshot.memory, w - 2), theme.get("windowFg"), theme.get("windowBg"))
    renderer.writeAt(2, 5, renderer.crop(snapshot.disk, w - 2), theme.get("windowFg"), theme.get("windowBg"))
    local io=snapshot.acquisition
    renderer.writeAt(2,6,renderer.crop("Reads "..io.reads.." | Active "..io.inFlight.." | Queue "..io.queue.." | Overruns "..io.overruns,w-2),theme.get("windowFg"),theme.get("windowBg"))
    renderer.writeAt(1, 7, renderer.crop("PID STATE    APP        NAME", w), theme.get("windowFg"), theme.get("buttonBg"))

    local visible=math.max(0,h-7-(self.selectedPid and 2 or 0))
    self.scroll=math.max(1,math.min(self.scroll,math.max(1,#rows-visible+1)))
    self.listBottom=7+visible
    for i = 1, math.min(#rows, visible) do
      local p = rows[self.scroll + i - 1]
      if p then
        local bg = p.pid == self.selectedPid and colors.cyan or theme.get("windowBg")
        renderer.writeAt(1, i + 7, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. tostring(p.appId or "-") .. "   " .. p.name, w), theme.get("windowFg"), bg)
      end
    end
    if self.selectedPid then
      for _, p in ipairs(rows) do
        if p.pid == self.selectedPid then
          local perms = table.concat(p.permissions or {}, ",")
          renderer.writeAt(1,h-1,renderer.crop("Active wall time: "..tostring(p.runtimeMs or "?").."ms | Resumes: "..tostring(p.resumes or "?"),w),theme.get("buttonBg"),theme.get("windowBg"))
          renderer.writeAt(1, h, renderer.crop("Perms: " .. (perms ~= "" and perms or "-") .. " Err: " .. tostring(p.error or "-"), w), theme.get("buttonBg"), theme.get("windowBg"))
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
      sample = nil
      if ctx.notifications then ctx.notifications:push(ok and "success" or "error", "Task Manager", ok and "Killed" or tostring(err), 3) end
      return true
    elseif action then
      sample = nil
      return true
    end
    if y >= 8 and y<=(self.listBottom or 0) then
      local rows = metrics().rows
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
