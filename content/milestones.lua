-- Milestones: strictly ordered unlock ladder with derived progress ("store
-- the raw stat, derive the unlock" — Void Place/Vimur/Endless Grind all
-- converge here) and a reward-table mutation hook (progression widens the
-- loot table, Vimur-style).

local milestones = {}

-- list: ordered { { id =, label =, stat = "bestDepth", at = 500 }, ... }
-- stats: the raw counters table the ladder reads from
function milestones.new(list, stats)
  local M = {
    list = list,
    stats = stats or {},
    level = 0,          -- highest achieved index
    hooks = {},
  }

  function M:achievedIndex()
    local highest = 0
    for i, entry in ipairs(M.list) do
      local value = M.stats[entry.stat] or 0
      if value >= (entry.at or 0) then highest = i else break end
    end
    return highest
  end

  -- returns array of newly crossed entries (diff since last check) — the
  -- caller turns these into announcements/toasts
  function M:check()
    local crossed = {}
    local target = M:achievedIndex()
    while M.level < target do
      M.level = M.level + 1
      crossed[#crossed + 1] = M.list[M.level]
      for _, hook in ipairs(M.hooks) do hook(M.list[M.level], M.level) end
    end
    return crossed
  end

  function M:onCross(fn) M.hooks[#M.hooks + 1] = fn end

  function M:next()
    return M.list[M.level + 1]
  end

  -- reward-table mutation: weight tables per level (Vimur rarity weights).
  -- levels: { [level] = { common = 85, rare = 15 }, ... } ; falls back to the
  -- highest defined level <= current level.
  function M:rewardWeights(levels, base)
    local chosen = base
    for level = 1, M.level do
      if levels[level] then chosen = levels[level] end
    end
    return chosen or base
  end

  return M
end

return milestones
