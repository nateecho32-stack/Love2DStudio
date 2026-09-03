-- Depth-pressure spawn director: cadence compresses with depth + linger
-- time, population cap grows, safe-zone hook, zone-weighted types.
-- Adapted from Burning src/systems/spawning.lua + Dead Meridian's population
-- director (the same module with different knobs, per the audit).

local spawn = {}

-- opts: {
--   base = 10, minInterval = 3.5, lingerRate = 0.15, depthRate = 0.15,
--   cap = function(depth) return 4 + math.floor(depth / 3) end,
--   weights = { {w = 85, v = "stalker"}, ... }  or  fn(depth) -> weights
--   canSpawn = function() -> bool end   -- safe-pocket / min-distance hook
--   random = fn
-- }
function spawn.new(opts)
  opts = opts or {}
  local D = {
    opts = opts,
    live = 0,
    linger = 0,
    timer = 0,
    random = opts.random or function() return love and love.math and love.math.random() or 0.5 end,
  }

  function D:weights(depth)
    local w = opts.weights
    if type(w) == "function" then return w(depth) end
    return w
  end

  -- returns an array of spawned type names this tick (usually empty)
  function D:update(dt, depth, weightedPick)
    depth = depth or 0
    D.linger = D.linger + dt
    local interval = math.max(
      opts.minInterval or 3.5,
      (opts.base or 10) - D.linger * (opts.lingerRate or 0.15) - depth * (opts.depthRate or 0.15))
    D.timer = D.timer + dt
    if D.timer < interval then return nil end
    D.timer = 0

    if D.live >= (opts.cap and opts.cap(depth) or (4 + math.floor(depth / 3))) then return nil end
    if opts.canSpawn and not opts.canSpawn() then return nil end

    local weights = D:weights(depth)
    if not weights then return nil end
    local roll = D.random()
    local total = 0
    for i = 1, #weights do total = total + weights[i].w end
    local pick = roll * total
    for i = 1, #weights do
      pick = pick - weights[i].w
      if pick <= 0 then
        D.live = D.live + 1
        return { weights[i].v }
      end
    end
    return nil
  end

  -- the game calls this when the player leaves a depth band / area
  function D:resetLinger() D.linger = 0 end
  function D:despawn() D.live = math.max(0, D.live - 1) end

  return D
end

return spawn
