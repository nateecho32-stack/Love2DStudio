local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local grid = R("core.grid")

T.case("grid: query finds ids in a cell", function()
  local g = grid.new(64)
  g:insert("a", 10, 10)
  g:insert("b", 500, 500)
  local hits = g:queryRect(0, 0, 63, 63) -- 63: floor indexing keeps this inside cell 0:0
  T.eq(hits, { "a" })
end)

T.case("grid: query dedupes ids spanning multiple cells", function()
  local g = grid.new(16)
  g:insert("big", 0, 0, 100, 100)
  local hits = g:queryRect(0, 0, 16, 16)
  T.eq(hits, { "big" })
end)

T.case("grid: move re-indexes", function()
  local g = grid.new(64)
  g:insert("a", 10, 10)
  g:move("a", 500, 500)
  T.eq(g:queryRect(0, 0, 64, 64), {})
  T.eq(g:queryRect(480, 480, 64, 64), { "a" })
end)

T.case("grid: remove drops the id", function()
  local g = grid.new(64)
  g:insert("a", 10, 10)
  g:remove("a")
  T.eq(g:queryRect(0, 0, 128, 128), {})
  g:remove("a") -- removing again is a no-op
end)

T.case("grid: insert duplicate id raises", function()
  local g = grid.new(64)
  g:insert("a", 0, 0)
  T.fails(function() g:insert("a", 1, 1) end)
end)

T.case("grid: sized bodies overlap the right cells", function()
  local g = grid.new(32)
  g:insert("wall", 30, 30, 10, 10) -- straddles the 32px boundary
  local hits = g:queryRect(0, 0, 32, 32)
  T.eq(hits, { "wall" })
end)
