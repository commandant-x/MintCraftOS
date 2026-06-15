local renderer = require("system.gui.renderer")

local M = {}

local rows = {
  "1234567890",
  "azertyuiop",
  "qsdfghjklm",
  "wxcvbn",
}

local function ensure(state)
  state.caps = state.caps or false
  state.shift = state.shift or false
  return state
end

function M.height()
  return 6
end

function M.draw(x, y, w, state)
  state = ensure(state or {})
  renderer.fill(x, y, w, M.height(), colors.lightGray)
  for row, chars in ipairs(rows) do
    local line = ""
    for i = 1, #chars do
      local ch = chars:sub(i, i)
      if state.caps or state.shift then ch = ch:upper() end
      line = line .. ch .. " "
    end
    renderer.writeAt(x, y + row - 1, renderer.crop(line, w), colors.black, colors.lightGray)
  end
  local control = w < 48 and "[M] [S] [C] [Tab] [Space] [<] [Enter]" or "[maj] [shift] [ctrl] [tab] [space] [back] [enter]"
  local flags = (state.caps and "CAPS " or "") .. (state.shift and "SHIFT " or "") .. (state.ctrl and "CTRL " or "")
  renderer.writeAt(x, y + 4, renderer.crop(control, w), colors.white, colors.gray)
  renderer.writeAt(x, y + 5, renderer.crop(flags .. (state.hint or ""), w), colors.black, colors.orange)
end

function M.handle(event, state)
  state = ensure(state or {})
  if event.name ~= "mouse_click" then return false end
  local _, x, y = table.unpack(event.args)
  local relY = y - (state.y or 1) + 1
  local relX = x - (state.x or 1) + 1

  if relY >= 1 and relY <= #rows then
    local chars = rows[relY]
    local index = math.floor((relX + 1) / 2)
    local ch = chars:sub(index, index)
    if ch ~= "" then
      if state.caps or state.shift then ch = ch:upper() end
      state.shift = false
      if state.onText then state.onText(ch) end
      return true
    end
  elseif relY == 5 then
    if relX >= 1 and relX <= 5 then
      state.caps = not state.caps
      return true
    elseif relX >= 7 and relX <= 13 then
      state.shift = true
      return true
    elseif relX >= 15 and relX <= 20 then
      state.ctrl = not state.ctrl
      return true
    elseif relX >= 22 and relX <= 27 then
      if state.onTab then state.onTab() end
      return true
    elseif relX >= 29 and relX <= 36 then
      if state.onText then state.onText(" ") end
      return true
    elseif relX >= 38 and relX <= 45 then
      if state.onBackspace then state.onBackspace() end
      return true
    elseif relX >= 47 and relX <= 55 then
      if state.onEnter then state.onEnter() end
      return true
    end
  end
  return false
end

return M
