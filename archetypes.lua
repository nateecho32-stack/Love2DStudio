-- Demo archetypes: the content contract shared by the editor, play mode, and
-- the runtime spawner. Schemas drive editor inspector fields; draw() is the
-- procedural fallback (no assets needed). Every archetype carries the `name`
-- string prop (the inspector's entity name field) so validate keeps it into
-- gameplay instead of dropping it.

local NAME = { type = "string", default = "" }

return {
  block = {
    label = "Block",
    size = { w = 48, h = 48 },
    tint = { 0.35, 0.38, 0.45 },
    schema = {
      name = NAME,
      hp = { type = "number", default = 20, min = 1, max = 200 },
      variant = { type = "enum", default = "stone", values = { "stone", "wood", "metal" } },
    },
  },
  torch = {
    label = "Torch",
    size = { w = 16, h = 24 },
    tint = { 1, 0.7, 0.3 },
    schema = {
      name = NAME,
      radius = { type = "number", default = 140, min = 40, max = 400 },
      color = { type = "enum", default = "warm", values = { "warm", "cold", "green" } },
    },
  },
  goblin = {
    label = "Goblin",
    size = { w = 22, h = 26 },
    tint = { 0.4, 0.75, 0.35 },
    schema = {
      name = NAME,
      hp = { type = "number", default = 12, min = 1, max = 60 },
      speed = { type = "number", default = 40, min = 0, max = 200 },
      elite = { type = "boolean", default = false },
    },
  },
  player_spawn = {
    label = "Player Spawn",
    size = { w = 24, h = 24 },
    tint = { 0.95, 0.65, 0.25 },
    schema = { name = NAME },
  },
}
