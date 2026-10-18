package.path="./?.lua;"..package.path
local Surface=require("system.graphics.surface")
package.loaded["system.gui.theme"]={currentId="mint"}
local Workspace=require("system.graphics.workspace")
keys={escape=1,backspace=2,enter=3,up=4,down=5}
local apps={}
for i=1,16 do apps[i]={id="app"..i,name="Application "..i,iconPath="/absent"} end
local launches={}
local function setup(w,h)
  local wins={} local active
  local wm={windows=wins,active=function() return active end,focus=function(_,win) active=win end}
  local ctx={wm=wm,apps={list=function() return apps end,launch=function(id) launches[#launches+1]=id return true end},notifications={queue={}}}
  local backend={mode=1,surface=Surface.new(w,h,15),caps={textWidth=math.floor(w/6),textHeight=math.floor(h/9)}}
  local workspace=Workspace.new(ctx)
  local function frame()
    local saved=package
    package=nil
    local ok,err=pcall(function() workspace:prepare(backend) workspace:draw(backend) end)
    package=saved
    assert(ok,err)
  end
  local function pointer(name,x,y,button,touch)
    return workspace:handle({name=name,args={button or 1,1,1},pixelX=x,pixelY=y,monitorTouch=touch})
  end
  frame()
  return workspace,ctx,backend,frame,pointer
end
for _,size in ipairs({{306,171},{600,306},{960,540},{156,180}}) do
  local w,h=table.unpack(size)
  local workspace,ctx,backend,frame,pointer=setup(w,h)
  for _,hit in ipairs(workspace.hits) do assert(hit.rect.x+hit.rect.w<=w and hit.rect.y+hit.rect.h<=h-28) end
  local before=workspace.scene.stats.rectangles
  frame() assert(workspace.scene.stats.rectangles==before,"static pixel workspace was redrawn")
  pointer("mouse_click",workspace.search.x+2,workspace.search.y+2,1,true) frame()
  assert(workspace.menu and workspace.menuPanel.y>=0)
  for _,hit in ipairs(workspace.keyboardHits or {}) do
    assert(hit.rect.y>=workspace.menuInput.y+workspace.menuInput.h and hit.rect.y+hit.rect.h<=workspace.menuPanel.y+workspace.menuPanel.h,"keyboard overflow")
    for _,row in ipairs(workspace.menuRows) do
      assert(not require("system.graphics.scene").intersects(hit.rect,row.rect),"search result overlaps keyboard")
    end
    if hit.text then
      local ink=false
      for y=hit.rect.y,hit.rect.y+hit.rect.h-1 do
        local row=backend.surface.rows[y+1]
        for x=hit.rect.x,hit.rect.x+hit.rect.w-1 do if row:byte(x+1)==workspace.palette.text then ink=true end end
      end
      assert(ink,"touch key label vanished at pocket width")
    end
  end
  workspace:handle({name="paste",args={"Application 16"}}) frame()
  assert(#workspace:filtered()==1)
  workspace:handle({name="key",args={keys.enter}}) assert(launches[#launches]=="app16" and not workspace.menu)
end
local workspace,ctx,backend,frame,pointer=setup(600,306)
local handled,closed=0,0
local win={id=1,title="Files",x=4,y=4,w=38,h=14,dirty=true,surfaceRevision=1,
  requestClose=function(self) closed=closed+1 self.closed=true end,
  handle=function(_,e) handled=handled+1 assert(e.args[2]>=1 and e.args[3]>=1) end,
  surface={getLine=function() return string.rep("x",36),string.rep("0",36),string.rep("f",36) end,
    getCursorPos=function() return 1,1 end,getCursorBlink=function() return false end}}
ctx.wm.windows[1]=win ctx.wm:focus(win) frame()
local hit=workspace.windowHits[1]
local count=#launches
pointer("mouse_click",hit.client.x+2,hit.client.y+2) assert(handled==1 and #launches==count,"window click escaped to desktop")
pointer("mouse_click",hit.controls.minimize.x+3,hit.controls.minimize.y+4) frame()
assert(win.minimized and #workspace.windowHits==0)
pointer("mouse_click",workspace.taskHits[1].rect.x+2,workspace.taskHits[1].rect.y+2) frame()
assert(not win.minimized and ctx.wm:active()==win)
local original=win.pixelBounds.x
pointer("mouse_click",win.pixelBounds.x+5,win.pixelBounds.y+5)
pointer("mouse_drag",win.pixelBounds.x+12,win.pixelBounds.y+7)
pointer("mouse_up",0,0) frame()
assert(win.pixelBounds.x==original+7,"drag snapped to character cells")
local oldW=win.pixelBounds.w
pointer("mouse_click",win.pixelBounds.x+oldW-3,win.pixelBounds.y+win.pixelBounds.h-3)
pointer("mouse_drag",10000,10000) pointer("mouse_up",0,0) frame()
assert(win.pixelBounds.x+win.pixelBounds.w<=600 and win.pixelBounds.y+win.pixelBounds.h<=278)
hit=workspace.windowHits[1]
pointer("mouse_click",hit.controls.maximize.x+2,hit.controls.maximize.y+2) frame()
assert(win.maximized and win.pixelBounds.w==600)
hit=workspace.windowHits[1]
pointer("mouse_click",hit.controls.maximize.x+2,hit.controls.maximize.y+2) frame()
assert(not win.maximized)
ctx.notifications.queue={{id=1,title="Notice",message="Message",level="info"}} frame()
local before=handled local toast=workspace.notificationHits[1].rect
pointer("mouse_click",toast.x+5,toast.y+5) assert(handled==before,"notification click reached a window")
ctx.notifications.queue={} frame()
workspace.cacheLimit=0 win.surfaceRevision=2 frame()
assert(workspace.cacheBytes==0 and not workspace.content[win.id].surface,"bitmap cache limit ignored")
local x,y=win.pixelBounds.x+5,win.pixelBounds.y+5
win.pixelBounds.w,win.pixelBounds.h=300,180 frame()
x,y=win.pixelBounds.x+5,win.pixelBounds.y+5
local origin=win.pixelBounds.x
pointer("mouse_click",x,y,1,true) pointer("mouse_click",x+3,y+1,1,true) frame()
assert(win.pixelBounds.x==origin+3 and not workspace.drag,"monitor tap-to-place failed")
hit=workspace.windowHits[1]
pointer("mouse_click",hit.controls.close.x+2,hit.controls.close.y+2) assert(closed==1)
workspace:deactivate() assert(not win.pixelManaged and not win.pixelController)
local stream={}
local native={id=2,title="Native",x=3,y=3,w=30,h=16,surfaceRevision=1,
  app={drawPixels=function(_,s,w,h) s:rect(0,0,w,h,4) end,
    handlePixels=function(_,e) stream[#stream+1]=e return true end}}
native.drawPixels=function(self,...) return self.app.drawPixels(self.app,...) end
native.handlePixels=function(self,e) return self.app.handlePixels(self.app,e) end
ctx.wm.windows={native} ctx.wm:focus(native) frame()
local client=workspace.windowHits[1].client
pointer("mouse_click",client.x+4,client.y+6)
pointer("mouse_drag",700,400) pointer("mouse_up",700,400)
assert(#stream==3 and stream[1].args[2]==4 and stream[1].args[3]==6 and stream[2].name=="mouse_drag" and stream[3].name=="mouse_up")
assert(not workspace.clientCapture,"client pointer capture not released")
pointer("mouse_click",client.x+4,client.y+6) native.minimized=true frame()
assert(not workspace.clientCapture,"minimized native client retained capture")
print("pixel workspace: responsive launch/search, touch keyboard isolation, pixel drag, resize clamp, minimize/restore/maximize/close and no click-through passed")
