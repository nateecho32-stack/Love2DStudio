local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local viewport = R("render.viewport")

T.case("viewport: perfect fit has zero offsets and unit scale", function()
  local v = viewport.new{ width = 100, height = 50, winW = 100, winH = 50 }
  T.near(v:scale(), 1)
  T.near(v:offsets(), 0, 0) -- offsets() returns two values; near checks first
end)

T.case("viewport: letterbox centers with pillarbox bars", function()
  local v = viewport.new{ width = 100, height = 50, winW = 200, winH = 50 }
  T.near(v:scale(), 1)
  local ox, oy = v:offsets()
  T.near(ox, 50)
  T.near(oy, 0)
end)

T.case("viewport: smaller window scales down uniformly", function()
  local v = viewport.new{ width = 100, height = 50, winW = 50, winH = 50 }
  T.near(v:scale(), 0.5)
end)

T.case("viewport: integerScale floors and never goes below 1", function()
  local v = viewport.new{ width = 100, height = 50, winW = 260, winH = 130, integerScale = true }
  T.eq(v:scale(), 2) -- would be 2.6 without the floor
  local tiny = viewport.new{ width = 100, height = 50, winW = 40, winH = 20, integerScale = true }
  T.eq(tiny:scale(), 1)
end)

T.case("viewport: toLogical/toScreen round-trip", function()
  local v = viewport.new{ width = 100, height = 50, winW = 200, winH = 50 }
  local lx, ly = v:toLogical(120, 25)
  T.near(lx, 70)
  T.near(ly, 25)
  local sx, sy = v:toScreen(lx, ly)
  T.near(sx, 120)
  T.near(sy, 25)
end)

T.case("viewport: contains respects the letterbox", function()
  local v = viewport.new{ width = 100, height = 50, winW = 200, winH = 50 }
  T.isTrue(v:contains(120, 25))
  T.isTrue(not v:contains(30, 25)) -- inside the left bar
end)
