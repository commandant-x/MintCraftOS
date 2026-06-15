local config = require("system.libraries.config")
local log = require("system.libraries.log")

local M = {
  speakers = {},
  defaultSide = nil,
}

local CONFIG = "/system/config/audio.cfg"

local function clampVolume(value)
  value = tonumber(value) or 1
  if value < 0 then return 0 end
  if value > 3 then return 3 end
  return value
end

local function loadCfg()
  return config.load(CONFIG, {
    enabled = true,
    volume = 1,
    notificationVolume = 0.6,
    defaultSide = nil,
    notifyOnSystemReady = true,
  })
end

local function get(side)
  if not peripheral or not peripheral.wrap then return nil end
  if side and peripheral.getType and peripheral.getType(side) == "speaker" then
    return peripheral.wrap(side), side
  end
  if peripheral.find then
    local speaker, found = peripheral.find("speaker")
    return speaker, found
  end
  return nil
end

function M.scan()
  local rows = {}
  if peripheral and peripheral.getNames and peripheral.getType then
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "speaker" then
        table.insert(rows, { side = name, type = "speaker" })
      end
    end
  end
  table.sort(rows, function(a, b) return a.side < b.side end)
  M.speakers = rows

  local cfg = loadCfg()
  if cfg.defaultSide and peripheral and peripheral.getType and peripheral.getType(cfg.defaultSide) == "speaker" then
    M.defaultSide = cfg.defaultSide
  elseif rows[1] then
    M.defaultSide = rows[1].side
  else
    M.defaultSide = nil
  end
  return rows
end

function M.status()
  M.scan()
  local cfg = loadCfg()
  return {
    enabled = cfg.enabled ~= false,
    volume = clampVolume(cfg.volume),
    notificationVolume = clampVolume(cfg.notificationVolume),
    defaultSide = M.defaultSide,
    count = #M.speakers,
    speakers = M.speakers,
  }
end

function M.setVolume(volume)
  local cfg = loadCfg()
  cfg.volume = clampVolume(volume)
  config.save(CONFIG, cfg)
  return cfg.volume
end

function M.setNotificationVolume(volume)
  local cfg = loadCfg()
  cfg.notificationVolume = clampVolume(volume)
  config.save(CONFIG, cfg)
  return cfg.notificationVolume
end

function M.setEnabled(enabled)
  local cfg = loadCfg()
  cfg.enabled = enabled ~= false
  config.save(CONFIG, cfg)
  return cfg.enabled
end

function M.use(side)
  M.scan()
  if not side or not peripheral or not peripheral.getType or peripheral.getType(side) ~= "speaker" then
    return false, "No speaker on " .. tostring(side or "-")
  end
  local cfg = loadCfg()
  cfg.defaultSide = side
  config.save(CONFIG, cfg)
  M.defaultSide = side
  return true
end

function M.playNote(instrument, pitch, volume, side)
  local cfg = loadCfg()
  if cfg.enabled == false then return false, "Audio disabled" end
  local speaker = get(side or cfg.defaultSide or M.defaultSide)
  if not speaker or not speaker.playNote then return false, "No speaker" end
  local ok, err = pcall(speaker.playNote, instrument or "harp", clampVolume(volume or cfg.volume), tonumber(pitch) or 12)
  if not ok then
    log.warn("speaker", tostring(err))
    return false, tostring(err)
  end
  return true
end

function M.playSound(name, pitch, volume, side)
  local cfg = loadCfg()
  if cfg.enabled == false then return false, "Audio disabled" end
  local speaker = get(side or cfg.defaultSide or M.defaultSide)
  if not speaker or not speaker.playSound then return false, "No speaker" end
  local ok, err = pcall(speaker.playSound, name, clampVolume(volume or cfg.volume), tonumber(pitch) or 1)
  if not ok then
    log.warn("speaker", tostring(err))
    return false, tostring(err)
  end
  return true
end

function M.notify(level)
  local cfg = loadCfg()
  local pitch = 12
  if level == "error" then pitch = 4 elseif level == "warn" then pitch = 8 elseif level == "success" then pitch = 16 end
  return M.playNote("bell", pitch, cfg.notificationVolume)
end

function M.test()
  local ok, err = M.playNote("harp", 12, loadCfg().volume)
  if not ok then return false, err end
  return true
end

function M.playDfPWM(path, side)
  local cfg = loadCfg()
  if cfg.enabled == false then return false, "Audio disabled" end
  if not fs.exists(path) then return false, "Missing file" end
  local speaker = get(side or cfg.defaultSide or M.defaultSide)
  if not speaker or not speaker.playAudio then return false, "No speaker audio API" end
  local okDfpwm, dfpwm = pcall(require, "cc.audio.dfpwm")
  if not okDfpwm then return false, "DFPWM decoder unavailable" end
  local handle = fs.open(path, "rb")
  if not handle then return false, "Cannot open file" end
  local decoder = dfpwm.make_decoder()
  while true do
    local chunk = handle.read(16 * 1024)
    if not chunk then break end
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer, clampVolume(cfg.volume)) do
      os.pullEvent("speaker_audio_empty")
    end
  end
  handle.close()
  return true
end

M.scan()

return M
