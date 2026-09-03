local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local boot = R("core.boot")
local scene = R("core.scene")
local events = R("core.events")
local time = R("core.time")
local input = R("core.input")
local assets = R("core.assets")
local log = R("core.log")
local capture = R("tools.capture")

local function makeStudio()
  local S = {
    log = log, bus = events.new(), scene = scene, time = time,
    input = input, assets = assets,
  }
  boot.wire(S)
  return S
end

T.case("boot: parse recognizes flags and their values", function()
  local flags = boot.parse({ "--test", "--shot", "menu", "--skipintro", "--audit" })
  T.isTrue(flags.test)
  T.eq(flags.shot, "menu")
  T.isTrue(flags.skipintro)
  T.isTrue(flags.audit)
  T.eq(boot.parse({}), {})
end)

T.case("boot: run registers scenes and pushes the first", function()
  scene.clear()
  makeStudio()
  local enteredWith = nil
  local home = { enter = function(a) enteredWith = a end } -- callbacks receive args directly (no self)
  boot.run({ scenes = { home = home }, first = "home", args = {} })

  T.eq(scene.topName(), "home")
  T.isTrue(enteredWith ~= nil and enteredWith.flags ~= nil)
  scene.clear()
end)

T.case("boot: run with --shot pushes the shot scene instead of first", function()
  scene.clear()
  makeStudio()
  local menuEntered = false
  boot.run({
    scenes = {
      home = {},
      menu = { enter = function() menuEntered = true end },
    },
    first = "home",
    args = { "--shot", "menu" },
  })
  T.eq(scene.topName(), "menu")
  T.isTrue(menuEntered)
  scene.clear()
end)

T.case("boot: frame pipeline updates input edges, then scene via time", function()
  scene.clear()
  capture.active = false -- cancel any leftover capture override from shot tests
  capture.quitting = false
  makeStudio()

  local order = {}
  local be = {
    keys = { space = false },
    keyDown = function(self, k) return self.keys[k] end,
    gamepad = function() return nil end,
  }
  input.clear()
  input.setBackend(be)
  input.define({ poke = { keys = { "space" } } })

  boot.run({
    scenes = { home = { update = function(dt) order[#order + 1] = dt end } },
    first = "home",
    args = {},
  })

  be.keys.space = true
  boot.frame(0.016) -- input.update runs before scene.update in the same frame
  T.eq(order, { 0.016 })
  T.isTrue(input.down("poke"))
  T.eq(time.gameDt, 0.016)
  scene.clear()
end)
