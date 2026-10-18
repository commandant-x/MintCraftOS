local M = {}
local rows = { "1234567890", "azertyuiop", "qsdfghjklm", "wxcvbn" }
local symbols = { ".,;:!?'-_/", "()[]{}+*=\\", '\"<>@#$%&|~', "`^" }
local controls = {
  { "caps", "Maj", "M" }, { "shift", "Shift", "S" },
  { "ctrl", "Ctrl", "C" }, { "symbols", "Sym", "#" },
  { "tab", "Tab", "Tab" }, { "space", "Space", "_" },
  { "back", "Back", "<" }, { "enter", "Enter", "Ent" },
}
function M.layout(state)
  state=state or {} local result={}
  for row=1,5 do
    result[row]={}
    local chars=rows[row] or symbols[state.symbolPage or 1] or symbols[1]
    for i=1,#chars do
      local ch=chars:sub(i,i)
      if (state.caps==true)~=(state.shift==true) then ch=ch:upper() end
      result[row][i]={id="text",label=ch,text=ch}
    end
  end
  result[6],result[7]={},{}
  for i,control in ipairs(controls) do
    local row=6+math.floor((i-1)/4)
    result[row][#result[row]+1]={id=control[1],label=control[2],short=control[3],
      active=state[control[1]]==true or control[1]=="symbols" and (state.symbolPage or 1)>1}
  end
  return result
end
function M.press(key,state)
  local id=key.id
  if id=="caps" or id=="shift" or id=="ctrl" then state[id]=not state[id]
  elseif id=="symbols" then state.symbolPage=(state.symbolPage or 1)%#symbols+1
  elseif id=="text" then
    if state.ctrl then if state.onControl then state.onControl(key.text:lower()) end
    elseif state.onText then state.onText(key.text) end
    state.shift=false
  elseif id=="space" then if state.onText then state.onText(" ") end
  elseif id=="tab" then if state.onTab then state.onTab() end
  elseif id=="back" then if state.onBackspace then state.onBackspace() end
  elseif id=="enter" then if state.onEnter then state.onEnter() end
  end
end
return M
