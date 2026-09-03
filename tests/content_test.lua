local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local spawnMod = R("content.spawn")
local economy = R("content.economy")
local milestones = R("content.milestones")
local loot = R("content.loot")
local variation = R("content.variation")
local offline = R("content.offline")

local function stepper(values)
  local i = 0
  return function()
    i = i % #values + 1
    return values[i]
  end
end

T.case("spawn: pressure compresses cadence and respects the cap", function()
  local director = spawnMod.new{
    base = 10, minInterval = 2, lingerRate = 0.5, depthRate = 0.5,
    cap = function() return 1 end,
    weights = { { w = 1, v = "slime" } },
    random = stepper({ 0.9 }),
  }
  local spawned = {}
  for _ = 1, 40 do
    local batch = director:update(1, 5)
    if batch then spawned[#spawned + 1] = batch[1] end
  end
  T.eq(#spawned, 1)      -- spawned once, then the cap (1) blocks the rest
  director:despawn()
  director.linger = 20   -- heavy pressure: next tick fires
  local batch = director:update(1, 5)
  T.eq(batch and batch[1], "slime")
end)

T.case("spawn: canSpawn hook gates (safe pockets)", function()
  local blocked = true
  local director = spawnMod.new{
    base = 1, minInterval = 1,
    weights = { { w = 1, v = "bat" } },
    canSpawn = function() return not blocked end,
    random = stepper({ 0.5 }),
  }
  director:update(2, 0)
  T.isNil(director:update(0.1, 0))
  blocked = false
  local batch = director:update(1, 0) -- the full interval elapses
  T.eq(batch and batch[1], "bat")
end)

T.case("economy: geometric curves and market variance", function()
  T.eq(economy.geometric(60, 1.18, 1), 60)
  T.eq(economy.geometric(60, 1.18, 2), 71)  -- 60*1.18 = 70.8
  T.eq(economy.upgradeCost(10, 2, 3), 80)
  local lo = economy.marketBase({ common = 100 }, "common", 0.3, function() return 0 end)
  local hi = economy.marketBase({ common = 100 }, "common", 0.3, function() return 0.999 end)
  T.eq(lo, 70)
  T.eq(hi, 130)
end)

T.case("economy: sell/buy asymmetry", function()
  local sell = economy.sellPrice{ base = 100, complexity = 10, perComplexity = 0.8, mutations = 2, perMutation = 12, multiplier = 1.5 }
  T.eq(sell, 198) -- (100 + 8 + 24) * 1.5
  T.eq(economy.buyPrice(100), 95) -- 0.9x + 5 flat
end)

T.case("milestones: derived progress, crossing diff, reward mutation", function()
  local stats = { bestDepth = 0 }
  local ladder = milestones.new({
    { id = "d500", label = "500m", stat = "bestDepth", at = 500 },
    { id = "d1000", label = "1000m", stat = "bestDepth", at = 1000 },
    { id = "d2000", label = "2000m", stat = "bestDepth", at = 2000 },
  }, stats)
  local crossed = {}
  ladder:onCross(function(entry) crossed[#crossed + 1] = entry.id end)

  stats.bestDepth = 300
  T.eq(#ladder:check(), 0)
  stats.bestDepth = 1200
  T.eq(#ladder:check(), 2) -- crossed 500 AND 1000
  T.eq(crossed, { "d500", "d1000" })
  T.eq(ladder:next().id, "d2000")

  local weights = ladder:rewardWeights({
    [1] = { common = 90 },
    [2] = { common = 70, rare = 30 },
  }, { common = 100 })
  T.eq(weights.common, 70)
  T.eq(weights.rare, 30)
end)

T.case("loot: scarcity, tier gates, durability rolls", function()
  local L = loot.new{ random = function() return 0.99 end }
  local table = {
    entries = { { w = 1, id = "scrap" }, { w = 1, id = "relic", minTier = 3 } },
    scarcity = 0.2,
    durability = { 0.35, 0.95 },
  }
  local roll = L:roll(table, 1)
  T.eq(roll.id, "scrap") -- relic is tier-gated out at tier 1
  T.isTrue(roll.durability >= 0.35 and roll.durability <= 0.95)
  local highTier = L:roll(table, 3) -- relic unlocks: weighted pick can now land it
  T.isTrue(highTier ~= nil)
  -- scarcity: skip when rng < scarcity
  local scarce = loot.new{ random = function() return 0.1 end }
  T.isNil(scarce:roll(table, 1))
end)

T.case("loot: populate skips spots via scarcity", function()
  local L = loot.new{ random = function() return 0.9 end }
  local table = { entries = { { w = 1, id = "coin" } }, scarcity = 0.5 }
  T.eq(#L:populate(table, 6, 1), 6)  -- 0.9 not < 0.5: every spot yields
  local emptier = loot.new{ random = function() return 0.1 end }
  T.eq(#emptier:populate({ entries = { { w = 1, id = "coin" } }, scarcity = 0.95 }, 6, 1), 0)
end)

T.case("variation: mutation stays within bounds and logs", function()
  local V = variation.new{ random = function() return 0.95 end }
  local schema = { size = { kind = "number", spread = 0.5, min = 1, max = 4 }, flag = { kind = "boolean" } }
  local spec = { size = 3, flag = false }
  local _, log = V:mutate(spec, schema, { rate = 1 })
  T.isTrue(#log >= 1)
  T.isTrue(spec.size >= 1 and spec.size <= 4)
end)

T.case("variation: breed blends numerics toward dominance", function()
  local V = variation.new{ random = function() return 0 end }
  local child = V:breed({ size = 2, elite = false }, { size = 8, elite = true }, {
    size = { kind = "number", spread = 0 },
    elite = { kind = "boolean" },
  })
  T.near(child.size, 5) -- dominance 0.5: midpoint of the parents
  T.isTrue(child.elite == false)
end)

T.case("variation: scored rarity with thresholds", function()
  local V = variation.new{ random = function() return 0.5 end }
  local spec = { golden = true, flowers = 3 }
  local name = V:rarity(spec, {
    function(s) return s.golden and 30 or 0 end,
    function(s) return (s.flowers or 0) * 10 end,
  }, { { at = 0, name = "common" }, { at = 25, name = "rare" }, { at = 55, name = "exotic" } })
  T.eq(name, "exotic") -- 30 + 30 = 60
end)

T.case("offline: action-capped, efficiency-scaled catch-up", function()
  local actions = 0
  local report = offline.advance(3600, { maxActions = 100, efficiency = 0.6, minSeconds = 30 }, function()
    actions = actions + 1
    return 1 -- each action consumes one in-game second
  end)
  T.eq(report.actions, 100)
  T.isTrue(report.capped)
  T.isTrue(actions <= 100)

  local short = offline.advance(5, {}, function() return 1 end)
  T.eq(short.actions, 0) -- below minSeconds: no offline progress
end)
