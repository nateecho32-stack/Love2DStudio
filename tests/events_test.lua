local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local events = R("core.events")

T.case("events: emit passes args to handlers", function()
  local bus = events.new()
  local got = {}
  bus.on("hit", function(a, b) got[#got + 1] = a + b end)
  bus.emit("hit", 2, 3)
  T.eq(got, { 5 })
end)

T.case("events: off unsubscribes via handle", function()
  local bus = events.new()
  local n = 0
  local h = bus.on("tick", function() n = n + 1 end)
  bus.emit("tick")
  T.isTrue(bus.off(h))
  bus.emit("tick")
  T.eq(n, 1)
end)

T.case("events: handler may unsubscribe itself during emit", function()
  local bus = events.new()
  local n = 0
  local h
  h = bus.on("tick", function()
    n = n + 1
    bus.off(h)
  end)
  bus.emit("tick")
  bus.emit("tick")
  T.eq(n, 1)
end)

T.case("events: independent buses do not cross-talk", function()
  local a, b = events.new(), events.new()
  local hits = 0
  a.on("x", function() hits = hits + 1 end)
  b.emit("x")
  T.eq(hits, 0)
  a.emit("x")
  T.eq(hits, 1)
end)

T.case("events: clear removes everything", function()
  local bus = events.new()
  local n = 0
  bus.on("x", function() n = n + 1 end)
  bus.clear()
  bus.emit("x")
  T.eq(n, 0)
end)

T.case("events: emitting an event with no handlers is a no-op", function()
  local bus = events.new()
  bus.emit("nothing", 1, 2)
  T.isTrue(true)
end)
