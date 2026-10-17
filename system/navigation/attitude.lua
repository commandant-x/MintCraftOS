local M = {}
local function finite(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end
-- Display-only hold. Control always uses the service's unmodified validity.
function M.sample(measurements, previous, now)
  local pitch, roll = measurements.pitch, measurements.roll
  if pitch and roll and pitch.valid and roll.valid and finite(pitch.value) and finite(roll.value) then
    local observed = math.min(pitch.observedAt or pitch.timestamp or -math.huge,
      roll.observedAt or roll.timestamp or -math.huge)
    local expires = math.min(pitch.validUntil or observed + 0.5, roll.validUntil or observed + 0.5)
    if now <= expires then
      return {pitch=pitch.value, roll=roll.value, observedAt=observed}, true
    end
  end
  if previous and now - previous.observedAt <= 1 then return previous, false end
  return nil, false
end
return M
