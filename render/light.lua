-- Point lights drawn additively onto the light canvas, which the pipeline
-- multiply-composites over the world. Glow texture is generated procedurally —
-- no binary assets. Adapted from Void Place render/light.lua and Burning
-- src/systems/lighting.lua.

local root = (...):match("^(.-)render%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local proc = R("render.proc")

local lights = {}

function lights.new(opts)
  opts = opts or {}
  local L = {
    ambient = opts.ambient or { 0.13, 0.13, 0.18 },
    items = {},
    _glow = nil,
  }

  function L:ensure()
    if not self._glow then self._glow = proc.glowImage(64, 2.5) end
  end

  -- ttl (seconds) makes the light fade out on its own; strength scales color
  function L:add(x, y, radius, r, g, b, strength, ttl)
    local item = {
      x = x, y = y, radius = radius,
      r = r, g = g, b = b,
      strength = strength or 1,
      ttl = ttl, t = 0,
    }
    self.items[#self.items + 1] = item
    return item
  end

  function L:remove(item)
    for i = 1, #self.items do
      if self.items[i] == item then
        table.remove(self.items, i)
        return true
      end
    end
    return false
  end

  function L:update(dt)
    for i = #self.items, 1, -1 do
      local item = self.items[i]
      if item.ttl then
        item.t = item.t + dt
        if item.t >= item.ttl then table.remove(self.items, i) end
      end
    end
  end

  function L:clear() self.items = {} end

  -- world space; the pipeline has the light canvas set
  function L:draw()
    if #self.items == 0 then return end
    self:ensure()
    local size = self._glow:getWidth()
    love.graphics.setBlendMode("add")
    for i = 1, #self.items do
      local it = self.items[i]
      local a = it.strength
      if it.ttl then
        -- fade the last 25% of life
        local remaining = it.ttl - it.t
        if remaining < it.ttl * 0.25 then a = a * remaining / (it.ttl * 0.25) end
      end
      love.graphics.setColor(it.r * a, it.g * a, it.b * a, 1)
      local s = it.radius * 2 / size
      love.graphics.draw(self._glow, it.x, it.y, 0, s, s, size / 2, size / 2)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
  end

  return L
end

return lights
