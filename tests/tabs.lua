package.path = "./?.lua;" .. package.path
package.loaded["system.gui.theme"] = {get = function() return 1 end}
package.loaded["system.gui.renderer"] = {button = function() end, writeAt = function() end}
local ui = require("system.gui.components")
local tabs = {}
for i = 1, 10 do tabs[i] = {id = i, label = "Category " .. i} end
for _, width in ipairs({12, 25, 49, 100, 200}) do
  local state, seen = {first = 1}, {}
  for i = 1, #tabs do
    state.first = i
    local boxes = ui.tabs(1, 1, width, tabs, 1, state)
    local cells = {}
    for _, box in ipairs(boxes) do
      assert(box.x >= 1 and box.x + box.w - 1 <= width)
      for x = box.x, box.x + box.w - 1 do
        assert(not cells[x], "overlapping tab hitboxes")
        cells[x] = true
        assert(ui.hit(box, x, 1))
      end
      if box.id then seen[box.id] = true end
    end
  end
  for i = 1, #tabs do assert(seen[i], "unreachable category") end
end
for _, tab in ipairs(tabs) do assert(tab.x == nil, "metadata mutated with stale hitbox") end
local state, seen = {first = 1}, {}
for index = 1, #tabs do
  state.first = index
  local boxes = ui.toolbar(1, 1, 25, tabs, state)
  for _, box in ipairs(boxes) do
    if box.id then
      assert(ui.toolbarHit(boxes, box.x, box.y) == box.id)
      seen[box.id] = true
    end
  end
end
for i = 1, #tabs do assert(seen[i], "toolbar action unreachable") end
print("tab navigation tests passed")
