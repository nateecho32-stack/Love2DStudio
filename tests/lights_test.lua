local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local lights = R("render.light")

T.case("lights: add/remove/clear", function()
  local L = lights.new{}
  local a = L:add(0, 0, 100, 1, 1, 1)
  L:add(10, 0, 100, 1, 1, 1)
  T.eq(#L.items, 2)
  T.isTrue(L:remove(a))
  T.eq(#L.items, 1)
  L:clear()
  T.eq(#L.items, 0)
end)

T.case("lights: ttl lights expire on update", function()
  local L = lights.new{}
  L:add(0, 0, 100, 1, 1, 1, 1, 0.5)
  L:update(0.3)
  T.eq(#L.items, 1)
  L:update(0.3)
  T.eq(#L.items, 0)
end)

T.case("lights: permanent lights ignore ttl", function()
  local L = lights.new{}
  L:add(0, 0, 100, 1, 1, 1)
  for _ = 1, 10 do L:update(10) end
  T.eq(#L.items, 1)
end)

T.case("lights: draw runs without error when a canvas is set", function()
  if not (love and love.graphics) then return end
  local L = lights.new{}
  L:add(50, 50, 100, 1, 0.8, 0.5, 1, 0.4)
  local canvas = love.graphics.newCanvas(200, 200)
  love.graphics.setCanvas(canvas)
  L:draw()
  love.graphics.setCanvas()
  canvas:release()
  T.isTrue(true)
end)

T.case("lights: draw with no items is a no-op", function()
  local L = lights.new{}
  L:draw() -- must not require graphics when there is nothing to draw
  T.isTrue(true)
end)
