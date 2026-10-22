package.path='./?.lua;'..package.path
local revision,locked,enrolled=1,false,true
package.loaded['system.services.securityd']={sessionRevision=function() return revision end,isLocked=function() return locked end,authorize=function() return enrolled end}
local clipboard=require('system.graphics.clipboard')
assert(clipboard.set('editor text')) assert(clipboard.get()=='editor text')
assert(not clipboard.set(string.rep('x',65537))) assert(clipboard.get()=='editor text')
locked=true assert(clipboard.get()=='') assert(not clipboard.set('locked'))
locked=false revision=revision+1 assert(clipboard.get()=='')
assert(clipboard.set('terminal output')) revision=revision+1 assert(clipboard.get()=='','clipboard leaked across session identities')
enrolled=false assert(not clipboard.set('factory admin'))
print('shared clipboard: bounded text, cross-client memory, lock/logout/revision/enrollment isolation passed')
