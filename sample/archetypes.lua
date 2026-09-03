-- Gem Haul archetypes: editor-authorable content. Schemas drive the editor
-- inspector; physics/trigger metadata is consumed by sample/game.lua; tint +
-- size drive both the editor view and the runtime's procedural sprites.

return {
  player_spawn = {
    label = "Player Spawn",
    size = { w = 24, h = 24 },
    tint = { 0.95, 0.65, 0.25 },
    schema = {},
  },
  wall = {
    label = "Wall",
    size = { w = 48, h = 48 },
    tint = { 0.35, 0.38, 0.45 },
    schema = {},
  },
  gem = {
    label = "Gem",
    size = { w = 18, h = 18 },
    tint = { 0.4, 0.9, 1 },
    schema = {
      tier = { type = "enum", default = "common", values = { "common", "rare", "epic" } },
    },
  },
  spike = {
    label = "Spike",
    size = { w = 22, h = 22 },
    tint = { 0.9, 0.3, 0.35 },
    schema = {},
  },
  exit_zone = {
    label = "Exit Zone",
    size = { w = 48, h = 48 },
    tint = { 0.5, 1, 0.55 },
    schema = {
      gemsRequired = { type = "number", default = 3, min = 1, max = 99, },
    },
  },
}
