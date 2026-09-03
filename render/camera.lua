-- Camera: follow-lerp, world-bounds clamp, zoom, and 30 Hz decaying shake
-- punches accumulated via max (never summed). shakeScale 0 disables shake
-- entirely — the photosensitivity escape from 2d Trippy Hell camera.lua.
-- Adapted from Void Place render/camera.lua + Trippy game/systems/core/camera.lua.

local camera = {}

function camera.new(opts)
  opts = opts or {}
  local C = {
    x = opts.x or 0,
    y = opts.y or 0,
    zoom = opts.zoom or 1,
    minZoom = opts.minZoom or 0.5,
    maxZoom = opts.maxZoom or 4,
    bounds = opts.bounds,          -- {x, y, w, h} in world units, or nil
    followSpeed = opts.followSpeed or 8,
    shakeScale = 1,                -- wire settings gameplay.screenShake here
    shakeX = 0,
    shakeY = 0,
    viewW = opts.viewW or 1280,
    viewH = opts.viewH or 720,
    random = opts.random or function() return love and love.math and love.math.random() or 0.5 end,
  }
  local punch = nil                -- { strength, t, dur }
  local regenT = 1

  local function clampToBounds()
    local b = C.bounds
    if not b then return end
    local halfW, halfH = C.viewW / (2 * C.zoom), C.viewH / (2 * C.zoom)
    local lo, hi = b.x + halfW, b.x + b.w - halfW
    C.x = lo > hi and (b.x + b.w / 2) or math.min(math.max(C.x, lo), hi)
    lo, hi = b.y + halfH, b.y + b.h - halfH
    C.y = lo > hi and (b.y + b.h / 2) or math.min(math.max(C.y, lo), hi)
  end

  function C:setViewSize(w, h)
    C.viewW, C.viewH = w, h
    clampToBounds()
  end

  function C:setZoom(z)
    C.zoom = math.min(math.max(z, C.minZoom), C.maxZoom)
    clampToBounds()
  end

  function C:moveTo(x, y)
    C.x, C.y = x, y
    clampToBounds()
  end

  -- frame-rate independent exponential follow
  function C:follow(x, y, dt)
    local t = 1 - math.exp(-C.followSpeed * dt)
    C.x = C.x + (x - C.x) * t
    C.y = C.y + (y - C.y) * t
    clampToBounds()
  end

  -- stronger punch wins (max, not add); a longer duration only fills in when
  -- the current punch is the one that stays
  function C:shake(strength, duration)
    if C.shakeScale <= 0 then return end
    strength = strength * C.shakeScale
    duration = duration or 0.3
    if not punch or strength >= punch.strength then
      punch = { strength = strength, t = 0, dur = duration }
      regenT = 1 -- pick a fresh direction on the next update
    end
  end

  function C:update(dt)
    if punch then
      punch.t = punch.t + dt
      if punch.t >= punch.dur then
        punch = nil
        C.shakeX, C.shakeY = 0, 0
      else
        regenT = regenT + dt
        if regenT >= 1 / 30 then -- new direction at 30 Hz, not per frame
          regenT = 0
          local ang = C.random() * 2 * math.pi
          local k = punch.strength * (1 - punch.t / punch.dur)
          C.shakeX = math.cos(ang) * k
          C.shakeY = math.sin(ang) * k
        end
      end
    end
    clampToBounds()
  end

  -- world drawing happens between apply/pop (inside the viewport transform)
  function C:apply(vp)
    love.graphics.push()
    love.graphics.translate(vp.width / 2, vp.height / 2)
    love.graphics.scale(C.zoom, C.zoom)
    love.graphics.translate(-(C.x + C.shakeX), -(C.y + C.shakeY))
  end

  function C:pop() love.graphics.pop() end

  -- screen(logical)->world; the inverse of apply (mouse picking)
  function C:toWorld(lx, ly)
    return (lx - C.viewW / 2) / C.zoom + C.x + C.shakeX,
           (ly - C.viewH / 2) / C.zoom + C.y + C.shakeY
  end

  -- world-space view rect for culling
  function C:getView()
    local w, h = C.viewW / C.zoom, C.viewH / C.zoom
    return {
      x = C.x + C.shakeX - w / 2,
      y = C.y + C.shakeY - h / 2,
      w = w,
      h = h,
    }
  end

  return C
end

return camera
