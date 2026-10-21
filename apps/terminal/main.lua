local renderer = require("system.gui.renderer")
local log = require("system.libraries.log")
local keyboard = require("system.gui.keyboard")
local ui = require("system.gui.components")
local autocomplete = require("system.dev.autocomplete")
local securityd = require("system.services.securityd")
local fileNames = require("system.libraries.file_names")
local authentication = require("system.libraries.auth_worker")
local pixel=require('apps.terminal.pixel')

local M = {}

local function sensitive(input)
  local command = input:match("^%s*(%S+)")
  return command == "login" or command == "unlock" or command == "passwd"
end

local function displayInput(input)
  if not sensitive(input) then return input end
  local command, args = input:match("^%s*(%S+)%s*(.*)$")
  return command .. (args ~= "" and " ***" or "")
end

local function append(app, line, color)
  line=tostring(line)
  if #line>4096 then line=line:sub(1,4070)..' [output truncated]' end
  app.outputSequence=(app.outputSequence or #app.lines)+1
  app.lineIds=app.lineIds or {} app.lineColors=app.lineColors or {}
  table.insert(app.lines,line) table.insert(app.lineIds,app.outputSequence) table.insert(app.lineColors,color or 'text')
  if #app.lines > 200 then table.remove(app.lines,1) table.remove(app.lineIds,1) table.remove(app.lineColors,1) end
  app.outputRevision=(app.outputRevision or 0)+1
end

local help = {
  ls = "ls [dir] - list directory",
  cd = "cd <dir> - change directory",
  pwd = "pwd - print current directory",
  mkdir = "mkdir <dir> - create directory",
  cp = "cp <src> <dst> - copy file or directory",
  mv = "mv <src> <dst> - move or rename",
  rm = "rm <path> - delete after yes confirmation",
  trash = "trash - open user trash in Files",
  restore = "restore <name> - restore from /home/user/.trash",
  cat = "cat <file> - show file",
  type = "type <file> - alias of cat",
  edit = "edit <file> - open Editor",
  open = "open <path> - open Files or Editor",
  ps = "ps - list processes",
  kill = "kill <pid> - kill after yes confirmation",
  logs = "logs - show recent logs",
  browser = "browser [url] - open text browser",
  crafttube = "crafttube - open native YouTube metadata client",
  messenger = "messenger - open Rednet chat",
  navigation = "navigation - open navigation; navigation pose - read cached orientation diagnostics",
  combat = "combat - open radar/CBC combat control center",
  store = "store - open package store",
  install = "install <pkg> - install package",
  display = "display [auto|computer|peripheral] - list or select the workstation",
  whoami = "whoami - show current security user",
  lock = "lock - lock current session",
  unlock = "unlock <password> - unlock current user",
  login = "login <user> [password] - switch user",
  logout = "logout - switch to guest",
  passwd = "passwd <old-password> <new-password> - change admin password",
}

local function trashPath(name)
  return fs.combine("/home/user/.trash", name)
end

local readPermissions={ls='filesystem.read',cd='filesystem.read',cat='filesystem.read',type='filesystem.read',
  cp='filesystem.read',ps='process.list',logs='logs.read'}

local function runCommand(app, ctx, input)
  append(app, "> " .. displayInput(input))
  local function writeAccess(path)
    if fileNames.protected(path) then return false,"Protected path" end
    return ctx.security.require("filesystem.write",path)
  end
  if app.pending then
    if input == "yes" then
      local pending = app.pending
      app.pending = nil
      pending()
      return
    end
    append(app, "cancelled")
    app.pending = nil
    return
  end

  local cmd, rest = input:match("^(%S+)%s*(.*)$")
  if not cmd then return end
  if readPermissions[cmd] then
    local ok,err=ctx.security.require(readPermissions[cmd],rest~='' and rest or app.cwd)
    if not ok then append(app,err,'error') return end
  end

  if cmd=='ls' or cmd=='cd' or cmd=='cat' or cmd=='type' then
    local target=fileNames.absolute(rest~='' and fs.combine(app.cwd,rest) or app.cwd)
    local ok,err=ctx.security.require('filesystem.read',target)
    if not ok then append(app,err,'error') return end
  end
  if cmd == "clear" then
    app:clearOutput()
  elseif cmd == "ls" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    if fs.exists(path) and fs.isDir(path) then
      for _, name in ipairs(fs.list(path)) do append(app, name) end
    else
      append(app, "Not a directory: " .. path)
    end
  elseif cmd == "cd" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or "/"
    if fs.exists(path) and fs.isDir(path) then app.cwd = path else append(app, "No such directory") end
  elseif cmd == "pwd" then
    append(app, app.cwd)
  elseif cmd == "mkdir" then
    if rest == "" then append(app, "Usage: mkdir <dir>") else
      local path = fs.combine(app.cwd, rest)
      local ok, err = writeAccess(path)
      if ok then fs.makeDir(path) ctx.security.audit("mkdir", path) else append(app, err) end
    end
  elseif cmd == "cp" then
    local src, dst = rest:match("^(%S+)%s+(.+)$")
    if not src or not dst then
      append(app, "Usage: cp <src> <dst>")
    else
      local from, to = fs.combine(app.cwd, src), fs.combine(app.cwd, dst)
      local readable,readError=ctx.security.require("filesystem.read",fileNames.absolute(from))
      if not readable then append(app,readError,'error') return end
      local ok, err = writeAccess(to)
      if not ok then append(app, err)
      elseif fs.exists(from) and not fs.exists(to) then
        local pending={fileNames.absolute(from)} local index=1
        while index<=#pending do
          local path=pending[index] index=index+1
          local permitted,problem=ctx.security.require('filesystem.read',path)
          if not permitted then append(app,problem,'error') return end
          if fs.isDir(path) then
            for _,name in ipairs(fs.list(path)) do
              if #pending>=4096 then append(app,'Copy tree exceeds safe preflight limit','error') return end
              pending[#pending+1]=fileNames.absolute(fs.combine(path,name))
            end
          end
        end
        fs.copy(from,to) ctx.security.audit("copy",from.." -> "..to)
      else append(app,"Cannot copy") end
    end
  elseif cmd == "mv" then
    local src, dst = rest:match("^(%S+)%s+(.+)$")
    if not src or not dst then
      append(app, "Usage: mv <src> <dst>")
    else
      local from, to = fs.combine(app.cwd, src), fs.combine(app.cwd, dst)
      local ok, err = writeAccess(to)
      if not ok then append(app, err)
      elseif fileNames.protected(from) then append(app, "Protected path")
      elseif fs.exists(from) and not fs.exists(to) then
        app.pending = function()
          local sourceAllowed, sourceError = writeAccess(from)
          local targetAllowed, targetError = writeAccess(to)
          if not sourceAllowed or not targetAllowed then append(app, sourceError or targetError) return end
          fs.move(from, to)
          ctx.security.audit("move", from .. " -> " .. to)
        end
        append(app, "Type yes to move " .. from .. " -> " .. to)
      else append(app, "Cannot move") end
    end
  elseif cmd == "rm" then
    if rest ~= "" then
      local path = fs.combine(app.cwd, rest)
      if fileNames.protected(path) then
        append(app, "Protected path")
      elseif fs.exists(path) then
        app.pending = function()
          local ok, err = writeAccess(path)
          if ok then fs.delete(path) ctx.security.audit("delete", path) append(app, "deleted") else append(app, err) end
        end
        append(app, "Type yes to delete " .. path)
      else
        append(app, "No such file")
      end
    else
      append(app, "Usage: rm <path>")
    end
  elseif cmd == "edit" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    ctx.apps.launch("editor", { path = path })
  elseif cmd == "open" then
    local path = rest ~= "" and fs.combine(app.cwd, rest) or app.cwd
    if fs.isDir(path) then ctx.apps.launch("files", { path = path }) else ctx.apps.launch("editor", { path = path }) end
  elseif cmd == "trash" then
    ctx.apps.launch("files", { path = "/home/user/.trash" })
  elseif cmd == "restore" then
    if rest == "" then
      append(app, "Usage: restore <name>")
    else
      local from = trashPath(rest)
      local to = fs.combine(app.cwd, rest)
      local ok, err = writeAccess(to)
      if not ok then append(app, err)
      elseif fs.exists(from) and not fs.exists(to) then fs.move(from, to) ctx.security.audit("restore", to) append(app, "restored") else append(app, "Cannot restore") end
    end
  elseif cmd == "cat" or cmd == "type" then
    local path = fs.combine(app.cwd, rest)
    if fs.exists(path) then
      local h = fs.open(path, "r")
      append(app, h.readAll() or "")
      h.close()
    else
      append(app, "No such file")
    end
  elseif cmd == "ps" then
    for _, p in ipairs(ctx.listProcesses()) do
      append(app, tostring(p.pid) .. " " .. p.state .. " " .. p.name)
    end
  elseif cmd == "kill" then
    local pid = tonumber(rest)
    if not pid then append(app, "Usage: kill <pid>") return end
    app.pending = function()
      local allowed, denied = ctx.security.require("process.kill", tostring(pid))
      if allowed then
        ctx.security.audit("kill", tostring(pid))
        local ok, err = ctx.kill(pid)
        append(app, ok and "killed" or tostring(err))
      else
        append(app, denied)
      end
    end
    append(app, "Type yes to kill pid " .. tostring(pid))
  elseif cmd == "logs" then
    for _, line in ipairs(log.tail(10)) do append(app, line) end
  elseif cmd == "browser" then
    ctx.apps.launch("browser", { url = rest })
  elseif cmd == "crafttube" then
    ctx.apps.launch("crafttube")
  elseif cmd == "messenger" then
    ctx.apps.launch("messenger")
  elseif cmd == "navigation" then
    if rest=="pose" then
      local permitted,denied=ctx.security.require("devices.list","navigation pose")
      if not permitted then append(app,tostring(denied)) return end
      local pose=require("system.services.sabled").pose()
      local logical=pose and pose.logicalPose
      local q=type(logical)=="table" and logical.orientation
      append(app,"Cached Sable pose; read only, no burner command")
      append(app,"orientation type: "..type(q))
      if type(q)=="table" then
        for _,key in ipairs({"x","y","z","w",1,2,3,4}) do
          local value=q[key]
          if type(key)=="string" or value~=nil then
            local scalar=type(value)=="number" or type(value)=="string" or type(value)=="boolean"
            append(app,tostring(key).." = "..(scalar and tostring(value):sub(1,80) or type(value)).." ["..type(value).."]")
          end
        end
      end
      append(app,"Pose age: "..(pose and type(pose.timestamp)=="number" and tostring(os.clock()-pose.timestamp) or "unknown"))
      append(app,"World frame: "..tostring(pose and pose.frame).." | on vehicle: "..tostring(pose and pose.inSublevel))
    elseif rest=="" then ctx.apps.launch("navigation")
    else append(app,"Usage: navigation [pose]") end
  elseif cmd == "combat" then
    ctx.apps.launch("combat")
  elseif cmd == "store" then
    ctx.apps.launch("store")
  elseif cmd == "install" then
    if rest == "" then append(app, "Usage: install <package>") else
      local allowed, denied = ctx.security.require("packages.install", rest)
      if allowed then ctx.security.audit("install", rest) local ok, msg = ctx.system.packages.install(rest) append(app, tostring(msg)) else append(app, denied) end
    end
  elseif cmd == "whoami" then
    append(app, securityd.statusText())
  elseif cmd == "lock" then
    local allowed, denied = ctx.security.require("system.auth", "lock")
    if allowed then securityd.lock() ctx.security.audit("lock", "terminal") append(app, "locked") else append(app, denied) end
  elseif cmd == "unlock" then
    local ok, msg = securityd.unlock(rest,app.authOptions)
    append(app, tostring(msg or ok))
  elseif cmd == "login" then
    local name, password = rest:match("^(%S+)%s*(.*)$")
    if not name then append(app, "Usage: login <user> [password]") else
      local ok, msg = securityd.login(name, password or "",app.authOptions)
      append(app, tostring(msg or ok))
    end
  elseif cmd == "logout" then
    securityd.logout()
    append(app, "guest session")
  elseif cmd == "passwd" then
    local oldPassword,newPassword=rest:match("^(%S+)%s+(.+)$")
    if not newPassword then append(app,"Usage: passwd <old-password> <new-password>; use Settings for an empty old password") else
      local allowed, denied = ctx.security.require("system.security.admin", "passwd")
      if allowed then
        local ok, msg = securityd.setPassword("admin",newPassword,oldPassword,{pid=ctx.pid,appId=ctx.appId,permissions=ctx.permissions},app.authOptions)
        append(app, ok and "password changed" or tostring(msg))
      else
        append(app, denied)
      end
    end
  elseif cmd == "files" then
    ctx.apps.launch("files")
  elseif cmd == "settings" then
    ctx.apps.launch("settings")
  elseif cmd == "devices" then
    ctx.apps.launch("devices")
  elseif cmd == "display" then
    local permitted,denied=ctx.security.require(rest=="" and "devices.list" or "system.config","display")
    if not permitted then append(app,tostring(denied)) return end
    local displays=require("system.services.deviced")
    if rest=="" then
      for _,row in ipairs(displays.listDisplays()) do append(app,(row.selected and "* " or "  ")..row.name..(row.available and "" or " (offline)")) end
    else
      local ok,problem=displays.setTarget(rest)
      if ok then ctx.security.audit("display",rest) end
      append(app,ok and "Display selected: "..rest or tostring(problem))
    end
  elseif cmd == "nexus" then
    local group=rest:match("^deploy%s+%-%-group%s+([%w_-]+)%s*$")
    if rest=="" or rest=="deploy" or group then
      local ok,err=ctx.apps.launch("nexus",{deploy=rest~="",group=group})
      if not ok then append(app,tostring(err)) end
    else append(app,"nexus deploy [--group factory]") end
  elseif cmd == "reboot" then
    local allowed, denied = ctx.security.require("system.reboot", "reboot")
    if allowed then ctx.security.audit("reboot", "terminal") os.reboot() else append(app, denied) end
  elseif cmd == "help" then
    if rest ~= "" and help[rest] then
      append(app, help[rest])
    else
      append(app, "Commands: " .. table.concat(autocomplete.commands(), " "))
      append(app, "Use help <cmd> for details.")
    end
  else
    append(app, "Unknown command: " .. cmd)
  end
end

function M.run(ctx)
  local authWorker
  local app = {
    lines = { "MintCraft Terminal", "Type help for commands." },
    input = "",
    cwd = "/home/user",
    caps = false,
    shift = false,
    suggestion = nil,
    history = {},
    historyIndex = nil,
    keyboard = {},
    lineIds={1,2},lineColors={'accent','muted'},outputSequence=2,outputRevision=0,follow=true,
  }

  local quick = {
    { id = "ls", label = "ls", text = "ls" },
    { id = "home", label = "cd home", text = "cd /home/user" },
    { id = "files", label = "files", text = "files" },
    { id = "ps", label = "ps", text = "ps" },
    { id = "logs", label = "logs", text = "logs" },
    { id = "clear", label = "clear", text = "clear" },
  }

  local function currentWord()
    return autocomplete.prefix(app.input, app.cursor or #app.input + 1, "([%w_%-/%.]+)$")
  end

  local suggestionInput, suggestionCwd, suggestionTime, suggestionCursor
  local function updateSuggestion()
    local now = os.clock()
    if sensitive(app.input) then
      app.suggestion=nil suggestionInput=nil app.completionError=nil
      return
    end
    if suggestionInput == app.input and suggestionCwd == app.cwd and suggestionCursor==app.cursor and now - suggestionTime < 1 then return end
    suggestionInput, suggestionCwd, suggestionTime,suggestionCursor=app.input,app.cwd,now,app.cursor
    local readable=ctx.security.require('filesystem.read',app.cwd)
    if not readable then app.suggestion=nil app.completionError='Autocomplete unavailable' return end
    local ok,result=pcall(function()
      local prefix=currentWord()
      return autocomplete.suggest({mode='terminal',prefix=prefix,cwd=app.cwd,text=app.input,cursor=app.cursor or #app.input+1})
    end)
    app.suggestion=ok and result or nil app.completionError=not ok and 'Autocomplete unavailable' or nil
  end

  local function acceptSuggestion()
    if not app.suggestion or suggestionInput~=app.input or suggestionCwd~=app.cwd or suggestionCursor~=app.cursor then updateSuggestion() end
    if not app.suggestion then return false end
    local prefix = currentWord()
    local text,cursor = autocomplete.apply(app.input, app.cursor or #app.input + 1, app.suggestion, prefix)
    app.input = text
    app.cursor=cursor or #text+1
    app.suggestion = nil
    return true
  end

  local function submit()
    local input = app.input
    app.input='' app.cursor=nil app.suggestion=nil app.follow=true
    if input ~= "" and not sensitive(input) then
      table.insert(app.history, input)
      if #app.history > 100 then table.remove(app.history, 1) end
      app.historyIndex = nil
    end
    if sensitive(input) then
      if app.authBusy then append(app,"Authentication already running") return end
      app.authBusy=true
      local queued,problem=authWorker:submit(input)
      if not queued then app.authBusy=false append(app,tostring(problem)) end
      return
    end
    local ok, err = pcall(runCommand, app, ctx, input)
    suggestionInput = nil
    if not ok then
      app.pending = nil
      if sensitive(input) then err = "Authentication command failed" end
      append(app, "Error: " .. tostring(err),'error')
      log.error("terminal", tostring(err))
    end
  end

  local function hitQuick(x, y)
    if y ~= 1 then return false end
    local cursor = 1
    for _, item in ipairs(quick) do
      local width = #item.label + 2
      if x >= cursor and x < cursor + width then
        app.input = item.text
        submit()
        return true
      end
      cursor = cursor + width + 1
    end
    return false
  end

  app.keyboard.onText = function(ch)
    ch=tostring(ch or ''):match('^[^\r\n]*') or ''
    local col=math.max(1,math.min(#app.input+1,app.cursor or #app.input+1))
    ch=ch:sub(1,math.max(0,4096-#app.input))
    app.input=app.input:sub(1,col-1)..ch..app.input:sub(col) app.cursor=col+#ch
    updateSuggestion()
  end
  app.keyboard.onBackspace = function()
    local col=math.max(1,math.min(#app.input+1,app.cursor or #app.input+1))
    if col>1 then app.input=app.input:sub(1,col-2)..app.input:sub(col) app.cursor=col-1 end
    updateSuggestion()
  end
  app.keyboard.onEnter = submit
  app.keyboard.onTab = acceptSuggestion
  app.keyboard.onControl = function(ch)
    if ch == "l" then app:clearOutput()
    elseif ch == "u" then app.input='' app.cursor=nil updateSuggestion() end
    if ch=='c' then app:action('copy') end
  end

  function app:clearOutput()
    self.lines={} self.lineIds={} self.lineColors={} self.selection=nil self.outputRevision=self.outputRevision+1 self.follow=true
  end
  function app:visibleInput() return displayInput(self.input),sensitive(self.input) end
  function app:refreshSuggestion() if type(autocomplete.suggest)=='function' then updateSuggestion() end end
  function app:action(id)
    if id=='keyboard' then self.pixelKeyboard=not self.pixelKeyboard
    elseif id=='live' then self.follow=true
    elseif id=='copy' then
      local rows={} local first,last=self.selection and self.selection.first,self.selection and self.selection.last
      if first and last then for i,line in ipairs(self.lines) do local seq=self.lineIds[i]
        if seq>=math.min(first,last) and seq<=math.max(first,last) then rows[#rows+1]=line end
      end end self.clipboard=table.concat(rows,'\n')
    elseif id=='paste' then if self.clipboard then self.keyboard.onText(self.clipboard) end
    elseif id=='clear' then self:clearOutput()
    elseif id=='submit' then submit()
    else for _,item in ipairs(quick) do if item.id==id then self.input=item.text self.cursor=nil submit() break end end end
  end

  function app:draw(w, h)
    if not self.graphicsActive then self.cursor=nil self.controlHeld=false end
    self.lastH = h
    local top = math.max(3, h - keyboard.height())
    local logHeight = math.max(1, top - 3)
    self.quickBoxes = ui.toolbar(1, 1, w, quick)

    local start = math.max(1, #self.lines - logHeight + 1)
    local y = 2
    for i = start, #self.lines do
      renderer.writeAt(1, y, renderer.crop(self.lines[i], w), colors.black, colors.lightGray)
      y = y + 1
      if y >= top - 1 then break end
    end
    local prompt = self.cwd .. "> " .. displayInput(self.input)
    if self.suggestion then prompt = prompt .. "  [tab " .. self.suggestion.label .. "]" end
    renderer.writeAt(1, top - 1, renderer.crop(prompt, w), colors.white, colors.gray)

    self.keyboard.x = 1
    self.keyboard.y = top
    self.keyboard.hint = self.suggestion and ("Tab: " .. self.suggestion.label) or ""
    keyboard.draw(1, top, w, self.keyboard)
  end

  function app:handle(event)
    if event.name == "char" or event.name=="paste" then
      self.keyboard.onText(event.args[1])
      return true
    elseif event.name == "key" then
      local key = event.args[1]
      if key == keys.enter then
        submit()
        return true
      elseif key == keys.backspace then
        self.keyboard.onBackspace()
        return true
      elseif key == keys.tab then
        acceptSuggestion()
        return true
      elseif key == keys.up then
        if #self.history > 0 then
          self.historyIndex = self.historyIndex and math.max(1, self.historyIndex - 1) or #self.history
          self.input = self.history[self.historyIndex] or self.input
          self.cursor=nil self:refreshSuggestion()
        end
        return true
      elseif key == keys.down then
        if self.historyIndex then
          self.historyIndex = self.historyIndex + 1
          if self.historyIndex > #self.history then self.historyIndex = nil self.input = "" else self.input = self.history[self.historyIndex] end
          self.cursor=nil self:refreshSuggestion()
        end
        return true
      end
    elseif event.name == "mouse_click" and event.monitorTouch then
      local _, x, y = table.unpack(event.args)
      local quickId = ui.toolbarHit(self.quickBoxes, x, y)
      if quickId then
        for _, item in ipairs(quick) do
          if item.id == quickId then app.input = item.text submit() return true end
        end
      end
      if hitQuick(x, y) then return true end
      if keyboard.handle(event, self.keyboard) then return true end
    end
    return false
  end

  app.handleText=app.handle
  pixel.attach(app)
  if ctx.system and ctx.system.eventBus and ctx.onCleanup then
    local bus=ctx.system.eventBus
    local listener=bus:on('key_up',function(key)
      if key==keys.leftCtrl or key==keys.rightCtrl then app.controlHeld=false end
    end)
    ctx.onCleanup(function() bus:off(listener) end)
  end
  app.handle=function(self,event)
    if self.graphicsActive and not event.name:match('^mouse_') then return self:handlePixels(event) end
    return self:handleText(event)
  end
  local sw, sh = term.getSize()
  local win = ctx.windowManager:create({ title = "Terminal", w = math.min(72, sw - 4), h = math.min(24, sh - 3), x = 4, y = 3, app = app })
  authWorker=authentication.new(ctx,function(input,options)
    app.authOptions=options
    return runCommand(app,ctx,input)
  end,function(ok)
    app.authBusy=false app.authOptions=nil suggestionInput=nil
    if not ok then append(app,"Authentication command failed") pcall(log.error,"terminal","Authentication command failed") end
  end)
  while not win.closed do ctx.pullEvent() end
end

return M
