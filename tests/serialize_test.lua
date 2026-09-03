local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local serialize = R("save.serialize")

T.case("serialize: round-trips nested tables, arrays and scalars", function()
  local data = {
    name = "slot \"one\"",
    depth = 1234.5,
    alive = true,
    dead = false,
    inventory = { "sword", "rope", "apple" },
    stats = { hp = 10, mp = 3 },
    mixed = { 1, 2, key = "v", [99] = "sparse tail" },
  }
  local out = serialize.decode(serialize.encode(data))
  T.eq(out, data)
end)

T.case("serialize: escapes newlines and quotes", function()
  local data = { text = "line1\nline2 \"quoted\"\n" }
  local out = serialize.decode(serialize.encode(data))
  T.eq(out.text, "line1\nline2 \"quoted\"\n")
end)

T.case("serialize: drops functions and userdata (documented contract)", function()
  local data = { keep = 1, fn = function() end }
  local out = serialize.decode(serialize.encode(data))
  T.eq(out.keep, 1)
  T.isNil(out.fn)
end)

T.case("serialize: cycles drop instead of hanging", function()
  local data = { a = 1 }
  data.self = data
  local out = serialize.decode(serialize.encode(data))
  T.eq(out.a, 1)
  T.isNil(out.self)
end)

T.case("serialize: decode rejects garbage and non-table roots", function()
  T.isNil(serialize.decode("this is not lua"))
  T.isNil(serialize.decode("return 42"))
  T.isNil(serialize.decode("os.exit()"))
end)

T.case("serialize: decode cannot touch the environment", function()
  -- setfenv-sandboxed load: save data must never execute with stdlib access
  local out = serialize.decode('return { bad = (function() return os end) }')
  T.isTrue(out == nil or (type(out) == "table" and type(out.bad) == "function" and out.bad() == nil))
end)
