-- FX: juice primitives + named presets, following the conventions the audit
-- found already converged across projects: shake = camera punches (never
-- additive), hitstop = timeScale with auto-restore, presets read palette
-- roles instead of literal colors, everything no-ops when muted (headless
-- sims), and RNG is injectable. Reference: Void Place render/effects.lua,
-- PVZ near-miss/coin juice, Endless Grind float text.

local fx = {}

local DEFAULT_PRESETS = {
  hit      = { shake = 4, shakeDur = 0.15, ring = { r0 = 4, r1 = 36, dur = 0.2, color = "hot" }, text = "hit" },
  heavyHit = { shake = 8, shakeDur = 0.25, hitstop = { 0.15, 0.06 }, ring = { r0 = 6, r1 = 60, dur = 0.3, color = "hot" }, burst = "spark", text = "heavy" },
  death    = { shake = 10, shakeDur = 0.4, hitstop = { 0.05, 0.12 }, flash = { 0.9, 0.2, 0.2, 0.35, 0.12 }, burst = "spark" },
  heal     = { ring = { r0 = 8, r1 = 44, dur = 0.45, color = "cold" }, text = "+", color = "cold" },
  levelUp  = { shake = 5, shakeDur = 0.2, flash = { 1, 0.9, 0.5, 0.3, 0.15 }, ring = { r0 = 8, r1 = 90, dur = 0.5, color = "hot" }, text = "level up", color = "hot" },
  unlock   = { flash = { 1, 1, 1, 0.25, 0.1 }, ring = { r0 = 4, r1 = 70, dur = 0.4, color = "hot" }, text = "unlocked", color = "hot" },
  nearMiss = { shake = 6, shakeDur = 0.22, text = "close!", color = "hot" },
  coin     = { text = "+1", color = "hot" },
}

local function colorOf(F, key)
  if type(key) == "table" then return key end
  return F.palette[key] or F.palette.hot
end

function fx.new(deps)
  deps = deps or {}
  local F = {
    muted = false,
    camera = deps.camera,
    time = deps.time,
    particles = deps.particles,
    timers = deps.timers,
    random = deps.random or function() return love and love.math and love.math.random() or 0.5 end,
    font = deps.font,
    palette = {
      hot = { 1, 0.6, 0.2 }, cold = { 0.4, 0.7, 1 },
      dim = { 0.55, 0.55, 0.6 }, text = { 1, 1, 1 },
    },
    presets = {},
    rings = {},
    nums = {},
    flashState = nil,
    _restore = nil,
  }
  for name, spec in pairs(DEFAULT_PRESETS) do F.presets[name] = spec end

  function F:setPalette(p)
    for k, v in pairs(p) do F.palette[k] = v end
  end

  function F:definePreset(name, spec) F.presets[name] = spec end

  function F:shake(strength, dur)
    if F.muted or not F.camera then return end
    F.camera:shake(strength, dur)
  end

  function F:hitstop(scale, dur)
    if F.muted or not F.time then return end
    F.time:setScale(scale)
    if F.timers and not F._restore then
      F._restore = F.timers:after(dur, function()
        F.time:setScale(1)
        F._restore = nil
      end)
    end
  end

  function F:flash(r, g, b, strength, dur)
    if F.muted then return end
    F.flashState = { r = r, g = g, b = b, strength = strength, t = 0, dur = dur or 0.1 }
  end

  function F:ring(x, y, r0, r1, dur, color)
    if F.muted then return end
    F.rings[#F.rings + 1] = { x = x, y = y, r0 = r0, r1 = r1, dur = dur, color = colorOf(F, color), t = 0 }
  end

  function F:damage(x, y, text, color)
    if F.muted then return end
    F.nums[#F.nums + 1] = { x = x, y = y, text = tostring(text), color = colorOf(F, color), t = 0, dur = 0.7 }
  end

  function F:burst(preset, x, y)
    if F.muted or not F.particles then return end
    F.particles:emit(preset, x, y)
  end

  -- data-driven composite: fx.play("hit", x, y) applies a whole preset
  function F:play(name, x, y, opts)
    local spec = F.presets[name]
    if not spec then return end
    if F.muted then return end
    local scale = (opts and opts.scale) or 1
    if spec.shake then F:shake(spec.shake * scale, spec.shakeDur) end
    if spec.hitstop then F:hitstop(spec.hitstop[1], spec.hitstop[2]) end
    if spec.flash then F:flash(spec.flash[1], spec.flash[2], spec.flash[3], spec.flash[4], spec.flash[5]) end
    if spec.ring then
      F:ring(x, y, spec.ring.r0, spec.ring.r1 * scale, spec.ring.dur, spec.ring.color)
    end
    if spec.burst then F:burst(spec.burst, x, y) end
    if spec.text then F:damage(x, y - 18, spec.text, spec.color or "text") end
  end

  function F:update(dt)
    if F.flashState then
      local f = F.flashState
      f.t = f.t + dt
      if f.t >= f.dur then F.flashState = nil end
    end
    for i = #F.rings, 1, -1 do
      local ring = F.rings[i]
      ring.t = ring.t + dt
      if ring.t >= ring.dur then table.remove(F.rings, i) end
    end
    for i = #F.nums, 1, -1 do
      local n = F.nums[i]
      n.t = n.t + dt
      n.y = n.y - 40 * dt
      if n.t >= n.dur then table.remove(F.nums, i) end
    end
  end

  -- world space; register as a pipeline layer above entities
  function F:drawWorld()
    if F.muted then return end
    for i = 1, #F.rings do
      local ring = F.rings[i]
      local k = ring.t / ring.dur
      local r = ring.r0 + (ring.r1 - ring.r0) * k
      love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], 1 - k)
      love.graphics.circle("line", ring.x, ring.y, r)
    end
    for i = 1, #F.nums do
      local n = F.nums[i]
      local a = 1 - n.t / n.dur
      love.graphics.setColor(n.color[1], n.color[2], n.color[3], a)
      if F.font then love.graphics.setFont(F.font) end
      love.graphics.print(n.text, n.x, n.y)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- screen space; call after the pipeline (flash overlay)
  function F:drawScreen(vp)
    if F.muted or not F.flashState then return end
    local f = F.flashState
    local a = f.strength * (1 - f.t / f.dur)
    love.graphics.setColor(f.r, f.g, f.b, a)
    love.graphics.rectangle("fill", 0, 0, (vp and vp.width) or 1280, (vp and vp.height) or 720)
    love.graphics.setColor(1, 1, 1, 1)
  end

  return F
end

return fx
