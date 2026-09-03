local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")

local function makeScene(tag, log)
  return {
    enter = function() log[#log + 1] = tag .. ".enter" end,
    pause = function() log[#log + 1] = tag .. ".pause" end,
    resume = function() log[#log + 1] = tag .. ".resume" end,
    exit = function() log[#log + 1] = tag .. ".exit" end,
    update = function(dt) log[#log + 1] = tag .. ".update" end,
    draw = function() log[#log + 1] = tag .. ".draw" end,
    keypressed = function(key) log[#log + 1] = tag .. ".key:" .. key end,
    resize = function(w, h) log[#log + 1] = tag .. ".resize" end,
  }
end

T.case("scene: push/enter/pause lifecycle", function()
  local log = {}
  scene.register("a", makeScene("a", log))
  scene.register("b", makeScene("b", log))
  scene.push("a")
  scene.push("b")
  T.eq(log, { "a.enter", "a.pause", "b.enter" })
  T.eq(scene.topName(), "b")
  scene.clear()
end)

T.case("scene: pop exits and resumes below", function()
  local log = {}
  scene.register("a", makeScene("a", log))
  scene.register("b", makeScene("b", log))
  scene.push("a")
  scene.push("b")
  scene.pop()
  T.eq(log, { "a.enter", "a.pause", "b.enter", "b.exit", "a.resume" })
  scene.clear()
end)

T.case("scene: replace skips pause/resume", function()
  local log = {}
  scene.register("a", makeScene("a", log))
  scene.register("b", makeScene("b", log))
  scene.push("a")
  scene.replace("b")
  T.eq(log, { "a.enter", "a.exit", "b.enter" })
  scene.clear()
end)

T.case("scene: draw renders whole stack bottom-up (modal overlay)", function()
  local log = {}
  scene.register("a", makeScene("a", log))
  scene.register("overlay", makeScene("overlay", log))
  scene.push("a")
  scene.push("overlay") -- pushing logs a.pause on the scene below
  scene.draw()
  T.eq(log, { "a.enter", "a.pause", "overlay.enter", "a.draw", "overlay.draw" })
  scene.clear()
end)

T.case("scene: update and keypressed go to top only; resize broadcasts", function()
  local log = {}
  scene.register("a", makeScene("a", log))
  scene.register("b", makeScene("b", log))
  scene.push("a")
  scene.push("b")
  scene.update(0.016)
  scene.keypressed("space")
  scene.resize(100, 100)
  local expected = { "a.enter", "a.pause", "b.enter", "b.update", "b.key:space", "a.resize", "b.resize" }
  T.eq(log, expected)
  scene.clear()
end)

T.case("scene: push unknown name raises", function()
  T.fails(function() scene.push("nope_nope") end)
end)

T.case("scene: lifecycle methods are optional", function()
  scene.register("bare", {})
  scene.push("bare")
  scene.update(0.016)
  scene.draw()
  scene.pop()
  T.isTrue(true)
end)
