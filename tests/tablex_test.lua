local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local tablex = R("core.tablex")

T.case("tablex: deepCopy is independent", function()
  local a = { x = 1, nested = { y = { z = 3 } } }
  local b = tablex.deepCopy(a)
  b.nested.y.z = 9
  b.x = 2
  T.eq(a.nested.y.z, 3)
  T.eq(a.x, 1)
end)

T.case("tablex: merge — src wins, returns dst", function()
  local dst = { a = 1, b = 2 }
  local out = tablex.merge(dst, { b = 9, c = 3 })
  T.eq(out.a, 1)
  T.eq(out.b, 9)
  T.eq(out.c, 3)
  T.eq(out, dst)
end)

T.case("tablex: keys/count/contains/indexOf", function()
  local t = { alpha = 1, beta = 2 }
  T.eq(tablex.count(t), 2)
  T.eq(tablex.count(tablex.keys(t)), 2)
  T.isTrue(tablex.contains(t, 2))
  T.isTrue(not tablex.contains(t, 3))
  T.eq(tablex.indexOf({ 5, 6, 7 }, 6), 2)
  T.isNil(tablex.indexOf({ 5, 6, 7 }, 8))
end)

T.case("tablex: reversed is a copy", function()
  local t = { 1, 2, 3 }
  local r = tablex.reversed(t)
  T.eq(r, { 3, 2, 1 })
  T.eq(t, { 1, 2, 3 })
end)
