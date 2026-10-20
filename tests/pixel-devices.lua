package.path='./?.lua;'..package.path
keys={escape=1,tab=2,enter=3,up=4,down=5,home=6,['end']=7,backspace=8}
local model=require('apps.devices.model') local Surface=require('system.graphics.surface')
assert(model.value(false)=='false' and model.value(0)=='0' and model.value(nil)=='nil','primitive diagnostic value lost')
local actions={}
local app={rows={},scroll=1,query='',category='all',methods={},header={},message='Fixture',
  filteredRows=function(self) return model.filter(self.rows,self.query,self.category) end,
  selectedRow=function(self) for _,row in ipairs(self.rows) do if row.name==self.selected then return row end end end,
  detailText=function(self) return model.details(self:selectedRow(),{'getPosition','getTracks'}, {operationId=12,values={nested={position={x=1,y=2,z=3}}},errors={getPosition=string.rep('technical failure ',80)}}) end,
  filterChanged=function(self) self.scroll=1 self.selected=nil end,
  select=function(self,index) local rows=self:filteredRows() self.selected=rows[math.max(1,math.min(#rows,index))].name end,
  activate=function(self,id) actions[#actions+1]=id if id=='details' then self.inspect=not self.inspect end end}
for i=1,40 do app.rows[i]={name='device_'..i,type=i%2==0 and 'create_radar:radar_bearing' or 'monitor',types=i%2==0 and {'create_radar:radar_bearing'} or {'monitor'}} app.rows[i].role=model.role(app.rows[i]) end
assert(model.role({type='mixed',types={'mixed','modem'}})=='network','secondary type ignored')
require('apps.devices.pixel').attach(app)
local p={desktop=15,panel=7,button=15,text=0,muted=8,accent=9,ink=15,border=8}
local function draw(w,h)
  peripheral=setmetatable({},{__index=function() error('draw performed peripheral read') end})
  fs=setmetatable({},{__index=function() error('draw performed file read') end})
  app:drawPixels(Surface.new(w,h,15),w,h,p)
  for _,hit in ipairs(app.pixelHits) do local r=hit.rect assert(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'Device control outside window') end
end
local function click(id)
  for _,hit in ipairs(app.pixelHits) do if hit.id==id then return app:handlePixels({name='mouse_click',args={1,hit.rect.x+2,hit.rect.y+2}}) end end error('missing '..id)
end
for _,size in ipairs({{200,170},{306,171},{600,360},{960,500}}) do
  app.inspect=false app.selected=nil draw(size[1],size[2])
  local before=#actions click('probe') assert(#actions==before,'Probe enabled without selection')
  local hit=app.rowHits[1] app:handlePixels({name='mouse_click',args={1,hit.rect.x+2,hit.rect.y+2}})
  assert(app.selected=='device_1') draw(size[1],size[2]) assert(app.detailArea)
  local layout=app.detailLayout draw(size[1],size[2]) assert(layout==app.detailLayout,'static details rewrapped')
  app.probePending={id=1} draw(size[1],size[2]) click('probe') assert(#actions==before,'duplicate Probe accepted') app.probePending=nil
end
app.inspect=false draw(960,500) click('category') draw(960,500) assert(#app.rowHits==0 and not app.searchArea,'dropdown left underlying input active')
click('role:radar') assert(app.category=='radar' and #app:filteredRows()==20)
draw(960,500) app.focus='search' app:handlePixels({name='paste',args={'device_2'}}) assert(#app:filteredRows()==6)
app:handlePixels({name='key',args={keys.enter}}) assert(app.selected=='device_2')
app.focus='list' app:handlePixels({name='key',args={keys['end']}}) assert(app.selected=='device_28')
app.query='' app.category='all' app.inspect=false app.focus='probe' draw(150,100)
local before=#actions app:handlePixels({name='key',args={keys.enter}}) assert(#actions==before and #app.pixelHits==0)
local cyclic={} cyclic.self=cyclic assert(#model.value(cyclic)<100,'cyclic diagnostic not bounded')
local large={} for i=1,12 do large[i]=string.rep('x',10000) end
assert(#model.value(large)<=2048,'expanded values exceeded byte bound')
print('native Devices: responsive list/inspector, bounded diagnostics, search/category, disabled Probe, keyboard, cache-only drawing and resize safety passed')
