local renderer = require("system.gui.renderer")
local M = {}
local rows = { "1234567890", "azertyuiop", "qsdfghjklm", "wxcvbn" }
local symbols = { ".,;:!?'-_/", "()[]{}+*=\\", '\"<>@#$%&|~', "`^" }
local controls = {
  { "caps", "Maj", "M" }, { "shift", "Shift", "S" },
  { "ctrl", "Ctrl", "C" }, { "symbols", "Sym", "#" },
  { "tab", "Tab", "Tab" }, { "space", "Space", "_" },
  { "back", "Back", "<" }, { "enter", "Enter", "Ent" },
}
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
  for row = 1, 5 do
    local chars = rows[row] or symbols[state.symbolPage]
    for i = 1, #chars do
      local ch = chars:sub(i, i)
      if (state.caps == true) ~= (state.shift == true) then ch = ch:upper() end
      key(row, i, math.max(10, #chars), "text", ch, false, ch)
    end
  end
  for i, control in ipairs(controls) do
    local active = state[control[1]] == true or (control[1] == "symbols" and state.symbolPage > 1)
    key(6 + math.floor((i - 1) / 4), (i - 1) % 4 + 1, 4,
      control[1], w >= 24 and control[2] or control[3], active)
  end
end
function M.handle(event, state)
  if not state or event.name ~= "mouse_click" or event.args[1] ~= 1 then return false end
  local x, y = event.args[2], event.args[3]
  for _, box in ipairs(state.boxes or {}) do
    if x >= box.x and x < box.x + box.w and y == box.y then
      local id = box.id
      if id == "caps" or id == "shift" or id == "ctrl" then state[id] = not state[id]
      elseif id == "symbols" then state.symbolPage = (state.symbolPage or 1) % #symbols + 1
      elseif id == "text" then
        if state.ctrl then
          if state.onControl then state.onControl(box.text:lower()) end
        elseif state.onText then state.onText(box.text) end
        state.shift = false
      elseif id == "space" then
        if state.onText then state.onText(" ") end
      elseif id == "tab" then
        if state.onTab then state.onTab() end
      elseif id == "back" then
        if state.onBackspace then state.onBackspace() end
      elseif id == "enter" then
        if state.onEnter then state.onEnter() end
      end
      return true
    end
  end
  return false
end
return M
