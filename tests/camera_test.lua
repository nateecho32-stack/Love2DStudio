local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local camera = R("render.camera")

local function makeCamera(opts)
  opts = opts or {}
  opts.random = function() return 0.25 end -- deterministic shake directions
  return camera.new(opts)
end

T.case("camera: follow approaches the target", function()
  local c = makeCamera{ x = 0, y = 0, followSpeed = 8 }
  c:setViewSize(100, 100)
  for _ = 1, 60 do c:follow(100, 0, 1 / 60) end
  T.isTrue(math.abs(c.x - 100) < 1)
  T.near(c.y, 0)
end)

T.case("camera: bounds clamp keeps the view inside", function()
  local c = makeCamera{ x = 0, y = 0, bounds = { x = 0, y = 0, w = 200, h = 200 } }
  c:setViewSize(100, 100)
  c:moveTo(-500, 500)
  T.near(c.x, 50)  -- half of the 100-wide view
  T.near(c.y, 150)
end)

T.case("camera: bounds smaller than the view center on the bounds", function()
  local c = makeCamera{ x = 0, y = 0, bounds = { x = 0, y = 0, w = 50, h = 50 } }
  c:setViewSize(100, 100)
  c:moveTo(500, 500)
  T.near(c.x, 25)
  T.near(c.y, 25)
end)

T.case("camera: setZoom clamps and re-clamps position", function()
  local c = makeCamera{ x = 0, y = 0, bounds = { x = 0, y = 0, w = 100, h = 100 }, minZoom = 0.5, maxZoom = 4 }
  c:setViewSize(100, 100)
  c:setZoom(10)
  T.near(c.zoom, 4)
  c:setZoom(0.1)
  T.near(c.zoom, 0.5)
end)

T.case("camera: toWorld inverts the apply transform", function()
  local c = makeCamera{ x = 42, y = -17, zoom = 1.5 }
  c:setViewSize(200, 100)
  -- a point at the logical center maps to the camera position
  local wx, wy = c:toWorld(100, 50)
  T.near(wx, 42)
  T.near(wy, -17)
  local wx2, wy2 = c:toWorld(150, 75)
  T.near(wx2, 42 + 50 / 1.5)
  T.near(wy2, -17 + 25 / 1.5)
end)

T.case("camera: getView describes the visible world rect", function()
  local c = makeCamera{ x = 10, y = 20, zoom = 2 }
  c:setViewSize(100, 50)
  local v = c:getView()
  T.near(v.w, 50)
  T.near(v.h, 25)
  T.near(v.x, -15)
  T.near(v.y, 7.5)
end)

T.case("camera: shake accumulates via max and decays to zero", function()
  local c = makeCamera{ x = 0, y = 0 }
  c:setViewSize(100, 100)
  c:shake(5, 0.1)
  c:shake(3, 5) -- weaker/longer punch must NOT extend the strong one
  c:update(1 / 60)
  T.isTrue(c.shakeX ~= 0 or c.shakeY ~= 0)
  for _ = 1, 30 do c:update(1 / 60) end -- 0.5s: the 0.1s punch is long gone
  T.near(c.shakeX, 0)
  T.near(c.shakeY, 0)
end)

T.case("camera: shakeScale 0 is the photosensitivity escape", function()
  local c = makeCamera{ x = 0, y = 0 }
  c:setViewSize(100, 100)
  c.shakeScale = 0
  c:shake(10, 1)
  c:update(1 / 60)
  T.near(c.shakeX, 0)
  T.near(c.shakeY, 0)
end)
