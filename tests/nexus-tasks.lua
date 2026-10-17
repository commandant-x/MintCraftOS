package.path="./?.lua;"..package.path
local tasks=require("system.nexus.tasks")
local rows={
 [1]={seenAt=99,capabilities={"storage","ping"}},
 [2]={seenAt=99,capabilities={"storage"}},
 [3]={seenAt=99,capabilities={"storage"}},
 [4]={seenAt=1,capabilities={"storage"}},
 [5]={seenAt=99,capabilities={"ping"}}}
local members={['1']={group='a'},['2']={group='a'},['4']={group='a'},['5']={group='a'}}
local jobs={{node=1,state='sent'},{node=2,state='completed'}}
local ids=tasks.targets(rows,members,jobs,'a','storage',100,true)
assert(#ids==2 and ids[1]==2 and ids[2]==1,'Load balancing or authorization/freshness/capabilities failed')
assert(#tasks.targets(rows,members,jobs,'a','storage',100,false)==1)
assert(#tasks.targets(rows,members,jobs,'b','storage',100,true)==0)
local history={}
for i=1,140 do history[i]={id=i,state=i%10==0 and 'queued' or 'completed'} end
local kept,removed=tasks.prune(history,64)
assert(#kept==64 and #removed==76)
local active=0 for _,job in ipairs(kept) do if job.state=='queued' then active=active+1 end end
assert(active==14 and kept[#kept].id==139,'Active missions or recent history lost')
print('NEXUS HIVE: capability/group authorization, freshness, balanced assignment and bounded history passed')
