package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = {info=function() end,error=function() end}
local attached, opens, sent = false, 0, 0
peripheral = {
  getNames=function() return attached and {"left"} or {} end,
  getType=function() return "modem" end,
}
rednet = {
  isOpen=function() return false end,
  open=function() opens=opens+1 end,
  broadcast=function() sent=sent+1 end,
}
textutils = {serialize=function(t) return t end,unserialize=function() return nil end}
os.getComputerID=function() return 10 end
local bus = require("system.kernel.event_bus").new()
local service = require("system.services.messaged")
service.start({eventBus=bus})
assert(service.statusText()=="no modem")
attached=true
bus:emit("peripheral","left")
assert(service.side=="left" and opens==1)
assert(service.statusText():find('unauthenticated and unencrypted',1,true))
assert(service.send("hello") and sent==1)
bus:emit("rednet_message",20,{type="message",id=99,from="Name",text="hello"},"mintcraft.chat")
assert(#service.list()==1 and service.list()[1].id==20)
bus:emit("rednet_message",20,{type="message",text={}},"mintcraft.chat")
assert(#service.list()==1)
bus:emit('rednet_message',20,string.rep('x',8193),'mintcraft.chat')
bus:emit('rednet_message',0/0,'hello','mintcraft.chat')
assert(#service.list()==1)
textutils.unserialize=function() error('malformed serialized data') end
bus:emit('rednet_message',20,'safe plain text','mintcraft.chat')
assert(#service.list()==2 and service.list()[2].text=='safe plain text')
local seen=service.snapshot().sequence
for i=1,130 do bus:emit('rednet_message',20,{type='message',text='message '..i},'mintcraft.chat') end
local snapshot=service.snapshot(seen)
assert(#service.list()==100 and #snapshot.messages==100 and snapshot.dropped and snapshot.sequence==seen+130)
assert(snapshot.messages[#snapshot.messages].text=='message 130')
snapshot.messages[1].text='changed' assert(service.list()[1].text~='changed','snapshot aliases inbox')
assert(#service.snapshot(snapshot.sequence).messages==0,'duplicate cached delivery')
bus:emit('rednet_message',20,{type='message',text='after rollover'},'mintcraft.chat')
assert(service.snapshot(snapshot.sequence).messages[1].text=='after rollover','full inbox lost new messages')
attached=false
bus:emit("peripheral_detach","left")
assert(service.side==nil and service.statusText()=="no modem")
service.start({eventBus=bus})
attached=true
local before=opens
bus:emit("peripheral","left")
assert(opens==before+1)
service.stop()
before=opens
bus:emit("peripheral","left")
assert(opens==before)
print("messenger tests passed")
