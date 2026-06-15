local renderer = require("system.gui.renderer")

local M = {}

local function fallback(x, y, label, bg)
  renderer.writeAt(x, y, "[" .. renderer.crop(label or "?", 2) .. "]", colors.white, bg or colors.black)
end

function M.draw(path, x, y, fallbackLabel, bg)
  if path and fs.exists(path) and paintutils and paintutils.loadImage and paintutils.drawImage then
    local ok, image = pcall(paintutils.loadImage, path)
    if ok and image then
      local drawn = pcall(paintutils.drawImage, image, x, y)
      if drawn then return true end
    end
  end

  fallback(x, y, fallbackLabel, bg)
  return false
end

return M
