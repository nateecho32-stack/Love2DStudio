local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local input = R("core.input")

local function fakeBackend()
  return {
    keys = {},
    padButtons = {},
    padAxes = {},
    keyDown = function(self, k) return self.keys[k] == true end,
    gamepad = function(self)
      if not self.hasPad then return nil end
      return {
        isDown = function(_, b) return self.padButtons[b] == true end,
        axis = function(_, a) return self.padAxes[a] or 0 end,
      }
    end,
  }
end

T.case("input: keyboard edge detection", function()
  input.clear()
  local be = fakeBackend()
  input.setBackend(be)
  input.define({ jump = { keys = { "space" } } })

  input.update()
  T.isTrue(not input.pressed("jump"))

  be.keys["space"] = true
  input.update()
  T.isTrue(input.pressed("jump"))
  T.isTrue(input.down("jump"))

  input.update()
  T.isTrue(input.down("jump"))
  T.isTrue(not input.pressed("jump"))

  be.keys["space"] = nil
  input.update()
  T.isTrue(input.released("jump"))
  T.isTrue(not input.down("jump"))
end)

T.case("input: gamepad button mapping", function()
  input.clear()
  local be = fakeBackend()
  be.hasPad = true
  input.setBackend(be)
  input.define({ jump = { buttons = { "a" } } })

  input.update()
  T.isTrue(not input.down("jump"))
  be.padButtons["a"] = true
  input.update()
  T.isTrue(input.down("jump"))
end)

T.case("input: axis with deadzone and direction", function()
  input.clear()
  local be = fakeBackend()
  be.hasPad = true
  input.setBackend(be)
  input.deadzone = 0.25
  input.define({ left = { axis = "leftx", dir = -1 } })

  be.padAxes["leftx"] = 0
  input.update()
  T.eq(input.value("left"), 0)

  be.padAxes["leftx"] = -0.9 -- negative stick, dir=-1 flips to positive
  input.update()
  T.isTrue(input.value("left") > 0)
  T.isTrue(input.down("left"))

  be.padAxes["leftx"] = 0.1 -- below deadzone (after flip: -0.1)
  input.update()
  T.eq(input.value("left"), 0)
end)

T.case("input: actionFromKey reverse lookup", function()
  input.clear()
  input.define({ shoot = { keys = { "f", "kpenter" } }, jump = { keys = { "space" } } })
  T.eq(input.actionFromKey("f"), "shoot")
  T.eq(input.actionFromKey("space"), "jump")
  T.isNil(input.actionFromKey("q"))
end)

T.case("input: undefined action reads as 0/false", function()
  input.clear()
  input.update()
  T.eq(input.value("nothing"), 0)
  T.isTrue(not input.down("nothing"))
end)
