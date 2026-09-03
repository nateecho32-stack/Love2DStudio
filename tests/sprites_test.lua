local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local sprites = R("render.sprites")

local function layout()
  return {
    idle1 = { x = 0, y = 0, w = 16, h = 24, ox = 4, oy = 2 },
    idle2 = { x = 16, y = 0, w = 16, h = 24, ox = 4, oy = 2 },
  }
end

T.case("sprites: get returns nil for unknown keys (fallback contract)", function()
  local S = sprites.new{ layout = layout(), image = nil }
  T.isNil(S:get("ghost"))
  T.isNil(S:get("idle1")) -- no image either
end)

T.case("sprites: quads build once and frames carry trim offsets", function()
  if not (love and love.graphics) then return end
  local img = love.graphics.newCanvas(32, 32)
  local S = sprites.new{ layout = layout(), image = img }
  local a = S:get("idle1")
  T.isTrue(a ~= nil)
  T.eq(a.frame.ox, 4)
  T.eq(S:get("idle1"), a) -- cached
  local ok = pcall(function() S:draw("idle1", 100, 100) end)
  T.isTrue(ok, "sprite draw raised")
  T.isTrue(not S:draw("ghost", 0, 0)) -- miss reports false, no error
end)

T.case("sprites: center anchor mode centers frames on the draw position", function()
  if not (love and love.graphics) then return end
  local img = love.graphics.newCanvas(32, 32)
  local feet = sprites.new{ layout = layout(), image = img }
  local center = sprites.new{ layout = layout(), image = img, defaultAnchor = "center" }
  T.eq(feet.anchor, "feet")
  T.eq(center.anchor, "center")
  local ok = pcall(function()
    feet:draw("idle1", 10, 10)
    center:draw("idle1", 10, 10)
    center:draw("ghost", 10, 10) -- miss stays a clean false in either mode
  end)
  T.isTrue(ok, "anchored draws raised")
end)

T.case("animator: plays clips, loops, and reports done on one-shots", function()
  local S = sprites.new{ layout = layout(), image = nil }
  S:registerClip("walk", { frames = { "idle1", "idle2" }, fps = 10, loop = true })
  S:registerClip("die", { frames = { "idle1" }, fps = 10, loop = false })
  local A = sprites.animator(S)

  A:play("walk")
  A:update(0)      T.eq(A:frame(), "idle1")
  A:update(0.1)    T.eq(A:frame(), "idle2")
  A:update(0.11)   T.eq(A:frame(), "idle1") -- t=0.21: next cycle
  T.isTrue(not A:done())

  A:play("die")
  A:update(0.2)
  T.eq(A:frame(), "idle1")
  T.isTrue(A:done())
end)

T.case("animator: draw falls back to the procedural fn when clips miss", function()
  local S = sprites.new{ layout = {}, image = nil }
  local A = sprites.animator(S)
  local fellBack = false
  A.fallback = function() fellBack = true end
  A:play("nothing")
  A:draw(0, 0)
  T.isTrue(fellBack)
end)

T.case("state machine: set switches clips and auto-advances on completion", function()
  local S = sprites.new{ layout = layout(), image = nil }
  S:registerClip("spawn", { frames = { "idle1" }, fps = 10, loop = false })
  S:registerClip("idle", { frames = { "idle1", "idle2" }, fps = 10, loop = true })
  local A = sprites.animator(S)
  local M = sprites.stateMachine(A)
  M:add("spawning", { clip = "spawn", next = "idle" })
  M:add("idle", { clip = "idle" })

  M:set("spawning")
  T.eq(A.clip, "spawn")
  M:update(0.05)
  T.eq(A.clip, "spawn")
  M:update(0.2) -- spawn clip (1 frame @10fps) finishes -> auto-advance
  T.eq(M.current, "idle")
  T.eq(A.clip, "idle")
end)

T.case("state machine: speed scales playback", function()
  local S = sprites.new{ layout = layout(), image = nil }
  S:registerClip("fast", { frames = { "idle1", "idle2" }, fps = 10, loop = true })
  local A = sprites.animator(S)
  local M = sprites.stateMachine(A)
  M:add("go", { clip = "fast", speed = 2 })
  M:set("go")
  M:update(0.05) -- 2x: 0.05s * 2 = one full frame step
  T.eq(A:frame(), "idle2")
end)
