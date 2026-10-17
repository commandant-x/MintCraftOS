package.path="./?.lua;"..package.path
local now=10
os.clock=function() return now end os.getComputerID=function() return 1 end os.getComputerLabel=function() return "HQ" end
local addon=require("system.libraries.addon")
addon.periodic=function() return {stop=function() end,rescan=function() end} end
addon.inventory=function() return {{name="left",types={"modem"}}} end
local cfg={enabled=true,publish=true,allowInsecure=true,group="world-A",trusted={},x=0,y=0,z=0,radius=100,alerts=false}
package.loaded["system.libraries.config"]={load=function() return addon.copy(cfg) end}
package.loaded["system.libraries.safe_write"]={write=function() return true end}
package.loaded["system.security.permissions"]={require=function(actor) return actor.pid==7 end}
package.loaded["system.libraries.log"]={warn=function() end}
textutils={serialize=function() return "config" end}
local sent,closed,alerts={},0,0
rednet={isOpen=function() return true end,open=function() end,close=function() closed=closed+1 end,broadcast=function(packet,protocol) sent[#sent+1]={packet=packet,protocol=protocol} end}
local net=require("system.services.radarnetd")
-- The synchronous compatibility API is tested here; real listener ingress has
-- separate queue/worker coverage in radar-ingress.lua.
local listener=net.receive
net.start({scheduler={processes={[7]={state="ready",meta={appId="combat"},permissions={}}}},eventBus={on=function() return 1 end,off=function() end},notifications={push=function() alerts=alerts+1 end}})
local actor={pid=7}
local packet={version=1,session="boot-A",sequence=1,group="world-A",frame="world",label="Outpost",radars={{id="radar",position={x=1000,y=70,z=0},range=500,age=0}},targets={{id="uuid",position={x=20,y=70,z=30},radarId="radar",age=0,category="player",renderName="API name"}}}
assert(listener(2,packet,net.protocol))
assert(#net.snapshot().nodes==1 and #net.snapshot().targets==0,"unpaired station trusted automatically")
local saved=net.configuration() saved.trusted["2"]=true assert(net.configure(actor,saved))
local snap=net.snapshot() assert(#snap.targets==1 and snap.targets[1].remote and snap.targets[1].radarId=="net:2:radar")
assert(not listener(2,packet,net.protocol),"replayed sequence accepted")
local invalid=addon.copy(packet) invalid.sequence=2 invalid.frame="unknown" now=10.3
assert(not listener(2,invalid,net.protocol))
invalid=addon.copy(packet) invalid.sequence=2 invalid.targets={true}
assert(not listener(2,invalid,net.protocol),"malformed payload crashed/accepted")
invalid=addon.copy(packet) invalid.sequence=2 invalid.group="other-world"
assert(not listener(2,invalid,net.protocol))
invalid=addon.copy(packet) invalid.sequence=2 invalid.targets[1].position.x=0/0
assert(not listener(2,invalid,net.protocol))
now=15.1 assert(#net.snapshot().targets==0,"offline station never expired")
packet.sequence=2 packet.targets[1].age=4.9 assert(listener(2,packet,net.protocol))
now=15.3 assert(#net.snapshot().targets==0,"rebroadcast rejuvenated stale measurement")
local localSnapshot={radars={{id="local",position={x=0,y=0,z=0},range=100,timestamp=now},{id="remote",remote=true,position={x=0,y=0,z=0},range=100,timestamp=now}},targets={{id="a",radarId="local",position={x=10,y=0,z=10},timestamp=now},{id="b",remote=true,radarId="remote",position={x=10,y=0,z=10},timestamp=now}}}
local exported=net.publish(localSnapshot) assert(#exported.radars==1 and #exported.targets==1,"network relayed remote measurements")
package.loaded["system.services.combatd"]={snapshot=function() return localSnapshot end}
net.tick(true) assert(#sent==1 and sent[1].protocol==net.protocol)
saved=net.configuration() saved.alerts=true assert(net.configure(actor,saved))
net.checkPerimeter(localSnapshot) assert(alerts==1)
now=now+3 net.checkPerimeter(localSnapshot) assert(alerts==2,"second contact never alerted")
net.checkPerimeter(localSnapshot) assert(alerts==2,"same contact spammed")
localSnapshot.targets={} net.checkPerimeter(localSnapshot)
now=now+3 localSnapshot.targets={{id="a",position={x=0,y=0,z=0},timestamp=now}} net.checkPerimeter(localSnapshot) assert(alerts==3)
assert(not net.configure({pid=99},saved))
now=now+3 packet.sequence=3 packet.targets={} packet.radars={}
for i=1,40 do packet.radars[i]={id="radar_"..i,position={x=i*10,y=70,z=0},range=1000,heading=i*3,fov=80,halfHeight=20,running=i~=1,age=0} end
assert(listener(2,packet,net.protocol))
snap=net.snapshot() assert(#snap.radars==40 and snap.radars[1].running==false and snap.radars[2].halfHeight==20,"forty geometries/scan band not transported")
now=now+0.3 packet.sequence=4
for i=41,65 do packet.radars[i]=packet.radars[1] end
assert(not listener(2,packet,net.protocol),"unbounded station geometry accepted")
packet.radars={} packet.targets={}
for id=3,18 do assert(listener(id,packet,net.protocol)) end
assert(not listener(19,packet,net.protocol),'discovery quota not bounded')
saved=net.configuration() saved.trusted['99']=true assert(net.configure(actor,saved))
assert(listener(99,packet,net.protocol),'untrusted discovery flood blocked trusted station')
local found={}
snap=net.snapshot() for _,node in ipairs(snap.nodes) do found[node.id]=true end
assert(found[2] and found[99] and #snap.nodes==18,'discovery evicted paired station')
assert(snap.authenticated==false and snap.encrypted==false and snap.warning:find('spoofed',1,true))
now=now+0.3 packet.sequence=5
assert(listener(2,packet,net.protocol),'untrusted traffic blocked paired update')
net.stop() assert(closed==0,"stopping network broke Messenger modem")
print("radar network pairing, bounded packets, freshness, no relay and perimeter alerts passed")
