-- Trigger volumes: archetype components (`trigger = {w, h, once, onEnter,
-- onLeave}`) become rect zones checked against a watched point (usually the
-- player). Enter/leave fire on the component's callbacks and on the bus.

local triggers = {}

-- ecs: an ecs world; opts: { bus = event bus (optional) }
function triggers.new(ecs, opts)
  opts = opts or {}
  local T = {
    ecs = ecs,
    bus = opts.bus,
    watchers = {},          -- name -> {x, y}
    _inside = {},           -- "watcherId:entityId" -> true while inside
    drawOutlines = false,   -- editor/debug visualization
  }

  -- register a moving point to test against every trigger
  function T:watch(id, x, y)
    local w = self.watchers[id]
    if not w then w = {} self.watchers[id] = w end
    w.x, w.y = x, y
  end

  function T:unwatch(id) self.watchers[id] = nil end

  function T:rectFor(entityId, transform, trigger)
    local s = transform.scale or 1
    local w, h = (trigger.w or 32) * s, (trigger.h or 32) * s
    return transform.x - w / 2, transform.y - h / 2, w, h
  end

  function T:update()
    local ecs = self.ecs
    for wid, w in pairs(self.watchers) do
      ecs:each("trigger", function(id, trigger)
        local transform = ecs:get(id, "transform")
        if not transform then return end
        local x, y, rw, rh = self:rectFor(id, transform, trigger)
        local insideNow = w.x >= x and w.x < x + rw and w.y >= y and w.y < y + rh
        local k = wid .. ":" .. id
        local wasInside = self._inside[k] == true
        if insideNow and not wasInside then
          self._inside[k] = true
          if trigger.onEnter then trigger.onEnter(id, wid) end
          if self.bus then self.bus.emit("trigger.enter", id, wid) end
        elseif not insideNow and wasInside then
          self._inside[k] = nil
          if trigger.onLeave then trigger.onLeave(id, wid) end
          if self.bus then self.bus.emit("trigger.leave", id, wid) end
          if trigger.once then ecs:destroy(id) end
        end
      end)
    end
  end

  -- editor/debug: dashed-ish outlines of every trigger volume
  function T:draw()
    if not self.drawOutlines then return end
    local ecs = self.ecs
    love.graphics.setColor(0.3, 1, 0.5, 0.7)
    ecs:each("trigger", function(id, trigger)
      local transform = ecs:get(id, "transform")
      if transform then
        local x, y, w, h = self:rectFor(id, transform, trigger)
        love.graphics.rectangle("line", x, y, w, h)
        if trigger.once then
          love.graphics.print("once", x + 2, y + 2)
        end
      end
    end)
    love.graphics.setColor(1, 1, 1, 1)
  end

  return T
end

return triggers
