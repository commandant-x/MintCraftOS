local renderer = require("system.gui.renderer")

local M = {}
local cache = {}

function M.invalidate(path)
  if path then cache[path] = nil else cache = {} end
end

local function fallback(x, y, label, bg)
  renderer.writeAt(x, y, "[" .. renderer.crop(label or "?", 2) .. "]", colors.white, bg or colors.black)
end

function M.draw(path, x, y, fallbackLabel, bg)
  bg = bg or colors.black
  if path and paintutils and paintutils.loadImage and cache[path] == nil then
    local finePath = path:gsub("%.nfp$", ".spx")
    local fine = finePath ~= path and fs.exists(finePath)
    local ok, image = pcall(paintutils.loadImage, fine and finePath or path)
    cache[path] = ok and image and { image = image, fine = fine, variants = {} } or false
  end
  local asset = path and cache[path]
  if asset then
    local canvas = asset.variants[bg]
    if not canvas then
      local image, width = asset.image, 0
      for _, row in ipairs(image) do width = math.max(width, #row) end
      if width == 0 or #image == 0 then fallback(x, y, fallbackLabel, bg) return false end
      local subpixel = require("system.gui.subpixel")
      canvas = subpixel.new(asset.fine and math.ceil(width / 2) or width,
        asset.fine and math.ceil(#image / 3) or #image, bg)
      for py, row in ipairs(image) do
        for px, color in ipairs(row) do
          if color ~= 0 then
            if asset.fine then canvas:pixel(px, py, color)
            else canvas:rect(px * 2 - 1, py * 3 - 2, 2, 3, color) end
          end
        end
      end
      asset.variants[bg] = canvas
    end
    canvas:draw(x, y)
    return true
  end

  fallback(x, y, fallbackLabel, bg)
  return false
end

return M
