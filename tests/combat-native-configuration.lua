package.path='./?.lua;'..package.path
colors={} for i,n in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[n]=2^(i-1) end
keys={escape=1,enter=2,backspace=3,leftCtrl=4,rightCtrl=5,a=6,c=7,v=8}
term={getSize=function() return 100,40 end}
local addon=require('system.libraries.addon')
local stored={radars={},profiles={},aliases={}}
local snapshot={revision=1,radars={{id='wired-radar',kind='fixed',frame='world',rawPosition={x=10,y=70,z=20},position={x=10,y=70,z=20},capabilities={position=true},apiProfile='bridge',rawTrackCount=0}},targets={},cannons={{id='mount'}},devices={},acquisition={}}
local saves=0
package.loaded['system.services.combatd']={configuration=function() return addon.copy(stored) end,status=function() return {revision=1} end,displaySnapshot=function() return snapshot end,
 validateRadar=function(c) return c.frame=='world','unknown frame' end,
 configure=function(actor,section,id,value) assert(actor.pid==7 and section=='radars' and id=='wired-radar') saves=saves+1 stored.radars[id]=addon.copy(value) return true end,
 requestAim=function() error('configuration issued aim') end,requestFire=function() error('configuration issued fire') end,release=function() end}
local net={group='fixture',sharedKey='fixture-secret-key',allowInsecure=false,x=0,y=0,z=0,radius=100,alerts=false,trusted={}}
package.loaded['system.services.radarnetd']={configuration=function() return addon.copy(net) end,snapshot=function() return {} end}
package.loaded['system.services.sabled']={status=function() return {inSublevel=false} end}
local Surface=require('system.graphics.surface')
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local app,win
local function draw() app:drawPixels(Surface.new(600,400),600,400,p) end
local function click(id)
 for _=1,100 do
  draw()
  for _,hit in ipairs(app.nativePanel.state.hits or {}) do if hit.id==id or hit.kind=='choice' and ('fieldCycle:'..hit.id)==id then
   return app:handlePixels({name='mouse_click',args={1,hit.rect.x+1,hit.rect.y+1+app.nativePanel.header}})
  end end
  local nextHit
  for _,hit in ipairs(app.nativePanel.state.hits or {}) do if hit.kind==(id:match('^fieldCycle:') and 'fieldsPage' or 'actionsPage') and hit.id=='next' then nextHit=hit end end
  assert(nextHit,'native action missing: '..id)
  app:handlePixels({name='mouse_click',args={1,nextHit.rect.x+1,nextHit.rect.y+1+app.nativePanel.header}})
 end error('unreachable action '..id)
end
require('apps.combat.main').run({pid=7,onCleanup=function() end,startTimer=function() return 1 end,
 windowManager={create=function(_,opts) app=opts.app win={closed=false} return win end},
 pullEvent=function()
  assert(app.pixelPages.config and app.pixelPages.radar)
  app:handle({name='mouse_click',args={1,-999,-999},command='radarConfig'})
  assert(app.setup and app.pixelPages.radar,'setup fell back to terminal client')
  click('wizardNext') assert(app.setup.step==2 and saves==0)
  click('wizardNext') assert(app.setup.step==3 and saves==0)
  click('fieldCycle:4') assert(app.setup.drafts['wired-radar'].headingValidated)
  click('wizardNext') assert(app.setup.step==4 and saves==0)
  click('wizardNext') assert(not app.setup and saves==1 and stored.radars['wired-radar'].headingValidated)
  app.page='config' app.configKind='radar' draw()
  app.nativePanel.buffers={[1]='bad-frame'} app.tracking=true
  app:handlePixels({name='mouse_click',args={1,5,5}})
  assert(not app.tracking and app.page=='radar' and saves==1,'urgent cancel saved invalid draft or left tracking on')
  app:handle({name='mouse_click',args={1,-999,-999},command='networkConfig'}) draw()
  local secret
  for _,field in ipairs(app.nativePanel.state.model.fields) do if field.label=='Shared key (16+ chars)' then secret=field end end
  assert(secret and secret.secret,'network key lost native secret-field masking')
  win.closed=true return {name='test',args={}}
 end})
print('native Combat configuration: complete staged radar setup, no implicit save/aim/fire, invalid-draft cancel and network secret masking passed')
