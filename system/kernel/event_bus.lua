local log = require("system.libraries.log")

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({ listeners = {}, nextId = 1 }, EventBus)
end

function EventBus:on(name, callback)
  self.listeners[name] = self.listeners[name] or {}
  local id = self.nextId
  self.nextId = self.nextId + 1
  table.insert(self.listeners[name], { id = id, callback = callback })
  return id
end

function EventBus:off(id)
  for name, listeners in pairs(self.listeners) do
    for i = #listeners, 1, -1 do
      if listeners[i].id == id then
        table.remove(listeners, i)
        return true
      end
    end
  end
  return false
end

function EventBus:emit(name, ...)
  local listeners = self.listeners[name] or {}
  for _, listener in ipairs(listeners) do
    local ok, err = pcall(listener.callback, ...)
    if not ok then
      log.error("event_bus", tostring(err))
    end
  end
end

return EventBus
