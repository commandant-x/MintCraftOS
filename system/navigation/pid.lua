local M = {}
function M.step(state, gains, error, rate, dt)
  dt = math.max(0.01, math.min(0.5, dt))
  if math.abs(error) < (gains.deadband or 0) then error = 0 end
  local integral = math.max(-gains.integralLimit, math.min(gains.integralLimit, (state.integral or 0) + error*dt))
  local raw = gains.kp*error + gains.ki*integral - gains.kd*rate
  local value = math.max(-gains.limit, math.min(gains.limit, raw))
  if raw == value or error*raw <= 0 then state.integral = integral end
  local last = state.output or 0
  value = math.max(last-gains.slew*dt, math.min(last+gains.slew*dt,value))
  state.output = value
  return value
end
return M
