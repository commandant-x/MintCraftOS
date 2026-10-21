-- Run: lua5.2 tools/graphics-benchmark.lua /path/to/tree [1|4|8|16|32]
-- Synthetic pixel workloads, instrumented terminal; no Java/network/FPS claim.
local root=arg[1] or '.'
local batch=tonumber(arg[2]) or 16
package.path=root..'/?.lua;'..package.path
local Backend=require('system.graphics.backend')
local Scene=require('system.graphics.scene')
print('size\tscenario\tbatch\tdraw_calls\tfreeze_calls\tbytes\tcompose_ms\tpresent_ms\tpeak_lua_KiB')
for _,size in ipairs({{306,171},{480,270},{600,360},{960,540}}) do
 for _,scenario in ipairs({'static','move','resize','terminal','editor','overlap','taskmanager','radar-simulated','navigation-simulated','open-close','text-pixels','minimize-restore'}) do
  collectgarbage('collect')
  local startHeap=collectgarbage('count')
  local w,h=table.unpack(size)
  local mode,frozen=0,false local calls,freezes,bytes=0,0,0
  local t={getSize=function(m) return m and m>0 and w or 51,m and m>0 and h or 19 end,
   getGraphicsMode=function() return mode end,setGraphicsMode=function(m) mode=m end,
   getFrozen=function() return frozen end,setFrozen=function(v) frozen=v freezes=freezes+1 end,
   drawPixels=function(x,y,rows) calls=calls+1 for _,row in ipairs(rows) do bytes=bytes+#row end end}
  local b=Backend.new(t,'auto',{batchRows=batch})
  local scene=Scene.new() local compose,present,peak=0,0,startHeap
  for frame=1,scenario=='static' and 1001 or 51 do
   local before=os.clock()
   if scenario=='text-pixels' and frame>1 then b:close() b=Backend.new(t,'auto',{batchRows=batch}) end
   local x,y=30,30 local cw,ch=math.floor(w/2),math.floor(h/2)
   if scenario=='move' then x,y=frame%30,frame%20 end
   if scenario=='resize' then cw,ch=cw+frame%20,ch+frame%10 end
   local layers={{id='desktop',x=0,y=0,w=w,h=h,revision=1,draw=function(s) s:rect(0,0,w,h,15) end}}
   local visible=not ((scenario=='open-close' or scenario=='minimize-restore') and frame%2==0)
   if visible then
    layers[#layers+1]={id='client',x=x,y=y,w=cw,h=ch,revision=scenario=='static' and 1 or frame,draw=function(s)
      s:rect(x,y,cw,ch,7)
      if scenario=='radar-simulated' then
       for n=1,16 do s:rect(x+(frame*n)%cw,y+(frame+n*7)%ch,2,2,n%16) end
      elseif scenario=='navigation-simulated' then s:rect(x,y+frame%ch,cw,2,0)
      elseif scenario=='terminal' or scenario=='editor' then
       for n=1,8 do s:rect(x+5,y+n*10,math.min(cw-10,20+frame%20),2,0) end
      else s:rect(x+frame%cw,y+5,1,8,0) end
     end}
   end
   if scenario=='overlap' then layers[#layers+1]={id='top',x=x+20,y=y+20,w=cw,h=ch,revision=frame,draw=function(s) s:rect(x+20,y+20,cw,ch,8) end} end
   scene:draw(b.surface,layers)
   compose=compose+os.clock()-before
   before=os.clock() assert(b:present()) present=present+os.clock()-before
   peak=math.max(peak,collectgarbage('count'))
  end
  print(string.format('%dx%d\t%s\t%d\t%d\t%d\t%d\t%.3f\t%.3f\t%.1f',w,h,scenario,batch,calls,freezes,bytes,compose*1000,present*1000,peak-startHeap))
 end
end
