-- Sprite runtime: the missing playback half of the asset pipeline. Consumes
-- atlas_pack layouts (or hand-authored ones with the same shape), builds
-- quads, draws frames with trim-offset anchoring, and plays clips.
-- Nil-return contract: sprites.get(key) -> nil means "draw procedurally".

local sprites = {}

-- opts: { layout = { key = {x,y,w,h,ox,oy} }, image = Image, defaultAnchor = {"center","feet"} }
function sprites.new(opts)
  opts = opts or {}
  local S = {
    layout = opts.layout or {},
    image = opts.image,
    _quads = {},
    clips = opts.clips or {},   -- name -> {frames = {key...}, fps = 10, loop = true}
  }

  function S:setImage(image) S.image = image S._quads = {} end

  function S:get(key)
    local frame = S.layout[key]
    if not frame or not S.image then return nil end
    local quad = S._quads[key]
    if not quad then
      quad = love.graphics.newQuad(
        frame.x, frame.y, frame.w, frame.h,
        S.image:getWidth(), S.image:getHeight())
      S._quads[key] = quad
    end
    return { quad = quad, frame = frame }
  end

  -- anchor restores pre-trim alignment: "feet" = bottom-center of the ORIGINAL
  -- cell, "center" = cell center. ox/oy are the trim offsets recorded by the packer.
  function S:draw(key, x, y, rot, sx, sy)
    local sprite = S:get(key)
    if not sprite then return false end
    local f = sprite.frame
    sx, sy = sx or 1, sy or 1
    local ox, oy = f.ox or 0, f.oy or 0
    local anchorX = f.w / 2 + ox
    local anchorY = f.h + oy -- feet anchor by default (characters stand on y)
    love.graphics.draw(S.image, sprite.quad, x, y, rot or 0, sx, sy, anchorX, anchorY)
    return true
  end

  function S:registerClip(name, clip)
    clip.fps = clip.fps or 10
    clip.loop = clip.loop ~= false
    S.clips[name] = clip
    return clip
  end

  return S
end

-- Animator: drives clip playback; draw() falls back to fn(x, y, t) when the
-- clip is missing (procedural fallback stays first-class).
function sprites.animator(S)
  local A = {
    clip = nil,
    t = 0,
    fallback = nil, -- function(x, y, t) drawn when no clip/sprite
  }

  function A:play(name, restart)
    if self.clip == name and not restart then return end
    self.clip = name
    self.t = 0
  end

  function A:update(dt) self.t = self.t + dt end

  function A:frame()
    local clip = S.clips[self.clip]
    if not clip or #clip.frames == 0 then return nil end
    local index = math.floor(self.t * clip.fps) + 1
    if clip.loop then
      index = (index - 1) % #clip.frames + 1
    else
      index = math.min(index, #clip.frames)
    end
    return clip.frames[index]
  end

  function A:done()
    local clip = S.clips[self.clip]
    if not clip or clip.loop then return false end
    return self.t * clip.fps >= #clip.frames
  end

  function A:draw(x, y, rot, sx, sy)
    local frameKey = self:frame()
    if frameKey and S:draw(frameKey, x, y, rot, sx, sy) then return true end
    if self.fallback then self.fallback(x, y, self.t) return true end
    return false
  end

  return A
end

-- Minimal animation state machine: states = { name = {clip=, speed=1,
-- next="statename" (auto-advance when the clip ends), onEnter=fn} }
function sprites.stateMachine(animator)
  local M = { current = nil, states = {} }

  function M:add(name, state)
    state.speed = state.speed or 1
    M.states[name] = state
    return state
  end

  function M:set(name)
    if M.current == name then return end
    M.current = name
    local state = M.states[name]
    animator:play(state and state.clip or name, true)
    if state and state.onEnter then state.onEnter() end
  end

  function M:update(dt)
    local state = M.states[M.current]
    animator:update(dt * ((state and state.speed) or 1))
    if state and state.next and animator:done() then
      M:set(state.next)
    end
  end

  return M
end

return sprites
