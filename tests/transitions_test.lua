local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")
local transitions = R("core.transitions")

transitions.wire(scene)

local function countingScene(tag, log)
  return {
    enter = function() log[#log + 1] = tag .. ".enter" end,
    exit = function() log[#log + 1] = tag .. ".exit" end,
    update = function(dt) log[#log + 1] = tag .. ".update" end,
    draw = function()
      log[#log + 1] = tag .. ".draw"
      if love and love.graphics then love.graphics.setColor(1, 1, 1) end
    end,
  }
end

T.case("transitions: replace swaps scenes under a fading overlay", function()
  scene.clear()
  local log = {}
  scene.register("a", countingScene("a", log))
  scene.register("b", countingScene("b", log))
  scene.push("a")
  scene.update(0.016)

  transitions.replace("b", nil, { kind = "fade", dur = 0.3 })
  T.eq(scene.topName(), "__transition")
  T.isTrue(transitions.active())

  for _ = 1, 20 do scene.update(1 / 60) end -- 0.33s > 0.3s duration
  T.isTrue(not transitions.active())
  T.eq(scene.topName(), "b")
  scene.clear()
end)

T.case("transitions: push keeps the old scene under the overlay", function()
  scene.clear()
  local log = {}
  scene.register("a", countingScene("a", log))
  scene.register("b", countingScene("b", log))
  scene.push("a")
  transitions.push("b", nil, { kind = "fade", dur = 0.2 })
  T.eq(scene.depth(), 3) -- a + b + overlay
  for _ = 1, 15 do scene.update(1 / 60) end
  T.eq(scene.depth(), 2) -- overlay popped; a still beneath b
  T.eq(scene.topName(), "b")
  scene.clear()
end)

T.case("transitions: draw runs through the whole transition without error", function()
  if not (love and love.graphics) then return end
  scene.clear()
  scene.register("a", countingScene("a", {}))
  scene.register("b", countingScene("b", {}))
  scene.push("a")
  transitions.push("b", nil, { kind = "cross", dur = 0.2 })
  local ok = true
  for _ = 1, 20 do
    scene.update(1 / 60)
    if not pcall(scene.draw) then ok = false end
  end
  T.isTrue(ok, "transition draw raised")
  scene.clear()
end)
