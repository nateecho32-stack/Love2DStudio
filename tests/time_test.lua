local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local time = R("core.time")

-- the module holds state; start each case from defaults
local function reset()
  time.scale = 1
  time.paused = false
  time.fixedDt = nil
  time.maxFrame = 0.25
end

T.case("time: scale multiplies gameDt", function()
  reset()
  time.setScale(2)
  local gameDt = time.update(0.1)
  T.near(gameDt, 0.2)
  T.near(time.gameDt, 0.2)
  T.near(time.realDt, 0.1)
end)

T.case("time: pause zeroes gameDt", function()
  reset()
  local steps = 0
  time.setPaused(true)
  local gameDt = time.update(0.1, function() steps = steps + 1 end)
  T.eq(gameDt, 0)
  T.eq(steps, 0)
  time.setPaused(false)
  time.update(0.1, function() steps = steps + 1 end)
  T.eq(steps, 1)
end)

T.case("time: fixed stepping runs the right number of steps", function()
  reset()
  time.setFixed(1 / 60)
  local steps = 0
  time.update(1 / 60, function() steps = steps + 1 end)
  T.eq(steps, 1)
  time.update(0.5 / 60, function() steps = steps + 1 end)
  T.eq(steps, 1) -- remainder accumulates
  T.isTrue(time.alpha > 0 and time.alpha < 1)
  time.update(0.5 / 60, function() steps = steps + 1 end)
  T.eq(steps, 2)
end)

T.case("time: spiral-of-death guard caps catch-up", function()
  reset()
  time.setFixed(1 / 60)
  local steps = 0
  time.update(10, function() steps = steps + 1 end)
  T.isTrue(steps <= 16, "guard must cap steps, got " .. steps)
end)

T.case("time: clamps huge dt after a stall (window drag, alt-tab)", function()
  reset()
  time.maxDt = 0.1
  local gameDt = time.update(3) -- e.g. the whole duration of a window drag
  T.near(gameDt, 0.1)           -- simulated time must be clamped
  T.near(time.realDt, 3)        -- raw dt stays visible for hitch detection
  local steps = 0
  time.setFixed(1 / 60)
  time.update(5, function() steps = steps + 1 end)
  T.isTrue(steps <= 16, "fixed mode must also respect the clamp")
end)

T.case("time: alpha is a fraction within [0,1)", function()
  reset()
  time.setFixed(1 / 60)
  time.update(0.004)
  T.isTrue(time.alpha >= 0 and time.alpha < 1)
end)

T.case("time: togglePause flips state", function()
  reset()
  time.togglePause()
  T.isTrue(time.paused)
  time.togglePause()
  T.isNil(time.paused and true or nil)
  T.isTrue(not time.paused)
end)
