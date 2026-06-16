local log = require("system.libraries.log")
local speaker = require("system.drivers.speaker")

local M = {
  ctx = nil,
  ready = false,
}

function M.start(ctx)
  M.ctx = ctx
  local rows = speaker.scan()
  M.ready = true
  log.info("audiod", "audio service ready, speakers=" .. tostring(#rows))
  if ctx and ctx.eventBus then
    ctx.eventBus:on("peripheral", function()
      local found = speaker.scan()
      log.info("audiod", "speaker rescan, speakers=" .. tostring(#found))
    end)
    ctx.eventBus:on("peripheral_detach", function()
      local found = speaker.scan()
      log.info("audiod", "speaker rescan, speakers=" .. tostring(#found))
    end)
  end
end

function M.stop()
  M.ready = false
end

function M.status()
  local st = speaker.status()
  st.ready = M.ready
  return st
end

function M.test()
  return speaker.test()
end

function M.notify(level)
  return speaker.notify(level)
end

function M.setEnabled(enabled)
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
  return speaker.playDfPWM(path, side)
end

return M
