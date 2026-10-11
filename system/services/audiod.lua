local log = require("system.libraries.log")
local speaker = require("system.drivers.speaker")

local M = {
  ctx = nil,
  ready = false,
  listeners = {},
  stream = nil,
}

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
    end))
  end
end

function M.stop()
  M.stopPlayback()
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
  return speaker.notify(level)
end

function M.setEnabled(enabled)
  if enabled == false then M.stopPlayback() end
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
