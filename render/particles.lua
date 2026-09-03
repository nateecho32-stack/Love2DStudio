-- The ONE particle system: data-driven presets, pooled particles, quality
-- ladder (off/low/medium/high), and SpriteBatch bucketing by
-- (preset, color, alpha-level) so tinting stays cheap. API shape from the
-- Particles library; budget/quality ideas from 2d Trippy Hell
-- game/systems/effects/particles.lua.

local root = (...):match("^(.-)render%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local proc = R("render.proc")

local LEVELS = 8 -- alpha quantization levels per bucket
local QUALITY = { off = 0, low = 0.4, medium = 0.7, high = 1 }

local particles = {}

local function between(range, rng)
  if type(range) == "number" then return range end
  if not range then return nil end
  local lo, hi = range[1] or 0, range[2] or range[1] or 0
  return lo + (hi - lo) * rng()
end

function particles.new(opts)
  opts = opts or {}
  local PS = {
    budget = opts.budget or 600,
    quality = "high",
    presets = {},                    -- name -> cfg
    order = {},                      -- preset names in registration order
    live = {},
    free = {},
    random = opts.random or function() return love and love.math and love.math.random() or 0.5 end,
    _tex = nil,
    _batches = {},                   -- key -> SpriteBatch
    _colorMode = nil,                -- "add" (color bakes at :add) or "draw"
    _used = {},                      -- keys touched this frame
  }

  function PS:registerPreset(name, cfg)
    assert(type(cfg) == "table", "preset config required")
    cfg.colors = cfg.colors or { { 1, 1, 1 } }
    local existing = self.presets[name]
    if existing then
      cfg._idx = existing._idx -- re-registering keeps a stable bucket index
    else
      cfg._idx = #self.order + 1
      self.order[cfg._idx] = name
    end
    self.presets[name] = cfg
    return cfg
  end

  -- returns a fresh copy to tweak, Trippy's getPresetConfig pattern
  function PS:presetConfig(name)
    local src = self.presets[name]
    if not src then return nil end
    local copy = {}
    for k, v in pairs(src) do
      copy[k] = type(v) == "table" and { unpack(v) } or v
    end
    copy._idx = nil
    return copy
  end

  function PS:setQuality(name)
    assert(QUALITY[name], "unknown particle quality: " .. tostring(name))
    self.quality = name
  end

  function PS:count() return #self.live end

  function PS:emit(name, x, y)
    local cfg = self.presets[name]
    if not cfg then return end
    local count = math.floor((cfg.count or 10) * QUALITY[self.quality] + 0.5)
    local rng = self.random
    for _ = 1, count do
      if #self.live >= self.budget then return end
      local p = table.remove(self.free) or {}
      local size = between(cfg.size, rng) or 6
      p.x, p.y = x, y
      local ang = between(cfg.angle, rng)
      if ang == nil then ang = rng() * 2 * math.pi end
      local speed = between(cfg.speed, rng) or 0
      p.vx, p.vy = math.cos(ang) * speed, math.sin(ang) * speed
      p.life = between(cfg.life, rng) or 0.5
      p.maxLife = p.life
      p.size0 = size
      p.size1 = between(cfg.sizeEnd, rng)
      if p.size1 == nil then p.size1 = (cfg.fade == "shrink" or cfg.fade == "both") and 0 or size end
      p.rot = between(cfg.spin, rng) and rng() * math.pi or 0
      p.spin = between(cfg.spin, rng) or 0
      p.gravity = cfg.gravity or 0
      p.drag = cfg.drag or 0
      p.ci = math.min(#cfg.colors, math.max(1, math.ceil(rng() * #cfg.colors)))
      p.cfg = cfg
      self.live[#self.live + 1] = p
    end
  end

  function PS:update(dt)
    local live = self.live
    for i = #live, 1, -1 do
      local p = live[i]
      p.life = p.life - dt
      if p.life <= 0 then
        live[i] = live[#live]
        live[#live] = nil
        self.free[#self.free + 1] = p
      else
        if p.drag > 0 then
          local d = math.max(0, 1 - p.drag * dt)
          p.vx, p.vy = p.vx * d, p.vy * d
        end
        p.vy = p.vy + p.gravity * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        p.rot = p.rot + p.spin * dt
      end
    end
  end

  function PS:clear()
    for i = 1, #self.live do self.free[#self.free + 1] = self.live[i] end
    self.live = {}
  end

  -- one-time probe: does SpriteBatch tint at draw-time (LÖVE 11) or add-time?
  function PS:_probeColorMode()
    local ok = pcall(function()
      local canvas = love.graphics.newCanvas(4, 4)
      love.graphics.setCanvas(canvas)
      love.graphics.clear(0, 0, 0, 1)
      local sb = love.graphics.newSpriteBatch(self._tex, 4)
      love.graphics.setColor(1, 1, 1, 1)
      sb:add(2, 2, 0, 1, 1, self._tex:getWidth() / 2, self._tex:getHeight() / 2)
      love.graphics.setColor(1, 0, 0, 1)
      love.graphics.draw(sb, 0, 0)
      love.graphics.setCanvas()
      local r, g = canvas:newImageData():getPixel(2, 2)
      sb:release()
      canvas:release()
      self._colorMode = (r > 0.5 and g < 0.5) and "draw" or "add"
    end)
    if not ok then self._colorMode = "add" end
  end

  function PS:_ensure()
    if not self._tex then self._tex = proc.glowImage(16, 2) end
    if not self._colorMode then self:_probeColorMode() end
  end

  -- world space; pipeline has the world canvas set
  function PS:draw()
    if #self.live == 0 then
      for key in pairs(self._used) do
        self._batches[key]:clear()
        self._used[key] = nil
      end
      return
    end
    self:_ensure()
    local texHalf = self._tex:getWidth() / 2
    local used = {}

    -- SpriteBatches accumulate; every bucket touched last frame starts empty
    for key in pairs(self._used) do self._batches[key]:clear() end

    for i = 1, #self.live do
      local p = self.live[i]
      local cfg = p.cfg
      local k = 1 - p.life / p.maxLife          -- 0 fresh -> 1 dead
      local alpha = (cfg.fade == "fade" or cfg.fade == "both") and 1 - k or 1
      local level = math.min(LEVELS - 1, math.floor(alpha * LEVELS))
      local size = p.size0 + (p.size1 - p.size0) * k
      if size > 0.2 then
        local key = cfg._idx * 4096 + p.ci * 16 + level
        local batch = self._batches[key]
        if not batch then
          batch = love.graphics.newSpriteBatch(self._tex, self.budget)
          self._batches[key] = batch
        end
        used[key] = true
        self._used[key] = true
        local color = cfg.colors[p.ci]
        local a = (level + 0.5) / LEVELS
        if self._colorMode == "add" then
          love.graphics.setColor(color[1] * a, color[2] * a, color[3] * a, 1)
        else
          love.graphics.setColor(1, 1, 1, 1)
        end
        batch:add(p.x, p.y, p.rot, size / texHalf, size / texHalf, texHalf, texHalf)
      end
    end

    -- forget buckets that had nothing this frame
    for key in pairs(self._used) do
      if not used[key] then self._used[key] = nil end
    end

    -- flush, grouped by preset (keys are ordered preset-major)
    local keys = {}
    for key in pairs(used) do keys[#keys + 1] = key end
    table.sort(keys)
    local lastPreset = nil
    for i = 1, #keys do
      local key = keys[i]
      local presetIdx = math.floor(key / 4096)
      local level = key % 16
      local cfg = self.presets[self.order[presetIdx]]
      if presetIdx ~= lastPreset then
        love.graphics.setBlendMode(cfg.blend or "add")
        lastPreset = presetIdx
      end
      local color = cfg.colors[math.floor((key % 4096) / 16) + 1]
      local a = (level + 0.5) / LEVELS
      if self._colorMode == "add" then
        love.graphics.setColor(1, 1, 1, 1) -- tint baked at add time
      else
        love.graphics.setColor(color[1] * a, color[2] * a, color[3] * a, 1)
      end
      love.graphics.draw(self._batches[key], 0, 0)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
  end

  return PS
end

return particles
