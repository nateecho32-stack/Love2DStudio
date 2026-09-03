local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local ecs = R("core.ecs")
local entities = R("core.entities")

local function makeWorld()
  local E = entities.new{ ecs = ecs.new() }
  E:define("goblin", {
    schema = {
      hp = { type = "number", default = 10, min = 1, max = 100 },
      name = { type = "string", default = "gob" },
      elite = { type = "boolean", default = false },
      tier = { type = "enum", default = "grunt", values = { "grunt", "brute" } },
    },
    size = { w = 20, h = 28 },
    components = { hp = function(_, props) return { current = props.hp, max = props.hp } end },
  })
  return E
end

T.case("entities: spawn fills defaults and attaches components", function()
  local E = makeWorld()
  local id = E:spawn("goblin", 10, 20)
  T.eq(E.ecs:get(id, "transform"), { x = 10, y = 20, rot = 0, scale = 1 })
  local arch = E.ecs:get(id, "archetype")
  T.eq(arch.id, "goblin")
  T.eq(arch.props, { hp = 10, name = "gob", elite = false, tier = "grunt" })
  T.eq(E.ecs:get(id, "hp"), { current = 10, max = 10 })
end)

T.case("entities: props validate — clamp, coerce, enum, unknown dropped", function()
  local E = makeWorld()
  local props = E:validate("goblin", {
    hp = 500,           -- clamped to max 100
    tier = "boss",      -- not in enum -> default
    name = 42,          -- coerced to string
    secret = "nope",    -- unknown prop dropped
  })
  T.eq(props, { hp = 100, name = "42", elite = false, tier = "grunt" })
end)

T.case("entities: unknown archetype refuses to spawn", function()
  local E = makeWorld()
  local id, err = E:spawn("dragon", 0, 0)
  T.isNil(id)
  T.isTrue(tostring(err):find("dragon", 1, true) ~= nil)
end)

T.case("entities: serialize/deserialize round-trips through scene data", function()
  local E = makeWorld()
  E:spawn("goblin", 5, 6, { hp = 50, elite = true })
  E:spawn("goblin", 7, 8)
  local data = E:serializeAll()
  T.eq(#data, 2)
  T.eq(data[1], { type = "goblin", x = 5, y = 6, props = { hp = 50, name = "gob", elite = true, tier = "grunt" } })

  local E2 = entities.new{ ecs = ecs.new() }
  E2:define("goblin", {
    schema = {
      hp = { type = "number", default = 10, min = 1, max = 100 },
      name = { type = "string", default = "gob" },
      elite = { type = "boolean", default = false },
      tier = { type = "enum", default = "grunt", values = { "grunt", "brute" } },
    },
  })
  E2:deserialize(data)
  T.eq(E2.ecs:alive(), 2)
end)

T.case("entities: schema feeds the editor inspector", function()
  local E = makeWorld()
  local schema = E:schema("goblin")
  T.isTrue(schema.hp.min == 1 and schema.hp.max == 100)
  T.eq(schema.tier.values, { "grunt", "brute" })
  local ids = E:archetypeIds()
  T.eq(ids, { "goblin" })
end)
