local M = {}

function M.layout(width)
  local searchWidth = width >= 70 and 16 or 8
  local first = 10 + searchWidth + 1
  return {searchX = 10, searchWidth = searchWidth, first = first, last = width - 7}
end

return M
