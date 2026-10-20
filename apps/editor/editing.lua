local M={}
local function earlier(a,b) return a.row<b.row or a.row==b.row and a.col<b.col end
function M.range(app)
  local a=app.anchor local b={row=app.cy,col=app.cx}
  if not a or a.row==b.row and a.col==b.col then return end
  return earlier(a,b) and a or b,earlier(a,b) and b or a
end
function M.selected(app)
  local first,last=M.range(app) if not first then return '' end
  if first.row==last.row then return app.lines[first.row]:sub(first.col,last.col-1) end
  local rows={app.lines[first.row]:sub(first.col)}
  for row=first.row+1,last.row-1 do rows[#rows+1]=app.lines[row] end
  rows[#rows+1]=app.lines[last.row]:sub(1,last.col-1)
  return table.concat(rows,'\n')
end
function M.removeSelection(app)
  local first,last=M.range(app) app.anchor=nil if not first then return false end
  app.lines[first.row]=app.lines[first.row]:sub(1,first.col-1)..app.lines[last.row]:sub(last.col)
  for _=first.row+1,last.row do table.remove(app.lines,first.row+1) end
  app.cy,app.cx=first.row,first.col return true
end
function M.move(app,row,col,extend)
  if extend then app.anchor=app.anchor or {row=app.cy,col=app.cx} else app.anchor=nil end
  app.cy=math.max(1,math.min(#app.lines,row)) app.cx=math.max(1,math.min(#app.lines[app.cy]+1,col))
  app.revealCursor=true
end
function M.find(app,query)
  if query=='' then return false end
  -- Scan each line once, starting after the cursor and wrapping at EOF.
  for offset=0,#app.lines do
    local row=(app.cy+offset-1)%#app.lines+1
    local start=offset==0 and app.cx+1 or 1
    local found=app.lines[row]:find(query,start,true)
    if found and (offset<#app.lines or found<=app.cx) then
      app.anchor={row=row,col=found} app.cy,app.cx=row,found+#query app.revealCursor=true return true
    end
  end return false
end
local keywords={}
for word in ('and break do else elseif end false for function goto if in local nil not or repeat return then true until while'):gmatch('%S+') do keywords[word]=true end
function M.tokens(line)
  local out={} local i=1
  while i<=#line do
    local first=i local c=line:sub(i,i) local kind='text'
    if line:sub(i,i+1)=='--' then i=#line+1 kind='comment'
    elseif c=='"' or c=="'" then
      local quote=c i=i+1
      while i<=#line do local ch=line:sub(i,i) i=i+1 if ch=='\\' then i=i+1 elseif ch==quote then break end end
      kind='string'
    else
      local word=line:match('^[%a_][%w_]*',i)
      local number=line:match('^%d+%.?%d*',i)
      if word then i=i+#word kind=keywords[word] and 'keyword' or 'text'
      elseif number then i=i+#number kind='number'
      else i=i+1 end
    end
    out[#out+1]={text=line:sub(first,i-1),first=first,kind=kind}
  end return out
end
return M
