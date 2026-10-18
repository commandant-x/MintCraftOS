local data=require("system.graphics.font_data")
local M={width=6,height=9}
local glyphs={}
for code=0,255 do
  local columns={}
  for x=1,5 do columns[x]=tonumber(data:sub(code*10+x*2-1,code*10+x*2),16) end
  glyphs[code]=columns
end
function M.row(code,y,fg,bg)
  if y>=8 then return string.rep(string.char(bg),6) end
  local glyph=glyphs[code] or glyphs[63]
  local row={}
  for x=1,5 do row[x]=string.char(math.floor(glyph[x]/2^y)%2==1 and fg or bg) end
  row[6]=string.char(bg)
  return table.concat(row)
end
function M.measure(text,scale)
  scale=scale or 1
  assert(scale>=1 and scale<=4 and scale%1==0,"Invalid font scale")
  local width,lines=0,0
  for line in (text.."\n"):gmatch("([^\n]*)\n") do width=math.max(width,#line*6*scale) lines=lines+1 end
  return width,lines*9*scale
end
function M.draw(surface,x,y,text,fg,bg,scale)
  scale=scale or 1 M.measure("",scale)
  local origin=x
  for i=1,#text do
    local code=text:byte(i)
    if code==10 then x,y=origin,y+9*scale
    else
      for py=0,8 do
        local row=M.row(code,py,fg,bg)
        if scale>1 then row=row:gsub(".",function(c) return c:rep(scale) end) end
        for sy=0,scale-1 do surface:span(x,y+py*scale+sy,row) end
      end
      x=x+6*scale
    end
  end
end
return M
