-- Minimal gameplay scene: render stack + a player square + autosave scaffold.

local S = require("Love2d Studio")
local config = require("config")

local scene = {}
local R, player

function scene.enter()
  R = S.render.new{ width = 1280, height = 720 }
  player = { x = 640, y = 360 }
  R.pipeline:addLayer("world", function()
    love.graphics.setColor(0.95, 0.65, 0.25)
    love.graphics.rectangle("fill", player.x - 14, player.y - 14, 28, 28)
  end, 0)
  S.input.define({
    left  = { keys = { "left", "a" } },
    right = { keys = { "right", "d" } },
    up    = { keys = { "up", "w" } },
    down  = { keys = { "down", "s" } },
  })
  R:resize(love.graphics.getDimensions())
end

function scene.update(dt)
  local vx = (S.input.down("right") and 1 or 0) - (S.input.down("left") and 1 or 0)
  local vy = (S.input.down("down") and 1 or 0) - (S.input.down("up") and 1 or 0)
  player.x = player.x + vx * config.player.speed * dt
  player.y = player.y + vy * config.player.speed * dt
end

function scene.draw()
  R.pipeline:draw()
end

function scene.keypressed(key)
  if key == "escape" then S.scene.replace("menu") end
end

function scene.resize(w, h)
  R:resize(w, h)
end

return scene
