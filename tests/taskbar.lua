package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = {get = function() return 1 end}
local width, height = 51, 19
term = {getSize = function() return width, height end}
package.loaded["system.gui.renderer"] = {
  crop = function(value, length) return value:sub(1, length) end,
  writeAt = function(x, y, value)
    assert(x >= 1 and x + #value - 1 <= width and y == height)
  end,
}
local manager = require("system.wm.window_manager").new()
for i = 1, 12 do
  local win = manager:create({title = "Application " .. i})
  win.minimized = true
  win.draw = function() end
end
for _, size in ipairs({26, 39, 51, 80, 120}) do
  width = size
  manager.taskPage = 1
  local seen = {}
  manager:draw()
  local pages = manager.taskPages
  for page = 1, pages do
    manager:draw()
    local layout = require("system.gui.taskbar").layout(width)
    local right = layout.first - 1
    for _, box in ipairs(manager.taskButtons) do
      assert(box.x > right and box.x + box.w - 1 <= layout.last)
      right = box.x + box.w - 1
      seen[box.win.id] = true
      assert(manager:handle({name = "mouse_click", args = {1, box.x, height}}))
      assert(not box.win.minimized and manager:active() == box.win)
      box.win.minimized = true
    end
    if page < pages then
      local nextArrow = manager.taskArrows[2]
      assert(manager:handle({name = "mouse_click", args = {1, nextArrow.x, height}}))
    end
  end
  for i = 1, 12 do assert(seen[i], "unreachable minimized window") end
end
print("taskbar paging tests passed")
