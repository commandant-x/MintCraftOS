package.path='./?.lua;'..package.path
local edit=require('apps.editor.editing')
local a={lines={'local first=1','second line','last'},cx=3,cy=1}
edit.move(a,3,3,true) assert(edit.selected(a)=='cal first=1\nsecond line\nla')
assert(edit.removeSelection(a) and #a.lines==1 and a.lines[1]=='lost' and a.cx==3 and a.cy==1)
edit.move(a,1,999) assert(a.cx==5 and not a.anchor)
a={lines={'alpha beta','beta alpha',''},cx=1,cy=1}
assert(edit.find(a,'beta') and edit.selected(a)=='beta' and a.cy==1)
assert(edit.find(a,'beta') and a.cy==2)
assert(edit.find(a,'beta') and a.cy==1,'search did not wrap')
assert(not edit.find(a,'['),'search treated query as a pattern')
a.anchor={row=2,col=5} a.cy=1 a.cx=3
assert(edit.selected(a)=='pha beta\nbeta')
assert(edit.removeSelection(a) and a.lines[1]=='al alpha' and #a.lines==2)
local source='local text="hello \\\" world" -- note'
local tokens=edit.tokens(source) local combined={} local found={}
for _,token in ipairs(tokens) do combined[#combined+1]=token.text found[token.kind]=true end
assert(table.concat(combined)==source and found.keyword and found.string and found.comment)
print('Editor editing: multiline/reverse selection, replacement, cursor limits, literal wrap search and token preservation passed')
