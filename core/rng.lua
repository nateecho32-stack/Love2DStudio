-- Seeded RNG streams with deterministic sub-streams, weighted picks, shuffle,
-- and value-noise/fbm. Adapted from Void Place engine/rng.lua, Burning
-- src/world/generator.lua (seed*1000003+index chunk mixing) and Dead Meridian.

local M = {}

local function newGen(seed)
  if love and love.math then
    return love.math.newRandomGenerator(seed)
  end
  -- minimal pure-Lua fallback (Lehmer) so checks can run without a LÖVE runtime
  local s = math.floor(seed or 1) % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return {
    random = function(_, a, b)
      s = (s * 16807) % 2147483647
      local r = s / 2147483647
      if a == nil then return r end
      if b == nil then a, b = 1, a end
      return math.floor(r * (b - a + 1)) + a
    end,
  }
end

-- stream API: int, float, chance, pick, weighted, weightedMap, shuffle, fork, value
function M.new(seed)
  seed = seed or 1
  local gen = newGen(seed)
  local stream = { seed = seed }

  function stream:value() return gen:random() end
  function stream:int(a, b) return gen:random(a, b) end
  function stream:float(a, b)
    if b == nil then a, b = 0, a end
    return a + (b - a) * gen:random()
  end
  function stream:chance(p) return gen:random() < p end
  function stream:pick(t) return t[gen:random(1, #t)] end

  -- list of {w=weight, v=value} (or {weight=, value=}); returns value, index
  function stream:weighted(list)
    local total = 0
    for i = 1, #list do total = total + (list[i].w or list[i].weight) end
    local roll = gen:random() * total
    for i = 1, #list do
      roll = roll - (list[i].w or list[i].weight)
      if roll <= 0 then return list[i].v or list[i].value, i end
    end
    local last = list[#list]
    return last and (last.v or last.value), #list
  end

  -- map form {key=weight}; sorted keys keep it deterministic across table orders
  function stream:weightedMap(map)
    local keys, list = {}, {}
    for k in pairs(map) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for i = 1, #keys do list[i] = { w = map[keys[i]], v = keys[i] } end
    local v = stream:weighted(list)
    return v
  end

  -- Fisher-Yates, in place, returns t
  function stream:shuffle(t)
    for i = #t, 2, -1 do
      local j = gen:random(1, i)
      t[i], t[j] = t[j], t[i]
    end
    return t
  end

  -- deterministic sub-stream (Void Place pattern): same seed+salt -> same sequence
  function stream:fork(salt) return M.new(seed * 1000003 + (salt or 0)) end

  return stream
end

-- deterministic per-index stream: Burning's chunk-seeding pattern
function M.forIndex(seed, index) return M.new((seed or 1) * 1000003 + (index or 0)) end

function M.noise(x, y)
  if love and love.math then return love.math.noise(x, y or 0) end
  error("rng.noise requires the LÖVE runtime")
end

function M.fbm(x, y, octaves)
  octaves = octaves or 4
  local amp, freq, sum, norm = 1, 1, 0, 0
  for _ = 1, octaves do
    sum = sum + amp * M.noise(x * freq, y * freq)
    norm = norm + amp
    amp = amp * 0.5
    freq = freq * 2
  end
  return sum / norm
end

return M
