package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = { info = function() end, error = function() end }
package.loaded["system.libraries.config"] = { load = function() return { volume = 1 } end }
local reads, closes, plays, stops = 0, 0, 0, 0
local busy, broken = true, false
local device = {
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
    read = function() n = n + 1 reads = reads + 1 if n <= 2 then return "data" end end,
    close = function() closes = closes + 1 end,
  }
end }
package.loaded["cc.audio.dfpwm"] = { make_decoder = function() return function() return { 12 } end end }
local bus = require("system.kernel.event_bus").new()
local audio = require("system.services.audiod")
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
bus:emit("speaker_audio_empty", "left")
assert(closes == 2 and stops == 1 and not audio.status().playing)
audio.stop()
local before = plays
bus:emit("speaker_audio_empty", "left")
assert(plays == before)
assert(not audio.playDfPWM("alarm.dfpwm"))
print("audio tests passed")
