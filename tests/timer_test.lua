local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local timer = R("core.timer")

T.case("timer: after fires once at the right time", function()
  local t = timer.new()
  local fired = 0
  t:after(0.5, function() fired = fired + 1 end)
  t:update(0.2)
  t:update(0.2)
  T.eq(fired, 0)
  t:update(0.2)
  T.eq(fired, 1)
  t:update(1)
  T.eq(fired, 1) -- never again
end)

T.case("timer: every repeats", function()
  local t = timer.new()
  local fired = 0
  t:every(0.1, function() fired = fired + 1 end)
  for _ = 1, 10 do t:update(0.1) end
  T.eq(fired, 10)
end)

T.case("timer: cancel stops the callback", function()
  local t = timer.new()
  local fired = 0
  local h = t:every(0.1, function() fired = fired + 1 end)
  t:update(0.1)
  t:cancel(h)
  t:update(0.5)
  T.eq(fired, 1)
end)

T.case("timer: callbacks may add new timers (next frame)", function()
  local t = timer.new()
  local order = {}
  t:after(0.1, function()
    order[#order + 1] = "first"
    t:after(0.1, function() order[#order + 1] = "second" end)
  end)
  t:update(0.2)
  T.eq(order, { "first" })
  t:update(0.2)
  T.eq(order, { "first", "second" })
end)

T.case("timer: module-level default instance works", function()
  timer.clear()
  local fired = 0
  timer.after(0.05, function() fired = fired + 1 end)
  timer.update(0.1)
  T.eq(fired, 1)
end)
