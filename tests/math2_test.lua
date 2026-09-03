local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local m = R("core.math2")

T.case("math2: clamp", function()
  T.eq(m.clamp(5, 0, 3), 3)
  T.eq(m.clamp(-5, 0, 3), 0)
  T.eq(m.clamp(2, 0, 3), 2)
end)

T.case("math2: lerp endpoints and midpoint", function()
  T.near(m.lerp(0, 10, 0), 0)
  T.near(m.lerp(0, 10, 1), 10)
  T.near(m.lerp(0, 10, 0.5), 5)
end)

T.case("math2: approach never overshoots", function()
  T.eq(m.approach(1, 5, 2), 3)
  T.eq(m.approach(4, 5, 2), 5)
  T.eq(m.approach(5, 1, 2), 3)
  T.eq(m.approach(2, 1, 2), 1)
end)

T.case("math2: aabb and pointInRect", function()
  T.isTrue(m.aabb(0, 0, 10, 10, 5, 5, 10, 10))
  T.isTrue(not m.aabb(0, 0, 10, 10, 11, 5, 10, 10))
  T.isTrue(m.pointInRect(3, 4, 0, 0, 10, 10))
  T.isTrue(not m.pointInRect(10, 4, 0, 0, 10, 10)) -- exclusive upper edge
end)

T.case("math2: easings land on 0 and 1", function()
  T.near(m.smoothstep(0), 0)
  T.near(m.smoothstep(1), 1)
  T.near(m.easeInCubic(1), 1)
  T.near(m.easeOutCubic(0), 0)
  T.near(m.easeOutCubic(1), 1)
  T.isTrue(m.smoothstep(-1) >= 0 and m.smoothstep(2) <= 1)
end)

T.case("math2: angleLerp takes the short way around and wraps to [0, 2pi)", function()
  T.near(m.angleLerp(0.1, 0.2, 0.5), 0.15, 1e-9)
  -- halfway across the 2pi seam: 6.2 -> 0.1 goes through 6.2916 == 0.0084
  T.near(m.angleLerp(6.2, 0.1, 0.5), 0.0084, 0.001)
end)
