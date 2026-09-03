-- Integration: the full render stack (facade + pipeline + particles + lights
-- + postfx) draws three frames into a target canvas, then survives resize
-- and a simulated graphics reset.

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local render = R("render.init")

T.case("render: full stack draws and survives resize + graphics reset", function()
  if not (love and love.graphics) then return end
  local R = render.new{
    width = 64, height = 64,
    postfx = "high",
    lighting = true,
    bounds = { x = -100, y = -100, w = 200, h = 200 },
  }
  R.pipeline:addLayer("world", function()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", -8, -8, 16, 16)
  end, 0)
  R.pipeline:addLayer("particles", function() R.particles:draw() end, 5)
  R.particles:registerPreset("spark", {
    count = 5, life = 1, speed = { 0, 10 }, size = 4,
    colors = { { 1, 0.7, 0.3 } },
  })

  local target = love.graphics.newCanvas(64, 64)
  local ok, err = pcall(function()
    R.particles:emit("spark", 0, 0)
    R.camera:follow(5, 0, 1 / 60)
    R.camera:update(1 / 60)
    for _ = 1, 3 do
      love.graphics.setCanvas(target)
      R.pipeline:draw()
      love.graphics.setCanvas()
      R.particles:update(1 / 60)
      R.lights:update(1 / 60)
      R.camera:update(1 / 60)
    end
    R:resize(128, 128)
    R.pipeline:draw()
    R:onGraphicsReset()
    R.pipeline:draw()
  end)
  T.isTrue(ok, "render stack raised: " .. tostring(err))
  target:release()
end)

T.case("render: camera toWorld matches viewport mouse picking", function()
  local R = render.new{ width = 100, height = 100 }
  R.camera:moveTo(25, 50)
  -- logical center of the viewport maps to the camera position
  local wx, wy = R.camera:toWorld(50, 50)
  T.near(wx, 25)
  T.near(wy, 50)
end)
