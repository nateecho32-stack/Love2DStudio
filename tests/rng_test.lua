local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local rng = R("core.rng")

T.case("rng: same seed gives the same sequence (determinism contract)", function()
  local a, b = rng.new(42), rng.new(42)
  for _ = 1, 10 do
    T.eq(a:int(1, 1000), b:int(1, 1000))
    T.near(a:float(0, 1), b:float(0, 1))
  end
end)

T.case("rng: different seeds diverge", function()
  local a, b = rng.new(1), rng.new(2)
  local same = 0
  for _ = 1, 10 do
    if a:int(1, 1e9) == b:int(1, 1e9) then same = same + 1 end
  end
  T.isTrue(same < 10)
end)

T.case("rng: forIndex is stable per (seed, index) — chunk pattern", function()
  local a = rng.forIndex(7, 3)
  local b = rng.forIndex(7, 3)
  local c = rng.forIndex(7, 4)
  T.eq(a:int(1, 1e6), b:int(1, 1e6))
  T.isTrue(a:int(1, 1e6) ~= c:int(1, 1e6) or a.seed ~= c.seed)
end)

T.case("rng: int stays in range", function()
  local r = rng.new(5)
  for _ = 1, 500 do
    local v = r:int(3, 7)
    T.isTrue(v >= 3 and v <= 7)
  end
end)

T.case("rng: weighted never leaves the domain", function()
  local r = rng.new(9)
  local list = { { w = 5, v = "common" }, { w = 3, v = "rare" }, { w = 1, v = "exotic" } }
  local seen = {}
  for _ = 1, 1000 do
    local v = r:weighted(list)
    T.isTrue(v == "common" or v == "rare" or v == "exotic")
    seen[v] = (seen[v] or 0) + 1
  end
  T.isTrue(seen.common > seen.exotic, "higher weight must win on average")
end)

T.case("rng: weightedMap sorts keys so table order cannot matter", function()
  local r1, r2 = rng.new(3), rng.new(3)
  local m1, m2 = { a = 1, b = 2, c = 3 }, { c = 3, a = 1, b = 2 }
  for _ = 1, 50 do
    T.eq(r1:weightedMap(m1), r2:weightedMap(m2))
  end
end)

T.case("rng: shuffle keeps all elements", function()
  local r = rng.new(11)
  local t = { 1, 2, 3, 4, 5, 6, 7, 8 }
  r:shuffle(t)
  local count = 0
  local seen = {}
  for _, v in ipairs(t) do
    T.isNil(seen[v], "duplicate after shuffle")
    seen[v] = true
    count = count + 1
  end
  T.eq(count, 8)
end)

T.case("rng: fork is deterministic per salt", function()
  local a = rng.new(100):fork(7)
  local b = rng.new(100):fork(7)
  local c = rng.new(100):fork(8)
  T.eq(a:int(1, 1e6), b:int(1, 1e6))
  T.isTrue(a.seed ~= c.seed)
end)

T.case("rng: chance respects probability extremes", function()
  local r = rng.new(2)
  for _ = 1, 50 do T.isTrue(r:chance(1.0)) end
  for _ = 1, 50 do T.isTrue(not r:chance(0.0)) end
end)
