-- Minimal menu scene: the two-file footprint of a game (this + a registry line).

local S = require("Love2d Studio")

local scene = {}

function scene.enter() end
function scene.update(dt) end

function scene.draw()
  love.graphics.clear(0.08, 0.09, 0.11)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("MY GAME", 24, 24)
  love.graphics.print("press Enter to play, Esc to quit", 24, 48)
end

function scene.keypressed(key)
  if key == "return" or key == "space" then S.scene.replace("game") end
  if key == "escape" then love.event.quit() end
end

return scene
