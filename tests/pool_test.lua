local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local pool = R("core.pool")

T.case("pool: reuses instances via the free list", function()
  local created = 0
  local P = pool.new(function()
    created = created + 1
    return { id = created }
  end)

  local a = P:acquire()
  T.eq(created, 1)
  P:release(a)
  local b = P:acquire()
  T.eq(created, 1)      -- same object came back
  T.eq(b.id, 1)
end)

T.case("pool: reset runs on release", function()
  local resets = 0
  local P = pool.new(function() return { x = 0 } end, function(obj)
    resets = resets + 1
    obj.x = 0
  end)

  local a = P:acquire()
  a.x = 42
  P:release(a)
  T.eq(resets, 1)
  local b = P:acquire()
  T.eq(b.x, 0)
end)

T.case("pool: live/cached accounting", function()
  local P = pool.new(function() return {} end)
  local a, b = P:acquire(), P:acquire()
  T.eq(P:live(), 2)
  P:release(a)
  T.eq(P:live(), 1)
  T.eq(P:cached(), 1)
  P:release(b)
  T.eq(P:live(), 0)
  T.eq(P:cached(), 2)
end)
