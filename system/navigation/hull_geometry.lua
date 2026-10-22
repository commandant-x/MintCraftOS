-- Lossless block survey. Never guesses hull, wiring, RPM or unloaded geometry.
local addon=require('system.libraries.addon')
local M={MAX_BLOCKS=65536}
local function integer(n,low,high) return addon.finite(n) and n%1==0 and n>=low and n<=high end
function M.new(vehicle)
 return {vehicleId=vehicle,token='',nextPage=0,pages={},count=0,bytes=0,state='scanning',reason='Reading loaded block sections'}
end
function M.accept(scan,p)
 if type(p)~='table' or p.schema~=1 or p.ok~=true or p.readOnly~=true or p.vehicleId~=scan.vehicleId or p.frame~='body_plot' or p.units~='block' then return false,'Invalid hull frame / vehicle / schema' end
 if type(p.token)~='string' or #p.token<1 or #p.token>128 or not integer(p.page,0,1023) or p.page~=scan.nextPage or not integer(p.pages,1,1024) or p.page>=p.pages then return false,'Invalid hull page sequence' end
 if scan.token~='' and (scan.token~=p.token or scan.total~=p.pages or scan.coverage~=p.coverageComplete) then return false,'Hull survey changed' end
 local origin=addon.vec(p.origin)
 if not origin or not integer(origin.x,-1000000,1000000) or not integer(origin.y,-1000000,1000000) or not integer(origin.z,-1000000,1000000) then return false,'Invalid block origin' end
 if not addon.finite(p.startedTick) or not addon.finite(p.observedTick) or p.observedTick<p.startedTick or scan.startedTick and p.startedTick~=scan.startedTick then return false,'Invalid survey clock' end
 if type(p.palette)~='table' or #p.palette>4096 or type(p.runs)~='string' or #p.runs>65536 then return false,'Invalid hull payload' end
 local palette={}
 for i,row in ipairs(p.palette) do
  if type(row)~='table' or type(row.block)~='string' or #row.block>128 or not row.block:match('^[%w_%-]+:[%w_/%-%.]+$') or type(row.state)~='string' or #row.state>1024 then return false,'Invalid block palette' end
  palette[i]={block=row.block,state=row.state}
 end
 local at,last,count,bytes=1,-1,0,#p.runs
 for _,row in ipairs(palette) do bytes=bytes+#row.state+#row.block end
 while at<=#p.runs do
  local a,b,start,length,id=p.runs:find('(%d+):(%d+):(%d+);',at)
  if a~=at then return false,'Invalid hull run' end
  start,length,id=tonumber(start),tonumber(length),tonumber(id)
  if not integer(start,0,4095) or not integer(length,1,4096-start) or start<=last or not integer(id,1,#palette) then return false,'Overlapping/out-of-range hull run' end
  last=start+length-1 count=count+length at=b+1
 end
 if scan.count+count>M.MAX_BLOCKS or scan.bytes+bytes>2097152 then return false,'Hull memory limit: survey incomplete (65536 blocks / 2 MiB encoded)' end
 scan.token,scan.total,scan.coverage=p.token,p.pages,p.coverageComplete==true
 scan.startedTick,scan.observedTick=p.startedTick,p.observedTick
 scan.pages[#scan.pages+1]={origin=origin,palette=palette,runs=p.runs}
 scan.count,scan.bytes=scan.count+count,scan.bytes+bytes scan.nextPage=scan.nextPage+1
 scan.state=scan.nextPage==scan.total and 'complete' or 'scanning'
 scan.reason=scan.state=='complete' and (scan.coverage and 'Loaded parent plot surveyed' or 'Survey partial: unloaded chunks or bridge limit') or ('Sections '..scan.nextPage..'/'..scan.total)
 return true
end
function M.blocks(scan)
 local out={}
 for _,page in ipairs(scan.pages or {}) do
  for start,length,id in page.runs:gmatch('(%d+):(%d+):(%d+);') do
   start,length,id=tonumber(start),tonumber(length),tonumber(id)
   for n=start,start+length-1 do
    out[#out+1]={x=page.origin.x+n%16,y=page.origin.y+math.floor(n/256),z=page.origin.z+math.floor(n/16)%16,material=page.palette[id]}
   end
  end
 end
 return out
end
function M.label(scan)
 if not scan then return 'Hull unavailable: Vehicle Bridge 0.2.2 required' end
 return tostring(scan.count)..' blocks | '..scan.reason..' | survey, not live collision data; parent only'
end
return M
