local fonts=require("system.graphics.fonts")
local M={}
function M.buffer(target)
  -- CraftOS-PC's redirect fills missing graphics methods with native methods.
  -- Explicitly keep offscreen text windows in text mode (not the physical GPU).
  target.getGraphicsMode=function() return false end
  target.setGraphicsMode=function(mode) assert(not mode or mode==0,"Legacy text surface cannot change graphics mode") end
  target.mintcraftPixelBuffer=true
  return target
end
function M.parent(target,mode)
  local redirect={}
  for _,name in ipairs({"write","blit","clear","clearLine","getSize","getCursorPos","setCursorPos",
    "getCursorBlink","setCursorBlink","isColor","isColour","getTextColor","getTextColour",
    "setTextColor","setTextColour","getBackgroundColor","getBackgroundColour",
    "setBackgroundColor","setBackgroundColour","scroll"}) do redirect[name]=target[name] end
  local function index(color)
    if mode~=2 then return color end
    for i=0,15 do if color==2^i then return i end end
    error("Invalid legacy palette color",2)
  end
  redirect.getPaletteColor=function(c) return (target.getPaletteColor or target.getPaletteColour)(index(c)) end
  redirect.getPaletteColour=redirect.getPaletteColor
  redirect.setPaletteColor=function(c,...) return (target.setPaletteColor or target.setPaletteColour)(index(c),...) end
  redirect.setPaletteColour=redirect.setPaletteColor
  return redirect
end
-- Compatibility only: migration of native pixel controls is a separate layer.
function M.row(surface,y,text,fg,bg,columns,rows)
  local cellW,cellH=surface.width/columns,surface.height/rows
  for py=math.floor((y-1)*cellH),math.floor(y*cellH)-1 do
    local glyphY=math.min(8,math.floor((py-(y-1)*cellH)*9/cellH))
    local output={}
    for x=1,#text do
      local front,back=tonumber(fg:sub(x,x),16),tonumber(bg:sub(x,x),16)
      local code=text:byte(x)
      local left,right=math.floor((x-1)*cellW),math.floor(x*cellW)
      if code>=128 and code<=159 then
        -- Preserve CC's 2x3 mosaic assets, including the implicit sixth pixel.
        local sy=math.min(2,math.floor(glyphY/3))
        local pixels={}
        for px=left,right-1 do
          local sx=math.min(1,math.floor((px-left)*2/math.max(1,right-left)))
          local bit=sy*2+sx
          pixels[#pixels+1]=string.char(bit<5 and math.floor((code-128)/2^bit)%2==1 and front or back)
        end
        output[x]=table.concat(pixels)
      else
        local glyph=fonts.row(code,glyphY,front,back)
        if right-left==6 then output[x]=glyph
        else
          local pixels={}
          for px=left,right-1 do pixels[#pixels+1]=glyph:sub(math.floor((px-left)*6/math.max(1,right-left))+1,math.floor((px-left)*6/math.max(1,right-left))+1) end
          output[x]=table.concat(pixels)
        end
      end
    end
    surface:span(0,py,table.concat(output))
  end
end
return M
