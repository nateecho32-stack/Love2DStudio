local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local ecs = R("core.ecs")

T.case("ecs: spawn/add/get", function()
  local world = ecs.new()
  local id = world:spawn()
  world:add(id, "transform", { x = 1, y = 2 })
  T.eq(world:get(id, "transform"), { x = 1, y = 2 })
  T.isNil(world:get(id, "nope"))
  T.eq(world:alive(), 1)
end)

T.case("ecs: each visits ids in sorted order", function()
  local world = ecs.new()
  local ids = {}
  for i = 1, 5 do
    local id = world:spawn()
    world:add(id, "tag", i)
    ids[#ids + 1] = id
  end
  local visited = {}
  world:each("tag", function(id, v) visited[#visited + 1] = v end)
  T.eq(visited, { 1, 2, 3, 4, 5 })
end)

T.case("ecs: systems run in order and receive the world", function()
  local world = ecs.new()
  local order = {}
  world:addSystem("late", function(w, dt) order[#order + 1] = "late:" .. dt end, 5)
  world:addSystem("early", function(w, dt)
    order[#order + 1] = "early"
    local id = w:spawn()
    w:add(id, "hp", 10)
  end, 1)
  world:update(0.25)
  T.eq(order, { "early", "late:0.25" })
end)

T.case("ecs: destroy is deferred until end of update", function()
  local world = ecs.new()
  local id = world:spawn()
  world:add(id, "hp", 10)
  world:addSystem("killer", function(w)
    w:each("hp", function(e)
      w:remove(e, "hp")
      w:destroy(e)
    end)
  end)
  world:update(0.1)
  T.eq(world:alive(), 0)          -- swept at end of update
  T.isNil(world:get(id, "hp"))
end)

T.case("ecs: removing one component keeps the entity", function()
  local world = ecs.new()
  local id = world:spawn()
  world:add(id, "a", 1)
  world:add(id, "b", 2)
  world:remove(id, "a")
  T.isNil(world:get(id, "a"))
  T.eq(world:get(id, "b"), 2)
  T.eq(world:alive(), 1)
end)
