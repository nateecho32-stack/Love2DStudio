-- Integer-id ECS: per-component stores, ordered systems, deferred destroy.
-- Adapted from Void Place engine/ecs.lua. Component iteration is sorted by id
-- so replays and tests stay deterministic.

local ecs = {}

function ecs.new()
  local E = {
    nextId = 1,
    stores = {},   -- component name -> { entityId = data }
    systems = {},  -- system name -> { fn = fn(world, dt), order = n }
    order = {},    -- system names sorted by order
    dead = {},     -- deferred destroys, swept at end of update
    count = 0,
  }

  function E:spawn()
    local id = self.nextId
    self.nextId = id + 1
    self.count = self.count + 1
    return id
  end

  function E:add(id, name, data)
    local store = self.stores[name]
    if not store then store = {} self.stores[name] = store end
    store[id] = data
    return data
  end

  function E:get(id, name)
    local store = self.stores[name]
    return store and store[id] or nil
  end

  function E:each(name, fn)
    local store = self.stores[name]
    if not store then return end
    local ids = {}
    for id in pairs(store) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = 1, #ids do
      fn(ids[i], store[ids[i]])
    end
  end

  function E:remove(id, name)
    local store = self.stores[name]
    if store then store[id] = nil end
  end

  -- deferred: swept at the end of update, safe inside system iteration
  function E:destroy(id) self.dead[id] = true end

  function E:addSystem(name, fn, order)
    self.systems[name] = { fn = fn, order = order or 0 }
    self.order = {}
    for n in pairs(self.systems) do self.order[#self.order + 1] = n end
    table.sort(self.order, function(a, b)
      return self.systems[a].order < self.systems[b].order
    end)
  end

  function E:update(dt)
    for i = 1, #self.order do
      self.systems[self.order[i]].fn(self, dt)
    end
    for id in pairs(self.dead) do
      for _, store in pairs(self.stores) do store[id] = nil end
      self.dead[id] = nil
      self.count = self.count - 1
    end
  end

  function E:alive() return self.count end

  return E
end

return ecs
