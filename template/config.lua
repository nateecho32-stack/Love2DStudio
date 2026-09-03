-- Every tuning number in the game. Nothing else should hold a magic
-- constant, and each number carries its design rationale (Void Place rule).

return {
  saveDir = "saves/slot1",
  saveVersion = 1,
  scenePath = "scenes/sandbox.lua",  -- the file the editor opens/saves

  player = {
    speed = 240,        -- px/s: crosses the screen in ~5s at 1280 wide
    jumpPower = 520,    -- tuned so a full jump clears 3 tiles of 32px
  },

  escalation = {
    -- spawn interval compresses with depth; the floor keeps early areas calm
    spawnBase = 10,
    spawnFloor = 3.5,
  },
}
