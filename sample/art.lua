-- Gem Haul's frame art: the procedural shapes the scenes draw, baked into
-- ImageData frames. Shared by the runtime atlas bake (game.lua) and the asset
-- generator (tools/assetgen.lua) so the committed atlas and the fallback
-- shapes can never drift apart. Needs the LÖVE runtime.

local root = (...) and ((...):match("^(.-)sample%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local ARCHETYPES = R("sample.archetypes")

local art = {}

-- returns { name = ImageData } for every sprite frame (centered in square
-- cells with symmetric padding, which is what the atlas packer trims off)
function art.frames()
  local frames = {}
  local function bake(name, size, draw)
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    draw(size / 2, size / 2)
    love.graphics.setCanvas()
    frames[name] = canvas:newImageData()
    canvas:release()
  end
  bake("player_1", 32, function(cx, cy)
    love.graphics.setColor(0.95, 0.65, 0.25, 1)
    love.graphics.circle("fill", cx, cy, 13)
  end)
  bake("chaser_1", 28, function(cx, cy)
    love.graphics.setColor(0.85, 0.3, 0.4, 1)
    love.graphics.circle("fill", cx, cy, 12)
  end)
  bake("chaser_2", 28, function(cx, cy)
    love.graphics.setColor(0.85, 0.3, 0.4, 1)
    love.graphics.circle("fill", cx, cy, 12)
    love.graphics.setColor(0.62, 0.18, 0.28, 1)
    love.graphics.circle("fill", cx, cy, 7)
  end)
  local tint = ARCHETYPES.gem.tint
  for i, ring in ipairs({ 8, 6.5, 5, 6.5 }) do
    bake("gem_" .. i, 24, function(cx, cy)
      love.graphics.setColor(tint[1], tint[2], tint[3], 0.9)
      love.graphics.circle("fill", cx, cy, 9)
      love.graphics.setColor(1, 1, 1, 0.7)
      love.graphics.circle("line", cx, cy, ring)
    end)
  end
  return frames
end

return art
