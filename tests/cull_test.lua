local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local cull = R("render.cull")

local view = { x = 0, y = 0, w = 100, h = 100 }

T.case("cull: point", function()
  T.isTrue(cull.point(view, 50, 50))
  T.isTrue(cull.point(view, 0, 0))
  T.isTrue(cull.point(view, 100, 100))
  T.isTrue(not cull.point(view, 101, 50))
end)

T.case("cull: rect (inside, overlapping, fully out)", function()
  T.isTrue(cull.rect(view, 10, 10, 5, 5))
  T.isTrue(cull.rect(view, -5, -5, 10, 10)) -- overlaps the corner
  T.isTrue(not cull.rect(view, 200, 10, 5, 5))
  T.isTrue(not cull.rect(view, 10, 200, 5, 5))
end)

T.case("cull: circle (center outside but overlapping still counts)", function()
  T.isTrue(cull.circle(view, 50, 50, 5))
  T.isTrue(cull.circle(view, 105, 50, 10)) -- center out, edge in
  T.isTrue(not cull.circle(view, 150, 50, 10))
end)
