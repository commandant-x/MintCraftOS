local renderer = require("system.gui.renderer")

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
  local app = {}

  function app:draw(w, h)
    local rows = ctx.listProcesses()
    local total = #rows
    local ready = 0
    for _, p in ipairs(rows) do
      if p.state == "ready" then ready = ready + 1 end
    end
    local cpuEstimate = total > 0 and math.floor((ready / total) * 100 + 0.5) or 0

    renderer.writeAt(1, 1, renderer.crop("MintCraft Task Manager", w), colors.black, colors.lightGray)
    renderer.writeAt(2, 3, renderer.crop("CPU est.: " .. cpuEstimate .. "%  Proc: " .. tostring(total), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 4, renderer.crop(memoryStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(2, 5, renderer.crop(diskStats(), w - 2), colors.black, colors.lightGray)
    renderer.writeAt(1, 7, renderer.crop("PID STATE    NAME", w), colors.black, colors.gray)

    for i = 1, math.min(#rows, h - 7) do
      local p = rows[i]
      renderer.writeAt(1, i + 7, renderer.crop(tostring(p.pid) .. "   " .. p.state .. "   " .. p.name, w), colors.black, colors.lightGray)
    end
  end

  function app:handle()
    return false
  end

  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Task Manager", w = math.min(58, sw - 4), h = math.min(16, sh - 3), x = 8, y = 4, app = app })
  while not win.closed do ctx.pullEvent() end
end

return M
