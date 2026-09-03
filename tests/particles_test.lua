local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local particles = R("render.particles")

local function makePS()
  local ps = particles.new{ budget = 100, random = function() return 0.5 end }
  ps:registerPreset("puff", {
    count = 10, life = { 0.5, 0.5 }, speed = { 10, 10 },
    size = { 4, 4 }, colors = { { 1, 0, 0 }, { 0, 1, 0 } },
  })
  return ps
end

T.case("particles: emit spawns the preset count", function()
  local ps = makePS()
  ps:emit("puff", 0, 0)
  T.eq(ps:count(), 10)
end)

T.case("particles: quality ladder scales spawn; off means none", function()
  local ps = makePS()
  ps:setQuality("low")
  ps:emit("puff", 0, 0)
  T.eq(ps:count(), 4) -- 10 * 0.4
  ps:setQuality("off")
  ps:emit("puff", 0, 0)
  T.eq(ps:count(), 4)
end)

T.case("particles: unknown preset is a no-op, not an error", function()
  local ps = makePS()
  ps:emit("nope", 0, 0)
  T.eq(ps:count(), 0)
end)

T.case("particles: budget caps live particles", function()
  local ps = makePS()
  for _ = 1, 20 do ps:emit("puff", 0, 0) end
  T.eq(ps:count(), 100) -- budget
end)

T.case("particles: update retires dead particles back to the pool", function()
  local ps = makePS()
  ps:emit("puff", 0, 0)
  ps:update(0.6)
  T.eq(ps:count(), 0)
  -- pool reuse: emit again must work (free list fed)
  ps:emit("puff", 0, 0)
  T.eq(ps:count(), 10)
end)

T.case("particles: drag and gravity move particles", function()
  local ps = makePS()
  ps:registerPreset("fall", {
    count = 1, life = 1, speed = 0, gravity = 100, drag = 0,
    size = 4, colors = { { 1, 1, 1 } },
  })
  ps:emit("fall", 0, 0)
  ps:update(0.5)
  T.near(ps.live[1].vy, 50)
  T.near(ps.live[1].y, 25)
end)

T.case("particles: presetConfig returns a tweakable copy", function()
  local ps = makePS()
  local cfg = ps:presetConfig("puff")
  cfg.count = 3
  ps:registerPreset("puff", cfg)
  ps:emit("puff", 0, 0)
  T.eq(ps:count(), 3)
  T.eq(ps.presets.puff._idx, 1) -- re-register keeps a stable index
end)
