local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local pipeline = R("render.pipeline")
local viewport = R("render.viewport")
local camera = R("render.camera")

local function makeSetup()
  local vp = viewport.new{ width = 64, height = 64 }
  vp:resize(64, 64)
  local cam = camera.new{ x = 0, y = 0 }
  cam:setViewSize(64, 64)
  local calls = {}
  local p = pipeline.new{
    viewport = vp,
    camera = cam,
    -- no lights, no postfx: pure canvas path
  }
  return p, calls
end

T.case("pipeline: layers draw in order; add/remove works", function()
  local p, calls = makeSetup()
  p:addLayer("b", function() calls[#calls + 1] = "b" end, 5)
  p:addLayer("a", function() calls[#calls + 1] = "a" end, 1)
  p:addLayer("c", function() calls[#calls + 1] = "c" end, 9)
  p:removeLayer("c")
  if not (love and love.graphics) then return end
  p:draw()
  T.eq(calls, { "a", "b" })
  T.eq(p:layerNames(), { "a", "b" })
end)

T.case("pipeline: draw end-to-end on canvases", function()
  if not (love and love.graphics) then return end
  local p, calls = makeSetup()
  p:addLayer("world", function() calls[#calls + 1] = "world" end)
  p:addHud("hud", function() calls[#calls + 1] = "hud" end)
  -- redirect the screen stages into a canvas so no real screen is touched
  local target = love.graphics.newCanvas(64, 64)
  local ok = pcall(function()
    love.graphics.setCanvas(target)
    p:draw()
    love.graphics.setCanvas()
  end)
  T.isTrue(ok, "pipeline draw raised")
  -- world draws inside the camera stage, hud in the postfx/screen stage
  T.eq(calls, { "world", "hud" })
  target:release()
end)

T.case("pipeline: resize recreates canvases", function()
  if not (love and love.graphics) then return end
  local p = makeSetup()
  local first = p:canvases()
  p:onResize()
  local second = p:canvases()
  T.isTrue(first.world ~= second.world)
  T.isTrue(first.world ~= nil)
  second.world:release()
end)

T.case("pipeline: duplicate layer names replace instead of stack", function()
  local p, calls = makeSetup()
  p:addLayer("x", function() calls[#calls + 1] = "one" end)
  p:addLayer("x", function() calls[#calls + 1] = "two" end)
  if not (love and love.graphics) then return end
  p:draw()
  T.eq(calls, { "two" })
end)
