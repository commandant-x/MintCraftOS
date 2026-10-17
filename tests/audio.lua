package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = { info = function() end, error = function() end, warn = function() end }
local loads = 0
local configValue = { volume = 1 }
package.loaded["system.libraries.config"] = {
  load = function() loads = loads + 1 return configValue end,
  save = function() return true end,
}
local reads, closes, plays, stops = 0, 0, 0, 0
local busy, broken = true, false
local device = {
  playNote = function() if broken then error("detached") end return not busy end,
  playSound = function() if broken then error("detached") end return not busy end,
  playAudio = function(buffer)
    plays = plays + 1
    if broken then error("detached") end
    if busy then return false end
    assert(buffer[1] == 12)
    return true
  end,
  stop = function() stops = stops + 1 end,
}
peripheral = {
  getNames = function() return { "left" } end,
  getType = function() return "speaker" end,
  wrap = function() return device end,
  getName = function() return "left" end,
}
fs = { open = function()
  local n = 0
  return {
    read = function(size) assert(size == 16384) n = n + 1 reads = reads + 1 if n <= 2 then return "data" end end,
    close = function() closes = closes + 1 end,
  }
end }
package.loaded["cc.audio.dfpwm"] = { make_decoder = function() return function() return { 12 } end end }
local bus = require("system.kernel.event_bus").new()
local audio = require("system.services.audiod")
local driver = require("system.drivers.speaker")
assert(not driver.playNote() and not driver.playSound("test"), "busy speaker reported success")
assert(loads == 1)
driver.status() driver.status()
assert(loads == 1, "status reread config")
driver.invalidateConfig() driver.status()
assert(loads == 2)
driver.setVolume(2) driver.status()
assert(loads == 3, "setter did not invalidate cache")
for _, invalid in ipairs({false, true, 12, "invalid"}) do
  configValue = invalid
  driver.invalidateConfig()
  assert(driver.status().enabled and driver.status().volume == 1, "invalid config was not normalized")
end
configValue = nil
driver.invalidateConfig()
assert(driver.status().enabled and driver.status().volume == 1)
configValue = { volume = 1 }
driver.invalidateConfig()
local ctx = { eventBus = bus }
audio.start(ctx)
assert(audio.playDfPWM("alarm.dfpwm"))
assert(reads == 1 and plays == 1, "playback must return when speaker is busy")
bus:emit("speaker_audio_empty", "right")
assert(plays == 1, "wrong speaker advanced playback")
busy = false
bus:emit("speaker_audio_empty", "left")
assert(reads == 1 and plays == 2, "busy buffer was lost")
bus:emit("speaker_audio_empty", "left")
bus:emit("speaker_audio_empty", "left")
assert(closes == 1 and not audio.status().playing)
assert(audio.playDfPWM("alarm.dfpwm"))
broken = true
local noteOK, noteErr = driver.playNote()
assert(not noteOK and noteErr:find("detached", 1, true))
bus:emit("speaker_audio_empty", "left")
assert(closes == 2 and stops == 1 and not audio.status().playing)
audio.stop()
local before = plays
bus:emit("speaker_audio_empty", "left")
assert(plays == before)
assert(not audio.playDfPWM("alarm.dfpwm"))
broken, busy = false, true
local timer = 0
os.startTimer = function() timer = timer + 1 return timer end
os.cancelTimer = function() end
audio.start(ctx)
for i = 1, 16 do assert(audio.notify("info")) end
assert(not audio.notify("info"))
assert(audio.notify("error"))
assert(#audio.notificationQueue == 16 and audio.notificationQueue[1] == "error")
busy = false
bus:emit("timer", timer)
assert(#audio.notificationQueue == 0)
assert(audio.playDfPWM("user.dfpwm"))
assert(audio.notify("info") and audio.status().playing)
assert(audio.notify("error") and not audio.status().playing, "error did not preempt user audio")
audio.stop()
assert(#audio.notificationQueue == 0)
fs.exists = function() return true end
broken = true
local priorCloses = closes
local played, failure = driver.playDfPWM("broken.dfpwm")
assert(not played and failure:find("detached", 1, true) and closes == priorCloses + 1,
  "synchronous playback leaked its file on failure")
print("audio tests passed")
