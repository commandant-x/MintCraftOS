local log = require("system.libraries.log")

local M = {
  protocol = "mintcraft.chat",
  inbox = {},
  status = "not started",
  side = nil,
  ctx = nil,
  listener = nil,
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
  local packet = type(data) == "string" and textutils.unserialize(data) or data
  if type(packet) == "table" and packet.type == "message" then return packet end
  if type(data) == "string" and data ~= "" then
    return {
      type = "message",
      from = "Computer " .. tostring(sender),
      id = sender,
      text = data,
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
  if not peripheral or not peripheral.getNames or not rednet then
    M.status = "no rednet"
    return false, M.status
  end

  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      if not rednet.isOpen(name) then rednet.open(name) end
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
  return M.status
end

function M.list()
  return M.inbox
end

function M.send(text)
  text = tostring(text or "")
  if text == "" then return false, "empty message" end
  local ok, err = M.open()
  if not ok then return false, err end
  local packet = {
    type = "message",
    from = label(),
    id = computerId(),
    text = text,
    time = os.time and os.time() or 0,
  }
  rednet.broadcast(textutils.serialize(packet), M.protocol)
  return true, "sent"
end

function M.start(ctx)
  M.ctx = ctx
  M.open()
  if ctx and ctx.eventBus and not M.listener then
    M.listener = ctx.eventBus:on("rednet_message", function(sender, data, proto)
      if proto ~= nil and proto ~= M.protocol and proto ~= "mintcraft.public" then return end
      local packet = parse(data, sender)
      if not packet then return end
      if tonumber(packet.id) == computerId() and tonumber(sender) == computerId() then return end
      push(packet)
      M.status = "received from " .. tostring(sender)
      log.info("messaged", "message from " .. tostring(sender))
    end)
  end
  log.info("messaged", M.status)
end

function M.stop()
  if M.ctx and M.ctx.eventBus and M.listener then
    M.ctx.eventBus:off(M.listener)
  end
  M.listener = nil
end

return M
