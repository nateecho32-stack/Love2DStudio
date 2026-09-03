local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local pathfind = R("core.pathfind")

--  . = floor, # = wall
local MAP = {
  { 0, 0, 0, 0, 0 },
  { 0, 1, 1, 1, 0 },
  { 0, 0, 0, 1, 0 },
  { 1, 1, 0, 1, 0 },
  { 0, 0, 0, 0, 0 },
}

local pass = pathfind.mapPass(MAP)

T.case("mapPass: walls block, floors pass", function()
  T.isTrue(pass(1, 1))
  T.isTrue(not pass(2, 2))
  T.isTrue(not pass(99, 99)) -- out of bounds = blocked
end)

T.case("astar: finds a path around walls", function()
  local path = pathfind.astar(1, 1, 5, 5, pass)
  T.isTrue(path ~= nil, "a path must exist")
  T.eq(path[#path].x, 5)
  T.eq(path[#path].y, 5)
  -- every step is adjacent and walkable
  local prev = { x = 1, y = 1 }
  for _, step in ipairs(path) do
    local dx = math.abs(step.x - prev.x)
    local dy = math.abs(step.y - prev.y)
    T.isTrue(dx + dy == 1, "steps must be 4-adjacent")
    T.isTrue(pass(step.x, step.y), "path must not cross walls")
    prev = step
  end
end)

T.case("astar: unreachable goals return nil", function()
  local blocked = {
    { 0, 1, 0 },
    { 1, 1, 0 },
    { 0, 1, 0 },
  }
  local p = pathfind.mapPass(blocked)
  T.isNil(pathfind.astar(1, 1, 3, 3, p))
end)

T.case("astar: start == goal yields an empty path; blocked ends yield nil", function()
  T.eq(pathfind.astar(3, 1, 3, 1, pass), {})
  T.isNil(pathfind.astar(2, 2, 3, 3, pass)) -- start inside a wall
end)

T.case("flood: visits exactly the reachable cells with distances", function()
  local visited = {}
  local count = pathfind.flood(1, 3, pass, function(x, y, d)
    visited[x .. "," .. y] = d
  end)
  -- column 1 rows 1-3 + row 3 corridor + right side
  T.isTrue(count >= 10, "expected a healthy reachable set, got " .. count)
  T.eq(visited["1,3"], 0)
  T.eq(visited["2,3"], 1)
  T.isNil(visited["2,2"]) -- behind a wall
end)

T.case("flood: maxDist limits the fill", function()
  local count = pathfind.flood(1, 3, pass, nil, { maxDist = 1 })
  T.eq(count, 3) -- start + its 2 open neighbors
end)
