local output, writes = {}, 0
print = function(text) output[#output + 1] = text end
fs = {open = function() return nil end}
os = {getComputerID = function() return 7 end}
peripheral = {
  getNames = function() return {} end,
  getType = function(name) if name == 'right' then return 'monitor' end end,
  wrap = function() return {
    getSize = function() return 80, 30 end,
    getTextScale = function() return 0.5 end,
    setTextScale = function() writes = writes + 1 end,
  } end,
}
dofile('tools/display-diagnostic.lua')
assert(table.concat(output, '\n'):find('READ OK: 80x30 scale=0.5', 1, true))
assert(writes == 0, 'diagnosis changed the monitor')
output = {}
peripheral.getType = function() return nil end
dofile('tools/display-diagnostic.lua')
assert(table.concat(output, '\n'):find('DISPLAY-003', 1, true))
