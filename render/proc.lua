-- Procedural texture painters + dirty-flag canvas cache: the "ship with zero
-- binary assets" fallback kit. Glow painter from Void Place render/particles.lua
-- (lazy radial gradient); dirty-flag canvas from Vimur src/plant/renderer.lua.

local M = { _pixel = nil, _glow = {} }

-- white radial glow: alpha = (1 - d)^falloff. The one shared texture that
-- particles and lights tint at draw time.
function M.glowImage(size, falloff)
  size = size or 32
  falloff = falloff or 2
  local cache = M._glow
  local key = size .. ":" .. falloff
  if cache[key] then return cache[key] end
  local data = love.image.newImageData(size, size)
  local c = (size - 1) / 2
  data:mapPixel(function(x, y)
    local dx, dy = (x - c) / c, (y - c) / c
    local d = math.sqrt(dx * dx + dy * dy)
    if d >= 1 then return 255, 255, 255, 0 end
    local a = (1 - d) ^ falloff
    return 255, 255, 255, math.floor(a * 255 + 0.5)
  end)
  local img = love.graphics.newImage(data)
  cache[key] = img
  return img
end

-- flat white disc with a soft 1px edge
function M.discImage(size)
  size = size or 16
  local key = "disc" .. size
  if M._glow[key] then return M._glow[key] end
  local data = love.image.newImageData(size, size)
  local c = (size - 1) / 2
  data:mapPixel(function(x, y)
    local dx, dy = (x - c) / c, (y - c) / c
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 1 then return 255, 255, 255, 0 end
    local a = math.min(1, (1 - d) * size / 2) -- hairline AA at the rim
    return 255, 255, 255, math.floor(a * 255 + 0.5)
  end)
  local img = love.graphics.newImage(data)
  M._glow[key] = img
  return img
end

-- 1x1 white pixel for tinted rectangles
function M.pixelImage()
  if M._pixel then return M._pixel end
  local data = love.image.newImageData(1, 1)
  data:setPixel(0, 0, 255, 255, 255, 255)
  M._pixel = love.graphics.newImage(data)
  return M._pixel
end

-- Dirty-flag canvas: expensive draw runs once, then every frame just reuses
-- the canvas until invalidate(). Scissor is saved/restored so offscreen
-- rendering never leaks state (Vimur gotcha).
function M.cachedCanvas(w, h, drawFn)
  local C = { w = w, h = h }
  local canvas = nil

  function C:invalidate()
    if canvas then canvas:release() canvas = nil end
  end

  function C:get()
    if not canvas then
      canvas = love.graphics.newCanvas(w, h)
      love.graphics.setCanvas(canvas)
      local sx, sy, sw, sh = love.graphics.getScissor()
      love.graphics.setScissor()
      drawFn(canvas)
      if sx then
        love.graphics.setScissor(sx, sy, sw, sh)
      end
      love.graphics.setCanvas()
    end
    return canvas
  end

  return C
end

return M
