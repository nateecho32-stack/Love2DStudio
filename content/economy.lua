-- Economy curves: geometric costs, per-tier market pricing with variance,
-- buy/sell asymmetry, and derived sell formulas. Mergeable shape from
-- Endless Grind config.js + Vimur src/shop/pricing.lua.

local economy = {}

-- the one curve behind XP ladders and upgrade sinks: base * growth^level
function economy.geometric(base, growth, level)
  return math.floor(base * growth ^ (level - 1) + 0.5)
end

-- upgrade sink cost: base * growth^owned, capped at maxAffordable shape
function economy.upgradeCost(base, growth, owned)
  return math.floor(base * growth ^ owned + 0.5)
end

-- per-rarity market base with variance: 12 +/- 30% for common, wider at the top
-- table = { common = 12, ... } ; variance = fraction (0.3 = +/-30%)
function economy.marketBase(table, rarity, variance, rng)
  local base = table[rarity] or table[1] or 0
  local v = (rng and rng() or 0.5) * 2 - 1
  return math.max(1, math.floor(base * (1 + v * (variance or 0.3)) + 0.5))
end

-- sell/buy asymmetry: buy near list, sell below it (Vimur: buy 0.9x, seed resale 0.5x)
function economy.sellPrice(parts)
  -- parts = { base = rarityMarketBase, complexity = n, perComplexity = 0.8,
  --           mutations = n, perMutation = 12, multiplier = genomeValueMul }
  local value = (parts.base or 0)
    + (parts.complexity or 0) * (parts.perComplexity or 0.8)
    + (parts.mutations or 0) * (parts.perMutation or 12)
  return math.floor(value * (parts.multiplier or 1) + 0.5)
end

function economy.buyPrice(base, opts)
  opts = opts or {}
  return math.floor(base * (opts.buyMultiplier or 0.9) + (opts.flat or 5) + 0.5)
end

return economy
