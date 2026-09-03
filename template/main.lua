-- Template game entry. Lives at the game root, next to the Love2d Studio folder.
-- Conf lives at game root too (a conf inside the studio folder is inert).

local S = require("Love2d Studio")
local config = require("config")
local menu = require("scenes.menu")
local game = require("scenes.game")

function love.load(args)
  S.log.setLevel("info")
  local flags = S.boot.parse(args)

  if flags.test then
    -- your game's cases can live in mygame/tests/ and register the same way
    love.event.quit(S.tools.tests.runAll("tests") and 0 or 1)
    return
  end

  S.scene.register("menu", menu)
  S.scene.register("game", game)

  -- saves: sidecar-per-system with migrations when the schema grows
  S.game.save = S.save.new{ dir = config.saveDir, version = config.saveVersion }

  -- audio: families under the game's assets/sfx
  S.game.audio = S.audio.new{ dirs = { "assets/sfx" } }

  if flags.editor then
    S.scene.push("editor")
  else
    S.scene.push("menu")
  end
  S.assets.ready()
end

function love.update(dt) S.boot.frame(dt) end
function love.draw() S.scene.draw() end
function love.keypressed(k, s, r)
  S.boot.keypressed(k, s, r)
end
function love.mousepressed(x, y, b) S.boot.mousepressed(x, y, b) end
function love.mousereleased(x, y, b) S.boot.mousereleased(x, y, b) end
function love.mousemoved(x, y, dx, dy) S.boot.mousemoved(x, y, dx, dy) end
function love.wheelmoved(x, y) S.boot.wheelmoved(x, y) end
function love.resize(w, h) S.boot.resize(w, h) end
function love.focus(f) S.boot.focus(f) end
