package.path="./?.lua;"..package.path
local attitude=require("system.navigation.attitude")
local m={pitch={valid=true,value=0,observedAt=10,validUntil=10.5},
  roll={valid=true,value=12,observedAt=10,validUntil=10.5}}
local held,fresh=attitude.sample(m,nil,10.1)
assert(fresh and held.pitch==0 and held.roll==12)
local nextSample
nextSample,fresh=attitude.sample({},held,10.6)
assert(nextSample==held and not fresh)
nextSample,fresh=attitude.sample({},nextSample,10.9)
assert(nextSample==held and nextSample.observedAt==10 and not fresh)
assert(attitude.sample({},nextSample,11.01)==nil,"display hold refreshed its own timestamp")
assert(attitude.sample(m,nil,10.6)==nil,"expired service validity ignored")
m.roll.value=0/0
assert(attitude.sample(m,nil,10.1)==nil)
print("attitude: per-measure freshness, bounded stale display hold and no timestamp renewal passed")
