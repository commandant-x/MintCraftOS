local data=require("system.graphics.font_data")
local textCodec=require("system.graphics.text")
local View=require("system.graphics.view")
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
function M.measure(text,scale,encoding)
  if encoding then text=textCodec.decode(text,encoding) end
  scale=scale or 1
  assert(scale>=1 and scale<=4 and scale%1==0,"Invalid font scale")
  local width,lines=0,0
  for line in (text.."\n"):gmatch("([^\n]*)\n") do width=math.max(width,#line*6*scale) lines=lines+1 end
  return width,lines*9*scale
end
function M.draw(surface,x,y,text,fg,bg,scale,encoding)
  if encoding then text=textCodec.decode(text,encoding) end
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
-- Layout uses glyph bytes, so measurement, clipping and drawing agree exactly.
function M.layout(value,width,height,options)
  options=options or {}
  local scale=options.scale or 1 M.measure("",scale)
  local spacing=options.lineSpacing or 0
  assert(type(spacing)=="number" and spacing%1==0 and spacing>=0 and spacing<=64,"Invalid line spacing")
  assert(type(width)=="number" and width>=0 and width<math.huge and type(height)=="number" and height>=0 and height<math.huge,"Invalid text bounds")
  local align,valign=options.align or "left",options.valign or "top"
  assert(align=="left" or align=="center" or align=="right","Invalid text alignment")
  assert(valign=="top" or valign=="center" or valign=="bottom","Invalid text vertical alignment")
  local text,truncated=textCodec.decode(value,options.encoding or "auto")
  text=text:gsub("\r\n","\n"):gsub("\r","\n"):gsub("[%z\1-\8\11\12\14-\31\127]","?")
  local gw,gh=6*scale,9*scale
  local columns=math.floor(width/gw)
  local capacity=math.min(4096,math.max(0,math.floor((height+spacing)/(gh+spacing))))
  local lines={} local overflow=truncated
  local function add(s)
    if #lines>=capacity then overflow=true return false end
    if #s>columns then overflow=true s=s:sub(1,columns) end
    lines[#lines+1]={text=s,width=#s*gw}
    return true
  end
  if columns==0 or capacity==0 then return {lines=lines,width=0,height=0,overflow=#text>0 or truncated,scale=scale} end
  for paragraph in (text.."\n"):gmatch("([^\n]*)\n") do
    local expanded,col={},0
    for i=1,#paragraph do
      local c=paragraph:sub(i,i)
      if c=="\t" then local n=4-col%4 expanded[#expanded+1]=string.rep(" ",n) col=col+n
      else expanded[#expanded+1]=c col=col+1 end
    end
    paragraph=table.concat(expanded)
    local stopped,pos=false,1
    while options.wrap~=false and #paragraph-pos+1>columns do
      local cut
      for i=pos+1,pos+columns do if paragraph:byte(i)==32 then cut=i end end
      local first=cut and paragraph:sub(pos,cut-1):gsub(" +$","") or paragraph:sub(pos,pos+columns-1)
      if not add(first) then stopped=true break end
      pos=cut and cut+1 or pos+columns
      if cut then while paragraph:byte(pos)==32 do pos=pos+1 end end
    end
    if stopped or not add(paragraph:sub(pos)) then break end
  end
  local total=#lines>0 and #lines*(gh+spacing)-spacing or 0
  local top=valign=="center" and math.floor((height-total)/2) or valign=="bottom" and height-total or 0
  local measured=0
  for i,line in ipairs(lines) do
    line.x=align=="center" and math.floor((width-line.width)/2) or align=="right" and width-line.width or 0
    line.y=top+(i-1)*(gh+spacing) measured=math.max(measured,line.width)
  end
  return {lines=lines,width=measured,height=total,overflow=overflow,scale=scale}
end
function M.drawText(surface,x,y,width,height,text,fg,bg,options)
  local layout=M.layout(text,width,height,options)
  local canvas=View.new(surface,x,y,width,height)
  for _,line in ipairs(layout.lines) do M.draw(canvas,line.x,line.y,line.text,fg,bg,layout.scale) end
  return layout
end
M.decode=textCodec.decode
return M
