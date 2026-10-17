local log = require("system.libraries.log")

local M = {
  protocol = "mintcraft.chat",
  inbox = {},
  status = "not started",
  side = nil,
  ctx = nil,
  listener = nil,
  deviceListeners = {},
  securityWarning = "INSECURE Rednet: unauthenticated and unencrypted; senders can be spoofed",
}

local function computerId()
  if os.getComputerID then return os.getComputerID() end
  if os.computerID then return os.computerID() end
  return 0
end

local function label()
  if os.getComputerLabel then
    local current = os.getComputerLabel()
    if current and current ~= "" then return current end
  end
  return "MintCraft-" .. tostring(computerId())
end

local function parse(data, sender)
  if type(data)=="string" and #data>8192 then return nil end
  local packet=data
  if type(data)=="string" then
    local ok,value=pcall(textutils.unserialize,data)
    packet=ok and value or nil
  end
  if type(packet) == "table" and packet.type == "message" and type(packet.text) == "string" then
    return {
      type = "message", id = sender,
      from = type(packet.from) == "string" and packet.from:sub(1, 64) or ("Computer " .. tostring(sender)),
      text = packet.text:sub(1, 4096), time = tonumber(packet.time) or 0,
    }
  end
  if type(data) == "string" and data ~= "" then
    return {
      type = "message",
      from = "Computer " .. tostring(sender),
      id = sender,
      text = data:sub(1, 4096),
      time = os.time and os.time() or 0,
    }
  end
  return nil
end

local function push(packet)
  table.insert(M.inbox, packet)
  if #M.inbox > 100 then table.remove(M.inbox, 1) end
end

function M.open()
  M.side = nil
  if not peripheral or not peripheral.getNames or not rednet then
    M.status = "no rednet"
    return false, M.status
  end

  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      local ok, err = pcall(function()
        if not rednet.isOpen(name) then rednet.open(name) end
      end)
      if not ok then M.status = "modem error: " .. tostring(err) return false, M.status end
      M.side = name
      M.status = "public chat ready on " .. tostring(name)
      return true, name
    end
  end

  M.status = "no modem"
  M.side = nil
  return false, M.status
end

function M.statusText()
  if M.side then return M.status.." | "..M.securityWarning end
  return M.status
end

function M.list()
  return M.inbox
end

function M.send(text)
  text = tostring(text or "")
  if text == "" then return false, "empty message" end
  if #text > 4096 then return false, "message too long" end
  local ok, err = M.open()
  if not ok then return false, err end
  local packet = {
    type = "message",
    from = label(),
    id = computerId(),
    text = text,
    time = os.time and os.time() or 0,
  }
  local sent, problem = pcall(rednet.broadcast, textutils.serialize(packet), M.protocol)
  if not sent then M.status = "send failed: " .. tostring(problem) return false, M.status end
  return true, "sent"
end

function M.start(ctx)
  M.stop()
  M.ctx = ctx
  M.open()
  if ctx and ctx.eventBus and not M.listener then
    M.listener = ctx.eventBus:on("rednet_message", function(sender, data, proto)
      if type(sender)~="number" or sender~=sender or sender<0 or sender==math.huge or sender%1~=0 then return end
      if proto ~= nil and proto ~= M.protocol and proto ~= "mintcraft.public" then return end
      local packet = parse(data, sender)
      if not packet then return end
      if tonumber(packet.id) == computerId() and tonumber(sender) == computerId() then return end
      push(packet)
      M.status = "received from " .. tostring(sender)
      log.info("messaged", "message from " .. tostring(sender))
    end)
  end
  if ctx and ctx.eventBus then
    for _, event in ipairs({ "peripheral", "peripheral_detach" }) do
      table.insert(M.deviceListeners, ctx.eventBus:on(event, function() M.open() end))
    end
  end
  log.info("messaged", M.status)
end

function M.stop()
  if M.ctx and M.ctx.eventBus and M.listener then
    M.ctx.eventBus:off(M.listener)
  end
  if M.ctx and M.ctx.eventBus then
    for _, id in ipairs(M.deviceListeners) do M.ctx.eventBus:off(id) end
  end
  M.deviceListeners = {}
  M.listener = nil
  M.ctx = nil
  M.status = "stopped"
end

return M
