local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local physics = R("physics.init")

T.case("physics: categories allocate bits and the matrix is symmetric", function()
  local P = physics.new{}
  local player = P:category("player")
  local wall = P:category("wall")
  T.eq(player, 1)
  T.eq(wall, 2)
  T.eq(P:category("player"), 1) -- stable
  P:collide("player", "wall")
  T.isTrue(P:shouldCollide(player, wall))
  T.isTrue(P:shouldCollide(wall, player))
  P:collide("player", "wall", false)
  T.isTrue(not P:shouldCollide(player, wall))
end)

T.case("physics: bodies exist, fall under gravity, and rest on a floor", function()
  if not (love and love.physics) then return end
  local P = physics.new{ gravity = { 0, 600 } }
  T.isTrue(P:hasWorld())

  local floor = P:makeBody{ bodyType = "static", x = 400, y = 300, w = 800, h = 20, category = "wall" }
  local ball = P:makeBody{ bodyType = "dynamic", x = 400, y = 0, shape = "circle", r = 10,
                           category = "player", friction = 0.5, restitution = 0 }
  T.isTrue(floor ~= nil and ball ~= nil)

  for _ = 1, 300 do P:update(1 / 60) end
  local y = ball:getY()
  T.isTrue(y > 250 and y < 300, "ball must come to rest on the floor, got y=" .. y)
  T.isTrue(math.abs(ball:getY() - y) < 5)
end)

T.case("physics: contacts queue and drain outside the step", function()
  if not (love and love.physics) then return end
  local P = physics.new{ gravity = { 0, 0 } }
  local floor = P:makeBody{ bodyType = "static", x = 400, y = 100, w = 800, h = 20, category = "wall" }
  local ball = P:makeBody{ bodyType = "dynamic", x = 400, y = 50, shape = "circle", r = 10, category = "player" }
  ball:setLinearVelocity(0, 200)

  local began = 0
  for _ = 1, 120 do
    P:update(1 / 60)
    P:drainContacts(function(kind) if kind == "begin" then began = began + 1 end end)
  end
  T.isTrue(began >= 1, "a begin contact must be observed")
end)

T.case("physics: raycast finds the floor", function()
  if not (love and love.physics) then return end
  local P = physics.new{ gravity = { 0, 0 } }
  P:makeBody{ bodyType = "static", x = 400, y = 200, w = 800, h = 20, category = "wall" }
  local hit = P:raycast(400, 0, 400, 400)
  T.isTrue(hit ~= nil)
  T.isTrue(hit.y > 180 and hit.y < 210)
  T.isNil(P:raycast(400, 0, 400, -400)) -- nothing above
end)

T.case("physics: no-world mode degrades instead of crashing", function()
  -- simulate headless: a world without love.physics
  local P = physics.new{}
  P.world = nil -- force the degraded path
  T.isTrue(not P:hasWorld())
  T.isNil(P:makeBody{ x = 0, y = 0 })
  P:update(1 / 60) -- no-op
  P:drainContacts(function() error("must not fire") end)
  T.isNil(P:raycast(0, 0, 1, 1))
end)
