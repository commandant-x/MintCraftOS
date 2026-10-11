local M = {}

function M.normalize(raw, display)
  if raw[1] == "monitor_touch" then
    if not display or display.target ~= "monitor" or raw[2] ~= display.monitorSide then return nil end
    return {
      name = "mouse_click", args = {1, raw[3], raw[4]}, raw = raw,
      monitorTouch = true, monitorSide = raw[2],
    }
  end
  return {name = raw[1], args = table.pack(table.unpack(raw,2,raw.n or #raw)), raw = raw}
end

return M
