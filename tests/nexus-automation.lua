package.path="./?.lua;"..package.path
local auto=require("system.nexus.automation")
local p={enabled=true,ids={1,2},group="factory",attempts={},holds={}}
local members={["1"]={group="factory"},["2"]={group="factory"},["3"]={group="factory"}}
local rows={[1]={name="pc1",age=math.huge},[2]={name="pc2",age=math.huge},[3]={name="foreign",age=math.huge}}
local step=auto.plan(p,rows,members,"new",100000)
assert(step.kind=="deploy" and step.id==1 and step.count==1)
p.attempts["1"]={release="new",count=1,at=100000}
assert(auto.plan(p,rows,members,"new",100001).id==2)
p.holds["2"]=true
assert(auto.plan(p,rows,members,"new",100001).kind=="waiting")
assert(auto.plan(p,rows,members,"new",160000).id==1)
p.attempts["1"].count=2
assert(auto.plan(p,rows,members,"new",200000).kind=="waiting")
for id=1,2 do rows[id].seenAt=10 rows[id].age=0 rows[id].release="new" end
assert(auto.plan(p,rows,members,"new",200000).kind=="seal")
p.sealedRelease="new"
rows[1].age=100
assert(auto.plan(p,rows,members,"new",200000).kind=="waiting","Offline enrolled PC must not be rebooted")
members["1"]=nil
assert(auto.plan(p,rows,members,"new",200000).kind=="blocked")
p.enabled=false
assert(auto.plan(p,rows,members,"new",200000)==nil)
p.enabled=true members['1']={group='factory'} p.sealedRelease=nil p.holds={} p.attempts={}
rows[1].age=0 rows[2].age=0 p.resetToken=string.rep('r',40)
assert(auto.plan(p,rows,members,'new',200000).kind=='deploy','Reset skipped agent already on current release')
for id=1,2 do rows[id].provisionToken=p.resetToken end
assert(auto.plan(p,rows,members,'new',200000).kind=='seal','Reset sealed before operation-specific acknowledgements')
print("NEXUS automation: frozen scope, retries, cooldown, holds and sealing OK")
local policy={enabled=true,ids={1},group='factory',allowReset=true,attempts={['1']={release='new',count=2,at=100000}}}
local fleet={[1]={name='pc1',release='old',age=999}}
assert(auto.plan(policy,fleet,members,'new',200000).kind=='waiting','Missing heartbeat caused destructive recovery')
fleet[1].updateFailure=true
assert(auto.plan(policy,fleet,members,'new',120000).kind=='waiting','Recovery ignored cooldown')
assert(auto.plan(policy,fleet,members,'new',200000).kind=='reset','Confirmed failed update did not escalate')
policy.allowReset=false
assert(auto.plan(policy,fleet,members,'new',200000).kind=='waiting','Legacy consent escalated to erase')
policy.allowReset=true policy.resets={['1']={release='new',token=string.rep('r',40)}}
local recovery=auto.plan(policy,fleet,members,'new',200000)
assert(recovery.kind=='deploy' and recovery.phase=='reset' and recovery.count==1)
policy.attempts['1']={release='new',phase='reset',count=2,at=100000}
assert(auto.plan(policy,fleet,members,'new',200000).kind=='waiting','Destructive recovery loop is unbounded')
