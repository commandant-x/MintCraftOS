local renderer = require("system.gui.renderer")
local theme = require("system.gui.theme")

local M = {}

function M.button(x, y, w, label, active)
  renderer.button(x, y, w, label, active)
  return { x = x, y = y, w = w, h = 1, label = label }
end

function M.hit(box, x, y)
  return box and x >= box.x and x < box.x + box.w and y >= box.y and y < box.y + (box.h or 1)
end

function M.toolbar(x, y, w, actions, state)
  if state then return M.tabs(x, y, w, actions, nil, state) end
  local boxes = {}
  local cursor = x
  for _, action in ipairs(actions) do
    local width = math.min(#action.label + 2, math.max(4, w - cursor + x))
    if cursor + width - x > w then break end
    renderer.button(cursor, y, width, action.label, action.active)
    action.x, action.y, action.w, action.h = cursor, y, width, 1
    table.insert(boxes, action)
    cursor = cursor + width + 1
  end
  return boxes
end

function M.toolbarHit(actions, x, y)
  for _, action in ipairs(actions or {}) do
    if M.hit(action, x, y) then return action.id end
  end
  return nil
end

function M.tabs(x, y, w, tabs, selected, state)
  local boxes = {}
  local cursor = x
  local pageable = state ~= nil
  state = state or {}
  local total = -1
  for _, tab in ipairs(tabs) do total = total + #tab.label + 3 end
  local overflow = total > w
  state.first = overflow and math.max(1, math.min(#tabs, state.first or 1)) or 1
  local right = x + w - 1
  if overflow and pageable and w >= 5 then
    renderer.writeAt(x, y, "<", theme.get("buttonFg"), theme.get("buttonBg"))
    renderer.writeAt(right, y, ">", theme.get("buttonFg"), theme.get("buttonBg"))
    boxes[#boxes + 1] = {x = x, y = y, w = 1, delta = -1}
    boxes[#boxes + 1] = {x = right, y = y, w = 1, delta = 1}
    cursor, right = x + 2, right - 2
  end
  for index = state.first, #tabs do
    local tab = tabs[index]
    local width = math.min(#tab.label + 2, right - cursor + 1)
    if width < 1 then break end
    renderer.button(cursor, y, width, tab.label, tab.id == selected)
    table.insert(boxes, {id = tab.id, x = cursor, y = y, w = width, h = 1})
    cursor = cursor + width + 1
  end
  return boxes
end

function M.list(x, y, w, h, rows, selected, scroll, render)
  scroll = scroll or 1
  for i = 1, h do
    local index = scroll + i - 1
    local row = rows[index]
    local active = row ~= nil and row == selected
    local bg = active and colors.cyan or theme.get("windowBg")
    local text = row and render(row, index) or ""
    renderer.writeAt(x, y + i - 1, renderer.crop(text, w), active and colors.black or theme.get("windowFg"), bg)
  end
end

function M.input(x, y, w, label, value, focused)
  local bg = focused and colors.white or colors.lightGray
  renderer.writeAt(x, y, renderer.crop(label .. ": " .. tostring(value or ""), w), colors.black, bg)
end

function M.dialog(x, y, w, title, message, confirmLabel)
  renderer.fill(x, y, w, 5, colors.gray)
  renderer.writeAt(x + 1, y, renderer.crop(title, w - 2), colors.white, colors.gray)
  renderer.writeAt(x + 1, y + 2, renderer.crop(message, w - 2), colors.white, colors.gray)
  renderer.button(x + 1, y + 4, math.min(12, w - 2), confirmLabel or "Confirm", false)
end

return M
