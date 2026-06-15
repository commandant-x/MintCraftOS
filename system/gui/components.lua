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

function M.toolbar(x, y, w, actions)
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

function M.tabs(x, y, w, tabs, selected)
  local boxes = {}
  local cursor = x
  for _, tab in ipairs(tabs) do
    local width = math.min(#tab.label + 2, math.max(5, w - cursor + x))
    if cursor + width - x > w then break end
    renderer.button(cursor, y, width, tab.label, tab.id == selected)
    tab.x, tab.y, tab.w, tab.h = cursor, y, width, 1
    table.insert(boxes, tab)
    cursor = cursor + width + 1
  end
  return boxes
end

function M.list(x, y, w, h, rows, selected, scroll, render)
  scroll = scroll or 1
  for i = 1, h do
    local index = scroll + i - 1
    local row = rows[index]
    local bg = row == selected and colors.cyan or theme.get("windowBg")
    local text = row and render(row, index) or ""
    renderer.writeAt(x, y + i - 1, renderer.crop(text, w), colors.black, bg)
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
