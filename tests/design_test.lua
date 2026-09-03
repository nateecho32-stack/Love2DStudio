local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local design = R("tools.design_test")

T.case("design: assertUnchanged detects any tuning mutation", function()
  local config = { player = { speed = 200, dash = { power = 400 } } }
  local snapshot = design.snapshot(config)
  config.player.speed = 201
  local ok, detail = design.assertUnchanged(config, snapshot)
  T.isTrue(not ok)
  T.isTrue(tostring(detail):find("speed", 1, true) ~= nil)
end)

T.case("design: unchanged configs pass", function()
  local config = { a = { b = 1 }, list = { 1, 2, 3 } }
  T.isTrue(design.assertUnchanged(config, design.snapshot(config)))
end)

T.case("design: orderings assert trade direction", function()
  T.isTrue(design.assertIncreasing({ 1, 2, 3, 10 }))
  T.isTrue(not design.assertIncreasing({ 1, 3, 2 }))
  T.isTrue(design.assertDecreasing({ 9, 5, 1 }))
  T.isTrue(not design.assertDecreasing({ 9, 9, 1 }))
end)

T.case("design: monte-carlo + band checks seeded outcomes", function()
  local rng = { v = 0, random = function(self) self.v = (self.v + 0.1) % 1 return self.v end }
  local results = design.monteCarlo(10, rng, function(r) return r:random() * 10 end)
  T.eq(#results, 10)
  T.isTrue(design.assertBand(results, 0, 10))
  T.isTrue(not design.assertBand({ 5, 11 }, 0, 10))
  T.isTrue(not design.assertBand({ 0 / 0 }, 0, 10)) -- NaN escapes the band
end)

T.case("design: time budgets catch pacing drift", function()
  T.isTrue(design.assertTimeBudget(function() end, 0, 0.1))
  local ok = design.assertTimeBudget(function()
    local x = 0
    for i = 1, 2e6 do x = x + i end
    return x
  end, 0, 10)
  T.isTrue(ok)
end)
