-- Shader library: per-entity effects, all pcall-wrapped with graceful
-- degradation to plain drawing (the 2d Trippy Hell convention — a failed
-- compile must never crash a game).

local root = (...) and ((...):match("^(.-)render%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end

local library = {}

local SOURCES = {
  hitflash = [[
uniform float u_amount;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv);
  float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  return vec4(mix(c.rgb, vec3(1.0, l * 0.7, l * 0.7), u_amount), c.a);
}
]],
  grayscale = [[
uniform float u_amount;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv);
  float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  return vec4(mix(c.rgb, vec3(l, l, l), u_amount), c.a);
}
]],
  dissolve = [[
uniform float u_amount; // 0 = intact, 1 = fully gone
uniform float u_seed;
float hash(vec2 p) {
  return fract(sin(dot(p + u_seed, vec2(127.1, 311.7))) * 43758.5453);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv);
  float n = hash(uv * 40.0);
  if (n < u_amount) discard;
  float edge = smoothstep(u_amount, u_amount + 0.08, n);
  vec3 tint = mix(vec3(1.0, 0.5, 0.1), c.rgb, edge);
  return vec4(tint, c.a * edge);
}
]],
  water = [[
uniform float u_time;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec2 w = uv;
  w.x += sin(uv.y * 12.0 + u_time * 2.0) * 0.006;
  w.y += cos(uv.x * 10.0 + u_time * 1.6) * 0.004;
  vec4 c = texture2D(tex, w);
  c.rgb *= 0.92 + 0.08 * sin(u_time * 3.0 + uv.y * 20.0);
  return c;
}
]],
}

-- outline works on the SHAPE (alpha mask), drawn as a second pass
local OUTLINE = [[
uniform vec4 u_color;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = texture2D(tex, uv);
  float a = texture2D(tex, uv + vec2(0.0, -0.004)).a
          + texture2D(tex, uv + vec2(0.0,  0.004)).a
          + texture2D(tex, uv + vec2(-0.004, 0.0)).a
          + texture2D(tex, uv + vec2( 0.004, 0.0)).a;
  if (c.a > 0.5) return c;
  if (a > 0.1) return u_color;
  return vec4(0.0);
}
]]

local function tryCompile(src)
  if not (love and love.graphics) then return nil end
  local ok, shader = pcall(love.graphics.newShader, src)
  return ok and shader or nil
end

function library.new()
  local L = { _shaders = {}, _failed = {} }

  function L:get(name)
    if self._shaders[name] ~= nil then return self._shaders[name] end
    local src = name == "outline" and OUTLINE or SOURCES[name]
    if not src then return nil end
    local shader = tryCompile(src)
    self._shaders[name] = shader or false -- false caches the failure
    return shader
  end

  -- draw `drawable` with a uniform-driven effect applied
  -- opts: { amount =, time =, color = {r,g,b,a}, drawArgs = {...} }
  function L:draw(name, drawable, opts)
    opts = opts or {}
    local shader = self:get(name)
    if not shader then
      love.graphics.draw(drawable, unpack(opts.drawArgs or {}))
      return false
    end
    love.graphics.setShader(shader)
    if shader:hasUniform("u_amount") then shader:send("u_amount", opts.amount or 0.5) end
    if shader:hasUniform("u_time") then shader:send("u_time", opts.time or 0) end
    if shader:hasUniform("u_seed") then shader:send("u_seed", opts.seed or 0) end
    if shader:hasUniform("u_color") then
      local c = opts.color or { 1, 0.6, 0.1, 1 }
      shader:send("u_color", c[1], c[2], c[3], c[4] or 1)
    end
    love.graphics.draw(drawable, unpack(opts.drawArgs or {}))
    love.graphics.setShader()
    return true
  end

  -- convenience: hit-flash amount driven by a 0..1 timer
  function L:hitFlash(drawable, k, drawArgs)
    return self:draw("hitflash", drawable, { amount = k, drawArgs = drawArgs })
  end

  return L
end

return library
