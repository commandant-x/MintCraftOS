package.path = "./?.lua;" .. package.path
colors = { white = 1, black = 2, cyan = 3, gray = 4, lightGray = 5 }
local left, top, width = 3, 5, 12
package.loaded["system.gui.renderer"] = {
  fill = function() end,
  writeAt = function(x, y, text)
    assert(x >= left and x + #text <= left + width)
    assert(y >= top and y < top + 7)
  end,
}
local keyboard = require("system.gui.keyboard")
for _, w in ipairs({12, 20, 35, 48, 100}) do
  width = w
  local text, entered, tabbed, backed, control = "", 0, 0, 0, nil
  local state = {
    onText = function(ch) text = text .. ch end,
    onEnter = function() entered = entered + 1 end,
    onTab = function() tabbed = tabbed + 1 end,
    onBackspace = function() backed = backed + 1 end,
    onControl = function(ch) control = ch end,
  }
  local function draw() keyboard.draw(left, top, width, state) end
  local function tap(id, ch)
    draw()
    for _, box in ipairs(state.boxes) do
      if box.id == id and (not ch or box.text == ch) then
        assert(keyboard.handle({name="mouse_click", args={1,box.x,box.y}}, state))
        return
      end
    end
    error("missing key " .. id .. tostring(ch))
  end
  tap("enter") tap("tab") tap("back")
  assert(entered == 1 and tabbed == 1 and backed == 1)
  tap("text", "a") tap("shift") tap("text", "A")
  assert(text == "aA" and state.shift == false)
  tap("caps") tap("shift") tap("text", "a")
  assert(text == "aAa")
  tap("ctrl") tap("text", "S")
  assert(control == "s" and text == "aAa")
  tap("ctrl")
  local seen = {}
  for i = 1, 4 do
    draw()
    for _, box in ipairs(state.boxes) do
      if box.id == "text" then seen[box.text:lower()] = true end
    end
    tap("symbols")
  end
  for code = 33, 126 do
    assert(seen[string.char(code):lower()], "missing printable ASCII key " .. code)
  end
  assert(state.symbolPage == 1)
  draw()
  assert(not keyboard.handle({name="mouse_click",args={1,left-1,top}},state))
  assert(not keyboard.handle({name="mouse_click",args={1,left+width,top}},state))
end
print("keyboard tests passed")
