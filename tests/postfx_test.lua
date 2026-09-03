local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local postfx = R("render.postfx")

T.case("postfx: presets validate", function()
  local fx = postfx.new()
  fx:setPreset("low")
  T.eq(fx:current(), "low")
  T.fails(function() fx:setPreset("ultra") end)
end)

T.case("postfx: resize creates half-res buffers once per size", function()
  if not (love and love.graphics) then return end
  local fx = postfx.new()
  fx:resize(200, 100)
  T.eq(fx.w, 100)
  T.eq(fx.h, 50)
  local a = fx._a
  fx:resize(200, 100) -- same size: no recreation
  T.eq(fx._a, a)
  fx:resize(400, 200)
  T.isTrue(fx._a ~= a)
  fx:_releaseCanvases()
end)

T.case("postfx: invalidate clears shaders and canvases", function()
  if not (love and love.graphics) then return end
  local fx = postfx.new()
  fx:setPreset("high")
  fx:resize(100, 100)
  fx:_ensureShaders()
  fx:invalidate()
  T.isNil(fx._main)
  T.isNil(fx._a)
  T.eq(fx._tried, false) -- shaders will be re-tried after the reset
end)

T.case("postfx: apply runs off/low/high without error", function()
  if not (love and love.graphics) then return end
  local viewport = R("render.viewport")
  local vp = viewport.new{ width = 64, height = 64 }
  vp:resize(64, 64)
  local scene = love.graphics.newCanvas(64, 64)
  local target = love.graphics.newCanvas(64, 64)
  love.graphics.setCanvas(scene)
  love.graphics.clear(0.2, 0.4, 0.6, 1)
  love.graphics.setCanvas()
  for _, name in ipairs({ "off", "low", "high" }) do
    local fx = postfx.new()
    fx:setPreset(name)
    fx:resize(64, 64)
    local ok = pcall(function()
      love.graphics.setCanvas(target)
      love.graphics.clear(0, 0, 0, 1)
      fx:apply(scene, vp) -- draws scene into the currently-set target
      love.graphics.setCanvas()
    end)
    T.isTrue(ok, "postfx " .. name .. " apply raised")
  end
  scene:release()
  target:release()
end)
