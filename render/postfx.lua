-- Post-processing presets: off / low (vignette + chromatic aberration) /
-- high (+ half-res bloom). Every shader compile is pcall-wrapped and any
-- failure degrades to plain drawing (2d Trippy Hell convention); graphics
-- resets destroy shaders too, so invalidate() must run after setMode.

local postfx = {}

local PRESETS = {
  off  = { chroma = 0,      vig = 0,   bloom = false },
  low  = { chroma = 0.0035, vig = 0.55, bloom = false },
  high = { chroma = 0.006,  vig = 0.7,  bloom = true, threshold = 0.55, bloomStrength = 0.75 },
}

local MAIN = [[
uniform float chroma;
uniform float vig;
uniform float bloomStrength;
uniform Image bloomTex;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 dir = uv - 0.5;
  vec4 c;
  c.r = texture2D(tex, uv + dir * chroma).r;
  c.g = texture2D(tex, uv).g;
  c.b = texture2D(tex, uv - dir * chroma).b;
  c.a = 1.0;
  vec4 b = texture2D(bloomTex, uv);
  c.rgb += b.rgb * bloomStrength;
  float d = length(dir) * 1.4142;
  c.rgb *= mix(1.0, 1.0 - smoothstep(0.3, 0.8, d), vig);
  return c;
}
]]

local BRIGHT = [[
uniform float threshold;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv);
  float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  float k = max(0.0, l - threshold) / max(l, 0.0001);
  return vec4(c.rgb * k, 1.0);
}
]]

local BLUR = [[
uniform vec2 dir;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv) * 0.375;
  c += texture2D(tex, uv - dir) * 0.25;
  c += texture2D(tex, uv + dir) * 0.25;
  c += texture2D(tex, uv - dir * 2.0) * 0.0625;
  c += texture2D(tex, uv + dir * 2.0) * 0.0625;
  return c;
}
]]

local function tryShader(src)
  local ok, shader = pcall(love.graphics.newShader, src)
  if ok then return shader end
  return nil
end

function postfx.new()
  local P = {
    preset = "off",
    _main = nil, _bright = nil, _blur = nil, _tried = false,
    _a = nil, _b = nil, w = 0, h = 0,
  }

  function P:setPreset(name)
    assert(PRESETS[name], "unknown postfx preset: " .. tostring(name))
    self.preset = name
  end

  function P:current() return self.preset end

  -- after love.window.setMode: shaders and canvases are destroyed GPU-side
  function P:invalidate()
    self._main, self._bright, self._blur, self._tried = nil, nil, nil, false
    self:_releaseCanvases()
    self._reqW, self._reqH = nil, nil
  end

  function P:_releaseCanvases()
    for _, c in ipairs({ self._a, self._b }) do
      if c then pcall(c.release, c) end
    end
    self._a, self._b = nil, nil
    self.w, self.h = 0, 0
  end

  -- takes the full logical size; keeps half-res bloom buffers internally
  function P:resize(w, h)
    if self._reqW == w and self._reqH == h and self._a then return end
    self._reqW, self._reqH = w, h
    self:_releaseCanvases()
    if love and love.graphics then
      self.w, self.h = math.max(2, math.floor(w / 2)), math.max(2, math.floor(h / 2))
      self._a = love.graphics.newCanvas(self.w, self.h)
      self._b = love.graphics.newCanvas(self.w, self.h)
    end
  end

  function P:_ensureShaders()
    if self._tried then return end
    self._tried = true
    if not (love and love.graphics) then return end
    self._main = tryShader(MAIN)
    self._bright = tryShader(BRIGHT)
    self._blur = tryShader(BLUR)
  end

  -- draws `canvas` to the previously-set canvas (usually the screen) through
  -- the effect chain, inside the viewport
  function P:apply(canvas, vp)
    local cfg = PRESETS[self.preset]
    self:_ensureShaders()
    local prevCanvas = love.graphics.getCanvas()

    local bloomCanvas
    if self._main and cfg.bloom and self._bright and self._blur and self._a and self._b then
      local sx, sy = self.w / canvas:getWidth(), self.h / canvas:getHeight()
      love.graphics.setCanvas(self._a)
      love.graphics.clear()
      love.graphics.setShader(self._bright)
      self._bright:send("threshold", cfg.threshold)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(canvas, 0, 0, 0, sx, sy)
      love.graphics.setShader(self._blur)
      self._blur:send("dir", { 1.5 / self.w, 0 })
      love.graphics.setCanvas(self._b)
      love.graphics.clear()
      love.graphics.draw(self._a, 0, 0)
      self._blur:send("dir", { 0, 1.5 / self.h })
      love.graphics.setCanvas(self._a)
      love.graphics.clear()
      love.graphics.draw(self._b, 0, 0)
      love.graphics.setShader()
      bloomCanvas = self._a
    end

    if prevCanvas then love.graphics.setCanvas(prevCanvas) end
    if not self._main then
      vp:apply()
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(canvas, 0, 0)
      vp:pop()
      return
    end

    vp:apply()
    love.graphics.setShader(self._main)
    self._main:send("chroma", cfg.chroma)
    self._main:send("vig", cfg.vig)
    self._main:send("bloomStrength", bloomCanvas and cfg.bloomStrength or 0)
    self._main:send("bloomTex", bloomCanvas or canvas)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
    vp:pop()
  end

  return P
end

return postfx
