-- Optional numeric radio bridge. Cached values are never fresh control evidence.
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local channel=input('Channel') local code=input('Code') local value=input('Value') local tx=input('Transmit')
local clock=type(getUniverseTime)=='function' and getUniverseTime() or nil
local live=finite(clock) and clock>0
local s=_G.MintCraftRadio or {ready=false,high=false} _G.MintCraftRadio=s
local valid=finite(channel) and channel>0 and channel%1==0 and channel<=2147483647 and finite(code) and code%1==0 and math.abs(code)<=2147483647
local high=finite(tx) and tx>0
if not high then s.ready=true end
local regression=live and s.tick and clock<s.tick
if regression then s.ready=false end
if live then s.tick=clock end
if live and valid and not regression and high and not s.high and s.ready and finite(value) and type(sendPacket)=='function' then
 pcall(sendPacket,channel,code,value)
end
s.high=high
local cached
if valid and type(receivePacket)=='function' then local ok,v=pcall(receivePacket,channel,code) if ok and finite(v) then cached=v end end
output('Cached value',cached or 0)
output('Receive API readable',cached~=nil and 1 or 0)
output('Authenticated',0)
output('Fresh feedback',0)
