-- Pub/sub buses with unsubscribe handles.
-- Adapted from Void Place engine/events.lua.

local events = {}

function events.new()
  local bus = { _handlers = {} }

  -- returns a handle; pass it to bus.off to unsubscribe
  function bus.on(name, fn)
    local list = bus._handlers[name]
    if not list then list = {} bus._handlers[name] = list end
    local handle = { name = name, fn = fn }
    list[#list + 1] = handle
    return handle
  end

  function bus.off(handle)
    local list = bus._handlers[handle.name]
    if not list then return false end
    for i = 1, #list do
      if list[i] == handle then
        table.remove(list, i)
        return true
      end
    end
    return false
  end

  function bus.emit(name, ...)
    local list = bus._handlers[name]
    if not list then return end
    -- backwards so handlers may unsubscribe themselves/safely during emit;
    -- handlers subscribed during emit start next emit
    for i = #list, 1, -1 do
      list[i].fn(...)
    end
  end

  function bus.clear() bus._handlers = {} end
  return bus
end

return events
