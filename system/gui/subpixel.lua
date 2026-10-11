local renderer = require("system.gui.renderer")
local M = {}

-- CC's mosaic characters encode the first five pixels; the sixth is background.
function M.encode(pixels)
  local counts = {}
  for i = 1, 6 do
    renderer.color(pixels[i])
    counts[pixels[i]] = (counts[pixels[i]] or 0) + 1
  end
  local bg, fg, best, second = nil, nil, 0, 0
  for i = 0, 15 do
    local color, count = 2 ^ i, counts[2 ^ i] or 0
    if count > best then fg, second, bg, best = bg, best, color, count
    elseif count > second then fg, second = color, count end
  end
  fg = fg or bg
  if pixels[6] == fg then fg, bg = bg, fg end
  local mask, lost = 0, 0
  for i = 1, 6 do
    if pixels[i] ~= fg and pixels[i] ~= bg then lost = lost + 1 end
    if i < 6 and pixels[i] == fg then mask = mask + 2 ^ (i - 1) end
  end
  return string.char(128 + mask), renderer.color(fg), renderer.color(bg), lost
end

function M.new(columns, rows, background)
  assert(columns >= 1 and rows >= 1 and columns % 1 == 0 and rows % 1 == 0, "Invalid canvas size")
  assert(columns * rows <= 65536, "Canvas exceeds 65536 terminal cells")
  background = background or 32768
  renderer.color(background)
  local canvas = { width = columns * 2, height = rows * 3, columns = columns, rows = rows }
  local pixels, compiled = {}, {}

  function canvas:clear(color)
    background = color or background
    renderer.color(background)
    pixels, compiled = {}, {}
  end

  function canvas:pixel(x, y, color)
    x, y = math.floor(x), math.floor(y)
    if x < 1 or x > self.width or y < 1 or y > self.height then return end
    renderer.color(color)
    local index = (y - 1) * self.width + x
    if (pixels[index] or background) ~= color then
      pixels[index] = color
      compiled[math.ceil(y / 3)] = nil
    end
  end

  function canvas:rect(x, y, w, h, color)
    for py = math.max(1, y), math.min(self.height, y + h - 1) do
      for px = math.max(1, x), math.min(self.width, x + w - 1) do self:pixel(px, py, color) end
    end
  end

  function canvas:line(x1, y1, x2, y2, color)
    -- Clip before rasterising, so distant/offscreen coordinates cannot cause long loops.
    local dx, dy, low, high = x2 - x1, y2 - y1, 0, 1
    local function clip(p, q)
      if p == 0 then return q >= 0 end
      local t = q / p
      if p < 0 then if t > high then return false end low = math.max(low, t)
      else if t < low then return false end high = math.min(high, t) end
      return true
    end
    if not (clip(-dx, x1 - 1) and clip(dx, self.width - x1)
      and clip(-dy, y1 - 1) and clip(dy, self.height - y1)) then return end
    x2, y2 = math.floor(x1 + high * dx + 0.5), math.floor(y1 + high * dy + 0.5)
    x1, y1 = math.floor(x1 + low * dx + 0.5), math.floor(y1 + low * dy + 0.5)
    dx, dy = math.abs(x2 - x1), -math.abs(y2 - y1)
    local sx, sy, err = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1, dx + dy
    while true do
      self:pixel(x1, y1, color)
      if x1 == x2 and y1 == y2 then break end
      local twice = 2 * err
      if twice >= dy then err, x1 = err + dy, x1 + sx end
      if twice <= dx then err, y1 = err + dx, y1 + sy end
    end
  end

  function canvas:getLine(row)
    assert(row >= 1 and row <= self.rows, "Canvas row out of bounds")
    if compiled[row] then return table.unpack(compiled[row]) end
    local text, fg, bg, lost = {}, {}, {}, 0
    local block = {}
    for col = 1, self.columns do
      for py = 0, 2 do
        local offset = ((row - 1) * 3 + py) * self.width + (col - 1) * 2
        block[py * 2 + 1], block[py * 2 + 2] = pixels[offset + 1] or background, pixels[offset + 2] or background
      end
      local loss
      text[col], fg[col], bg[col], loss = M.encode(block)
      lost = lost + loss
    end
    compiled[row] = { table.concat(text), table.concat(fg), table.concat(bg), lost }
    return table.unpack(compiled[row])
  end

  function canvas:draw(x, y)
    for row = 1, self.rows do
      local text, fg, bg = self:getLine(row)
      renderer.blitAt(x, y + row - 1, text, fg, bg)
    end
  end
  return canvas
end

return M
