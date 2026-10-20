package.path = "./?.lua;" .. package.path
package.loaded["system.libraries.log"] = {info=function() end,warn=function() end,error=function() end}
local cfg={repo="owner/repo",branch="main",autoCheck=true}
package.loaded["system.libraries.config"]={load=function() return cfg end,save=function() return true end}
local closes,writes=0,0
local bodies={}
local function response(body, code, broken)
  local offset=1
  return {
    readAll=function() error("unbounded HTTP read") end,
    read=function(n)
      assert(n>0 and n<=8192)
      if broken then error("read failed") end
      if offset>#body then return nil end
      local chunk=body:sub(offset,offset+n-1) offset=offset+#chunk return chunk
    end,
    getResponseCode=function() return code or 200 end,
    close=function() closes=closes+1 end,
  }
end
fs={exists=function() return false end,getDir=function() return "/var/tmp" end,makeDir=function() end,
  open=function() writes=writes+1 return {write=function() end,close=function() end} end}
http={get=function(url)
  assert(type(url)=="string", "positional mock compatibility lost")
  return response((assert(bodies[url], url)))
end,request=function() return true end}
local timer=0
os.startTimer=function() timer=timer+1 return timer end
os.cancelTimer=function() end
local sha=string.rep("a",40)
textutils={unserializeJSON=function(body) assert(body=="commit") return {sha=sha} end}
local updated=require("system.services.updated")
local versionURL="https://raw.githubusercontent.com/owner/repo/main/VERSION"
local commitURL="https://api.github.com/repos/owner/repo/commits/main"
local installerURL="https://raw.githubusercontent.com/owner/repo/"..sha.."/install.lua"
bodies[versionURL]="1.2.3"
assert(updated.remoteVersion()=="1.2.3")
bodies[versionURL]=string.rep("x",257)
assert(not updated.remoteVersion() and closes==2)
bodies[commitURL]=string.rep("x",262145)
assert(not updated.downloadInstaller() and writes==0 and closes==3)
bodies[commitURL]="commit"
bodies[installerURL]=string.rep("x",updated.maxInstallerBytes+1)
assert(not updated.downloadInstaller() and writes==0 and closes==5)
bodies[installerURL]="installer"
assert(updated.downloadInstaller() and writes==1 and closes==7)
local bus=require("system.kernel.event_bus").new()
updated.start({eventBus=bus})
bus:emit("http_success",versionURL.."?mintcraft_auto=1",response(string.rep("x",257)))
assert(not updated.status.updateAvailable and updated.status.message:find("byte limit",1,true))
updated.start({eventBus=bus})
bus:emit("http_success",versionURL.."?mintcraft_auto=1",response("",200,true))
assert(updated.status.message:find("read failed",1,true))
updated.start({eventBus=bus})
bus:emit("http_success",versionURL.."?mintcraft_auto=1",response("bad",500))
assert(updated.status.message=="GitHub HTTP 500")
assert(closes==10)
print("update bounded I/O contracts passed")
