-- Loot: weighted tables with tier scaling, scarcity ("most spots are empty;
-- scarcity is the point" — Dead Meridian), and durability/quantity rolls.
-- The weighted picker is the most re-implemented primitive in the audit
-- (six projects); this is the canonical home.

local loot = {}

-- opts: { random = fn } — inject an rng stream for seeded determinism
function loot.new(opts)
  opts = opts or {}
  local L = { random = opts.random or function() return love and love.math and love.math.random() or 0.5 end }

  -- table = { entries = { {w = 5, id = "scrap", minTier = 1}, ... },
  --           scarcity = 0.5,            -- chance a roll yields nothing
  --           durability = { 0.35, 0.95 } }
  -- returns nil (scarcity / nothing rolled) or { id =, count =, durability = }
  function L:roll(table, tier)
    tier = tier or 1
    local rng = self.random
    if table.scarcity and rng() < table.scarcity then return nil end
    local entries = {}
    for _, e in ipairs(table.entries or {}) do
      if (e.minTier or 1) <= tier then entries[#entries + 1] = e end
    end
    if #entries == 0 then return nil end
    local total = 0
    for i = 1, #entries do total = total + entries[i].w end
    local pick = rng() * total
    local chosen
    for i = 1, #entries do
      pick = pick - entries[i].w
      if pick <= 0 then chosen = entries[i] break end
    end
    chosen = chosen or entries[#entries]
    local count = 1
    if chosen.count then
      count = chosen.count[1] + math.floor(rng() * (chosen.count[2] - chosen.count[1] + 1))
      count = count + math.floor((tier - 1) * 0.5) -- tier scales quantity a little
    end
    local durability = nil
    if table.durability then
      local lo, hi = table.durability[1], table.durability[2]
      durability = lo + (hi - lo) * rng()
    end
    return { id = chosen.id, count = count, durability = durability, tier = tier }
  end

  -- populate several rolls (per-POI/per-container), seeded by the caller's rng
  function L:populate(table, spots, tier)
    local out = {}
    for _ = 1, spots do
      local roll = self:roll(table, tier)
      if roll then out[#out + 1] = roll end
    end
    return out
  end

  return L
end

return loot
