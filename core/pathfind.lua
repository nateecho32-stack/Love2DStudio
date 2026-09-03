-- Pathfinding: A* over a grid with an injectable passability predicate, plus
-- BFS flood fill (the shared-reachability pattern Trippy used to replace six
-- duplicated flood fills). Dependency-free; the grid belongs to the caller.

local pathfind = {}

-- passability contract: pass(x, y) -> truthy when the cell is WALKABLE
-- (false/nil for walls — see mapPass below); richer rules are just functions
local function neighbors(x, y, pass)
  local out = {}
  local candidates = { { x + 1, y }, { x - 1, y }, { x, y + 1 }, { x, y - 1 } }
  for i = 1, 4 do
    local cx, cy = candidates[i][1], candidates[i][2]
    if pass(cx, cy) then out[#out + 1] = { x = cx, y = cy } end
  end
  return out
end

local function key(x, y) return x .. "," .. y end

-- returns { {x=,y=}, ... } start-exclusive goal-inclusive, or nil
-- opts: { maxNodes = 5000 } guards against runaway searches
function pathfind.astar(sx, sy, gx, gy, pass, opts)
  opts = opts or {}
  local maxNodes = opts.maxNodes or 5000
  if not pass(sx, sy) or not pass(gx, gy) then return nil end
  if sx == gx and sy == gy then return {} end

  local open = { { x = sx, y = sy, g = 0, f = math.abs(gx - sx) + math.abs(gy - sy) } }
  local cameFrom = {}
  local gScore = { [key(sx, sy)] = 0 }
  local closed = {}
  local expanded = 0

  while #open > 0 do
    expanded = expanded + 1
    if expanded > maxNodes then return nil end

    -- pop the lowest-f node (linear scan; grids are small)
    local best = 1
    for i = 2, #open do
      if open[i].f < open[best].f then best = i end
    end
    local node = table.remove(open, best)
    local nk = key(node.x, node.y)
    if not closed[nk] then
      closed[nk] = true
      if node.x == gx and node.y == gy then
        -- walk back
        local path = {}
        local cur = { node.x, node.y }
        while cur[1] ~= sx or cur[2] ~= sy do
          path[#path + 1] = { x = cur[1], y = cur[2] }
          cur = cameFrom[key(cur[1], cur[2])]
        end
        local out = {}
        for i = #path, 1, -1 do out[#out + 1] = path[i] end
        return out
      end
      for _, nb in ipairs(neighbors(node.x, node.y, pass)) do
        local tentative = node.g + 1
        local nkey = key(nb.x, nb.y)
        if not closed[nkey] and (gScore[nkey] == nil or tentative < gScore[nkey]) then
          gScore[nkey] = tentative
          cameFrom[nkey] = { node.x, node.y }
          open[#open + 1] = {
            x = nb.x, y = nb.y, g = tentative,
            f = tentative + math.abs(gx - nb.x) + math.abs(gy - nb.y),
          }
        end
      end
    end
  end
  return nil
end

-- BFS flood fill from a start; visit(x, y, distance) for every reachable cell
-- (distance in steps). Returns the count of visited cells.
function pathfind.flood(sx, sy, pass, visit, opts)
  opts = opts or {}
  local maxDist = opts.maxDist or math.huge
  if not pass(sx, sy) then return 0 end
  local frontier = { { sx, sy, 0 } }
  local seen = { [key(sx, sy)] = true }
  local count = 0
  while #frontier > 0 do
    local node = table.remove(frontier, 1)
    count = count + 1
    if visit then visit(node[1], node[2], node[3]) end
    if node[3] < maxDist then
      for _, nb in ipairs(neighbors(node[1], node[2], pass)) do
        local nk = key(nb.x, nb.y)
        if not seen[nk] then
          seen[nk] = true
          frontier[#frontier + 1] = { nb.x, nb.y, node[3] + 1 }
        end
      end
    end
  end
  return count
end

-- convenience: build a pass predicate from a 2D array map (1/#/true = wall).
-- Only explicit 0/false cells are walkable — nil (out of bounds) is a wall,
-- or a flood fill escapes to x = -inf through column 0.
function pathfind.mapPass(map)
  return function(x, y)
    if x < 1 then return false end
    local row = map[y]
    if type(row) ~= "table" then return false end
    local cell = row[x]
    return cell == 0 or cell == false
  end
end

return pathfind
