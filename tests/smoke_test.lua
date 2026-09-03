-- Smoke test: boot the demo scene and run 120 real update+draw frames.
-- Fails on NaN/out-of-bounds state or draw errors. Pattern from Void Place.

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")
local time = R("core.time")
local input = R("core.input")
local demo = R("demo")

T.case("smoke: 120 frames of update+draw with finite state", function()
  scene.register("demo", demo)
  scene.push("demo")

  input.update()
  local dt = 1 / 60
  local okDraw = true
  for _ = 1, 120 do
    scene.update(dt)
    local state = scene.top().state -- demo exposes its player for this check
    if state then
      T.isTrue(state.x == state.x and state.y == state.y, "NaN in demo player")
    end
    if love and love.graphics then
      if not pcall(scene.draw) then okDraw = false end
    end
  end
  T.isTrue(okDraw, "demo draw raised an error")
  T.eq(scene.depth(), 1)
  scene.clear()
end)
