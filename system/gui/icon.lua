local renderer = require("system.gui.renderer")

local M = {}
local cache = {}

function M.invalidate(path)
  if path then cache[path] = nil else cache = {} end
end

local function fallback(x, y, label, bg)
  renderer.writeAt(x, y, "[" .. renderer.crop(label or "?", 2) .. "]", colors.white, bg or colors.black)
end

function M.draw(path, x, y, fallbackLabel, bg, columns, rows)
  bg = bg or colors.black
  if path and paintutils and paintutils.loadImage and cache[path] == nil then
    local finePath = path:gsub("%.nfp$", ".spx")
    local fine = finePath ~= path and fs.exists(finePath)
    local ok, image = pcall(paintutils.loadImage, fine and finePath or path)
    cache[path] = ok and image and { image = image, fine = fine, variants = {} } or false
  end
  local asset = path and cache[path]
  if asset then
    local key=tostring(bg)..":"..tostring(columns)..":"..tostring(rows)
    local canvas = asset.variants[key]
    if not canvas then
      local image, width = asset.image, 0
      for _, row in ipairs(image) do width = math.max(width, #row) end
      if width == 0 or #image == 0 then fallback(x, y, fallbackLabel, bg) return false end
      local subpixel = require("system.gui.subpixel")
      local nativeW,nativeH=asset.fine and math.ceil(width/2) or width,asset.fine and math.ceil(#image/3) or #image
      canvas=subpixel.new(columns or nativeW,rows or nativeH,bg)
      for py=1,canvas.height do for px=1,canvas.width do
        local left=math.min(width,math.floor((px-1)*width/canvas.width)+1)
        local top=math.min(#image,math.floor((py-1)*#image/canvas.height)+1)
        local right=math.min(width,math.max(left,math.floor(px*width/canvas.width)))
        local bottom=math.min(#image,math.max(top,math.floor(py*#image/canvas.height)))
        local counts={} local color,score=0,-1
        for sy=top,bottom do for sx=left,right do
          local value=(image[sy] or {})[sx] or 0
          counts[value]=(counts[value] or 0)+1
        end end
        -- Preserve thin white glyphs when reducing the original bitmap.
        for value,count in pairs(counts) do
          local weight=count*(value==colors.white and 3 or 1)
          if weight>score or weight==score and value==colors.white then color,score=value,weight end
        end
        if color and color~=0 then canvas:pixel(px,py,color) end
      end end
      asset.variants[key] = canvas
    end
    canvas:draw(x, y)
    return true
  end

  fallback(x, y, fallbackLabel, bg)
  return false
end

return M
