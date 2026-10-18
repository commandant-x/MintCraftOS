local renderer = require("system.gui.renderer")
local layout = require("system.gui.keyboard_layout")
local M = {layout=layout.layout, press=layout.press}
function M.height() return 7 end
function M.draw(x, y, w, state)
  state = state or {}
  state.x, state.y, state.w = x, y, w
  state.boxes = {}
  state.symbolPage = state.symbolPage or 1
  local function key(row, index, count, id, label, active, text)
    local left = math.floor((index - 1) * w / count)
    local right = math.floor(index * w / count)
    if right <= left then return end
    local width = right - left
    local shown = label:sub(1, width)
    local pad = math.floor((width - #shown) / 2)
    renderer.writeAt(x + left, y + row - 1,
      string.rep(" ", pad) .. shown .. string.rep(" ", width - pad - #shown),
      active and colors.black or colors.white, active and colors.cyan or colors.gray)
    table.insert(state.boxes, { x = x + left, y = y + row - 1, w = width, id = id, text = text })
  end
  renderer.fill(x, y, w, M.height(), colors.lightGray)
  for row,entries in ipairs(M.layout(state)) do
    for i,entry in ipairs(entries) do
      key(row,i,row<=5 and math.max(10,#entries) or 4,entry.id,
        w>=24 and entry.label or entry.short or entry.label,entry.active,entry.text)
    end
  end
end
function M.handle(event, state)
  if not state or event.name ~= "mouse_click" or event.args[1] ~= 1 then return false end
  local x, y = event.args[2], event.args[3]
  for _, box in ipairs(state.boxes or {}) do
    if x >= box.x and x < box.x + box.w and y == box.y then
      M.press(box,state)
      return true
    end
  end
  return false
end
return M
