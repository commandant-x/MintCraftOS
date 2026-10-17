local log = require("system.libraries.log")
local speaker = require("system.drivers.speaker")

local M = {
  ctx = nil,
  ready = false,
  listeners = {},
  stream = nil,
  notificationQueue = {},
}

local function flushNotifications()
  while #M.notificationQueue > 0 do
    local level = M.notificationQueue[1]
    if M.stream and level ~= "error" then return end
    if M.stream then M.stopPlayback() end
    local ok, err = speaker.notify(level)
    if not ok and err == "Speaker busy" then return end
    table.remove(M.notificationQueue, 1)
  end
end

function M.stopPlayback()
  if M.stream then M.stream.close(true) end
  M.stream = nil
end

local function advance()
  if not M.stream then return true end
  local ok, done = pcall(M.stream.advance)
  if not ok then
    M.stopPlayback()
    log.error("audiod", tostring(done))
    if M.ctx and M.ctx.notifications then
      M.ctx.notifications:push("error", "Audio", tostring(done), 4)
    end
    return false, tostring(done)
  end
  if done then M.stream = nil end
  return true
end

function M.start(ctx)
  if M.ctx then M.stop() end
  M.ctx = ctx
  local rows = speaker.scan()
  M.ready = true
  log.info("audiod", "audio service ready, speakers=" .. tostring(#rows))
  if ctx and ctx.eventBus then
    table.insert(M.listeners, ctx.eventBus:on("peripheral", function()
      local found = speaker.scan()
      log.info("audiod", "speaker rescan, speakers=" .. tostring(#found))
    end))
    table.insert(M.listeners, ctx.eventBus:on("peripheral_detach", function(side)
      if M.stream and M.stream.side == side then M.stopPlayback() end
      local found = speaker.scan()
      log.info("audiod", "speaker rescan, speakers=" .. tostring(#found))
    end))
    table.insert(M.listeners, ctx.eventBus:on("speaker_audio_empty", function(side)
      if M.stream and M.stream.side == side then advance() end
      flushNotifications()
    end))
    table.insert(M.listeners, ctx.eventBus:on("timer", function(id)
      if id ~= M.notificationTimer then return end
      M.notificationTimer = nil
      flushNotifications()
      if #M.notificationQueue > 0 then M.notificationTimer = os.startTimer(0.1) end
    end))
  end
end

function M.stop()
  M.stopPlayback()
  if M.notificationTimer and os.cancelTimer then os.cancelTimer(M.notificationTimer) end
  M.notificationTimer = nil
  M.notificationQueue = {}
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.listeners) do M.ctx.eventBus:off(id) end
  end
  M.listeners = {}
  M.ctx = nil
  M.ready = false
end

function M.status()
  local st = speaker.status()
  st.ready = M.ready
  st.playing = M.stream ~= nil
  return st
end

function M.test()
  return speaker.test()
end

function M.notify(level)
  if not M.ready or not M.ctx or not M.ctx.eventBus or not os.startTimer then return speaker.notify(level) end
  local queue = M.notificationQueue
  if #queue >= 16 then
    if level ~= "error" then return false, "Notification queue full" end
    local victim
    for i = #queue, 1, -1 do if queue[i] ~= "error" then victim = i break end end
    if not victim then return false, "Notification queue full" end
    table.remove(queue, victim)
  end
  if level == "error" then table.insert(queue, 1, level) else table.insert(queue, level or "info") end
  flushNotifications()
  if #queue > 0 and not M.notificationTimer then M.notificationTimer = os.startTimer(0.1) end
  return true
end

function M.setEnabled(enabled)
  if enabled == false then M.stopPlayback() M.notificationQueue = {} end
  return speaker.setEnabled(enabled)
end

function M.setVolume(volume)
  return speaker.setVolume(volume)
end

function M.setNotificationVolume(volume)
  return speaker.setNotificationVolume(volume)
end

function M.use(side)
  return speaker.use(side)
end

function M.playDfPWM(path, side)
  if not M.ready or not M.ctx or not M.ctx.eventBus then return false, "Audio service stopped" end
  local ok, stream, err = pcall(speaker.openStream, path, side)
  if not ok then return false, tostring(stream) end
  if not stream then return false, err end
  M.stopPlayback()
  M.stream = stream
  return advance()
end

return M
