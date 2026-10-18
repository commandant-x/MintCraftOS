local M = {}
local function pointer(event,display)
  if display and display.pixelWidth and event.name:match("^mouse_") then
    local x,y=event.args[2],event.args[3]
    if type(x)~="number" or type(y)~="number" then return nil end
    event.pixelX,event.pixelY=x,y
    event.args[2]=math.floor(x*display.width/display.pixelWidth)+1
    event.args[3]=math.floor(y*display.height/display.pixelHeight)+1
  end
  return event
end

function M.normalize(raw, display)
  local name=raw[1]
  if type(name)=="string" and name:sub(1,9)=="terminal_" then
    if not display or display.target~="terminal" or raw[2]~=display.terminalSide then return nil end
    local event={name=name:sub(10),args=table.pack(table.unpack(raw,3,raw.n or #raw)),raw=raw,terminalSide=raw[2]}
    return pointer(event,display)
  end
  if raw[1] == "monitor_touch" then
    if not display or display.target ~= "monitor" or raw[2] ~= display.monitorSide then return nil end
    return pointer({
      name = "mouse_click", args = {1, raw[3], raw[4]}, raw = raw,
      monitorTouch = true, monitorSide = raw[2],
    },display)
  end
  local event={name = raw[1], args = table.pack(table.unpack(raw,2,raw.n or #raw)), raw = raw}
  if display and display.target=="computer" then return pointer(event,display) end
  return event
end

return M
