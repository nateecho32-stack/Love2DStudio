local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local tween = R("ui.tween")

T.case("tween: animates a property to its target", function()
  local m = tween.new()
  local obj = { x = 0 }
  m:to(obj, { x = 100 }, 1)
  m:update(0.5)
  T.isTrue(obj.x > 10 and obj.x < 100)
  m:update(0.5)
  T.near(obj.x, 100)
  m:update(1)
  T.near(obj.x, 100)
end)

T.case("tween: onDone fires exactly once at completion", function()
  local m = tween.new()
  local fired = 0
  m:to({ x = 0 }, { x = 10 }, 0.2, { onDone = function() fired = fired + 1 end })
  m:update(0.1)
  T.eq(fired, 0)
  m:update(0.2)
  T.eq(fired, 1)
  m:update(1)
  T.eq(fired, 1)
end)

T.case("tween: cancel stops animation", function()
  local m = tween.new()
  local obj = { x = 0 }
  local h = m:to(obj, { x = 100 }, 1)
  m:update(0.1)
  m:cancel(h)
  m:update(1)
  T.isTrue(obj.x < 100)
end)

T.case("tween: delay holds before animating", function()
  local m = tween.new()
  local obj = { x = 0 }
  m:to(obj, { x = 10 }, 0.2, { delay = 0.5 })
  m:update(0.4)
  T.near(obj.x, 0)
  m:update(0.2)
  T.isTrue(obj.x > 0)
end)

T.case("tween: multiple properties animate together", function()
  local m = tween.new()
  local obj = { x = 0, y = 100 }
  m:to(obj, { x = 10, y = 0 }, 1, { ease = tween.ease.linear })
  m:update(0.5)
  T.near(obj.x, 5)
  T.near(obj.y, 50)
end)
