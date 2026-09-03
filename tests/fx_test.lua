local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local fx = R("render.fx")

local function makeDeps()
  local calls = {}
  local deps
  deps = fx.new{
    camera = { shake = function(self, s, d) calls[#calls + 1] = "shake:" .. s end },
    time = {
      scale = 1,
      setScale = function(self, s) self.scale = s end,
    },
    particles = { emit = function(self, preset, x, y) calls[#calls + 1] = "burst:" .. preset end },
    timers = {
      after = function(self, d, fn)
        calls[#calls + 1] = "after:" .. d
        deps.pendingRestore = fn -- test invokes manually
      end,
    },
    random = function() return 0.5 end,
  }
  return calls, deps
end

T.case("fx: play applies the preset composite", function()
  local calls, F = makeDeps()
  F:play("heavyHit", 10, 20)
  local joined = table.concat(calls, ",")
  T.isTrue(joined:find("shake:8", 1, true) ~= nil)
  T.isTrue(joined:find("burst:spark", 1, true) ~= nil)
  T.isTrue(joined:find("after:0.06", 1, true) ~= nil)
  T.eq(#F.rings, 1)
  T.eq(#F.nums, 1)
end)

T.case("fx: hitstop scales time and auto-restores", function()
  local calls, F = makeDeps()
  F:hitstop(0.1, 0.05)
  T.near(F.time.scale, 0.1)
  F.pendingRestore()
  T.near(F.time.scale, 1)
end)

T.case("fx: muted mode silences everything", function()
  local calls, F = makeDeps()
  F.muted = true
  F:play("death", 0, 0)
  F:shake(10, 1)
  F:burst("spark", 0, 0)
  F:flash(1, 1, 1, 1, 1)
  F:ring(0, 0, 1, 2, 1, "hot")
  F:damage(0, 0, "x", "hot")
  T.eq(#calls, 0)
  T.eq(#F.rings, 0)
  T.eq(#F.nums, 0)
  T.isNil(F.flashState)
end)

T.case("fx: rings and damage numbers age out", function()
  local _, F = makeDeps()
  F:ring(0, 0, 2, 10, 0.3, "hot")
  F:damage(0, 0, "+5", "cold")
  F:update(0.35)
  T.eq(#F.rings, 0)
  F:update(0.5) -- damage numbers live 0.7s
  T.eq(#F.nums, 0)
end)

T.case("fx: damage numbers float upward", function()
  local _, F = makeDeps()
  F:damage(100, 100, "+5", "cold")
  F:update(0.1)
  T.near(F.nums[1].y, 96, 0.01)
end)

T.case("fx: presets are overridable per game", function()
  local calls, F = makeDeps()
  F:definePreset("bigHit", { shake = 20, shakeDur = 0.5 })
  F:play("bigHit", 0, 0)
  T.isTrue(table.concat(calls, ","):find("shake:20", 1, true) ~= nil)
end)

T.case("fx: palette roles resolve to colors", function()
  local _, F = makeDeps()
  F:setPalette({ hot = { 0, 1, 0 } })
  F:ring(0, 0, 1, 2, 1, "hot")
  T.eq(F.rings[1].color, { 0, 1, 0 })
end)
