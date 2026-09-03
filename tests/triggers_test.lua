local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local ecs = R("core.ecs")
local triggers = R("core.triggers")

local function worldWithTrigger(triggerDef)
  local world = ecs.new()
  local id = world:spawn()
  world:add(id, "transform", { x = 100, y = 100, rot = 0, scale = 1 })
  world:add(id, "trigger", triggerDef)
  return world, id
end

T.case("triggers: enter and leave fire as the watcher crosses", function()
  local world = worldWithTrigger({ w = 40, h = 40 })
  local TR = triggers.new(world)
  local entered, left = 0, 0
  world:get(1, "trigger").onEnter = function() entered = entered + 1 end
  world:get(1, "trigger").onLeave = function() left = left + 1 end

  TR:watch("player", 0, 100)
  TR:update()
  T.eq(entered, 0)

  TR:watch("player", 100, 100) -- inside
  TR:update()
  T.eq(entered, 1)

  TR:update() -- still inside: no refire
  T.eq(entered, 1)

  TR:watch("player", 200, 100) -- out again
  TR:update()
  T.eq(left, 1)
end)

T.case("triggers: scale grows the volume", function()
  local world = worldWithTrigger({ w = 40, h = 40 })
  world:get(1, "transform").scale = 2 -- 80x80 volume
  local TR = triggers.new(world)
  local entered = 0
  world:get(1, "trigger").onEnter = function() entered = entered + 1 end
  TR:watch("player", 139, 100) -- outside 40x40, inside 80x80
  TR:update()
  T.eq(entered, 1)
end)

T.case("triggers: once triggers destroy their entity on leave", function()
  local world, id = worldWithTrigger({ w = 40, h = 40, once = true })
  local TR = triggers.new(world)
  TR:watch("player", 100, 100)
  TR:update()
  TR:watch("player", 0, 0)
  TR:update()
  world:update(0) -- sweep deferred destroys
  T.isNil(world:get(id, "trigger"))
  T.eq(world:alive(), 0)
end)

T.case("triggers: events also land on the bus", function()
  local events = R("core.events")
  local bus = events.new()
  local world = worldWithTrigger({ w = 40, h = 40 })
  local TR = triggers.new(world, { bus = bus })
  local fired = {}
  bus.on("trigger.enter", function() fired[#fired + 1] = "enter" end)
  bus.on("trigger.leave", function() fired[#fired + 1] = "leave" end)
  TR:watch("p", 100, 100)
  TR:update()
  TR:watch("p", 0, 0)
  TR:update()
  T.eq(fired, { "enter", "leave" })
end)
