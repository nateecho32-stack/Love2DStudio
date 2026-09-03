# content/ — data-driven gameplay modules

Logic-only gameplay systems distilled from the project audit. All are
rng-injectable and headless-testable; the reference game (sample/) is the
showcase consumer.

- **spawn.lua** — depth-pressure spawn director: cadence compresses with
  depth + linger, population cap grows with depth, `canSpawn` hook for
  safe zones/min-distance, weighted type picks. (Burning + Dead Meridian.)
- **economy.lua** — geometric curves (`base*growth^level`), upgrade costs,
  per-tier market bases with variance, derived sell prices, buy/sell
  asymmetry. (Endless Grind + Vimur.)
- **milestones.lua** — strictly ordered unlock ladder over raw stats
  ("store the stat, derive the unlock"), crossing diffs for announcements,
  `rewardWeights` so progression widens loot tables. (Void Place + Vimur.)
- **loot.lua** — weighted rolls with tier gates, scarcity skips
  ("most spots are empty"), durability/quantity rolls, multi-spot populate.
  (Dead Meridian + Burning.)
- **variation.lua** — bounded-nudge mutation over typed specs, dominance-
  weighted breeding, curated wildcards, scored rarity with thresholds.
  (Vimur genome + the Python evolution sim.)
- **offline.lua** — action-capped, efficiency-scaled catch-up that re-runs
  the real action loop. (Endless Grind advanceSim.)

System links: all standalone; pass an `rng` stream for determinism.
