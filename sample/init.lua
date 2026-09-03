-- Gem Haul shared state: the studio modules a real game actually wires —
-- saves (sidecars), stats-driven milestones, settings, and scene registry.
-- This file is the template for "your game's glue".
-- Path note: sibling modules (menu/game/results) resolve the studio as
-- "init" and each other as "sample.<x>" — this file follows the same shape.

local S = require("init")

local sample = { S = S }

-- lazy library registry: scenes pull the heavier engines on first access, so
-- the menu boots without loading sprite/shader/pathfind machinery. i18n is
-- eager — every scene draws strings.
sample.D = S.deps.new({
  i18n       = "core.i18n",
  pathfind   = "core.pathfind",
  shaders    = "render.shaders",
  sprites    = "render.sprites",
  atlas_pack = "tools.atlas_pack",
  offline    = "content.offline",
}, { "i18n" })

-- shared locale registry: every player-facing string in the game resolves
-- through sample.i18n:t(key, ...); en is the fallback for partial locales
sample.i18n = sample.D.i18n.new{ default = "en" }
sample.i18n:registerLocale("en", { name = "English", strings = {
  ["menu.title"]       = "GEM HAUL",
  ["menu.stats"]       = "best %d | lifetime gems %d | runs %d (%d wins)",
  ["menu.play"]        = "Play (Enter)",
  ["menu.quit"]        = "Quit (Esc)",
  ["game.exit_open"]   = "EXIT",
  ["game.exit_closed"] = "EXIT %d/%d",
  ["game.hud"]         = "time %.0f   hearts %s   gems %d/%d   score %d",
  ["game.help"]        = "wasd/arrows move — collect gems, reach the exit — F1 back to studio",
  ["results.win"]      = "HAUL COMPLETE",
  ["results.lose"]     = "HAUL FAILED",
  ["results.score"]    = "score %d   gems %d   time left %.1fs",
  ["results.new_best"] = "NEW BEST",
  ["results.again"]    = "Play Again (Enter)",
  ["results.menu"]     = "Menu (Esc)",
  ["milestone.g10"]    = "10 gems collected",
  ["milestone.g25"]    = "25 gems collected",
  ["milestone.w1"]     = "first win",
  ["toast.unlocked"]   = "UNLOCKED: %s",
  ["toast.away"]       = "away haul: +%d gems (%s away)",
} })

sample.SCENE_FILE = "scenes/gemhaul.lua"

-- default layout: the built-in level the editor file replaces; designed so a
-- scripted "hold right" run collects every gem and reaches the exit
sample.DEFAULT_LAYOUT = {
  version = 1,
  name = "gemhaul_default",
  entities = {
    { type = "player_spawn", x = -420, y = 0, props = {} },
    { type = "wall", x = 0, y = -320, props = {} },
    { type = "wall", x = 64, y = -320, props = {} },
    { type = "wall", x = 128, y = -320, props = {} },
    { type = "wall", x = 0, y = 320, props = {} },
    { type = "wall", x = 64, y = 320, props = {} },
    { type = "wall", x = 128, y = 320, props = {} },
    { type = "gem", x = -240, y = 0, props = { tier = "common" } },
    { type = "gem", x = -120, y = 0, props = { tier = "common" } },
    { type = "gem", x = 0, y = 0, props = { tier = "rare" } },
    { type = "spike", x = 120, y = 160, props = {} },
    { type = "exit_zone", x = 420, y = 0, props = { gemsRequired = 3 } },
  },
}

-- ---------------------------------------------------------------- saves ----
sample.save = S.save.new{
  dir = "saves/gemhaul",
  version = 1,
  migrations = {},
}

function sample.loadStats()
  local stats = sample.save:read("stats")
  if not stats then
    stats = { totalGems = 0, bestScore = 0, runs = 0, wins = 0 }
  end
  stats.totalGems = stats.totalGems or 0
  stats.bestScore = stats.bestScore or 0
  stats.runs = stats.runs or 0
  stats.wins = stats.wins or 0
  return stats
end

function sample.commitRun(result)
  local stats = sample.loadStats()
  stats.runs = stats.runs + 1
  if result.win then stats.wins = stats.wins + 1 end
  stats.totalGems = stats.totalGems + (result.gems or 0)
  if (result.score or 0) > stats.bestScore then stats.bestScore = result.score end
  stats.lastPlayed = os.time()
  sample.save:write("stats", stats)
  return stats
end

-- --------------------------------------------------------------- offline ----
-- away earnings: the game's real action loop (one gem per secondsPerGem of
-- away time) re-run by content/offline.advance — efficiency-scaled, capped,
-- and silent below minSeconds. Tuning is snapshot-gated in the suite.
sample.OFFLINE = {
  secondsPerGem = 30,
  efficiency = 0.6,
  minSeconds = 60,
  maxActions = 2000,
}

function sample.formatAway(seconds)
  if seconds < 120 then
    return string.format("%ds", seconds)
  elseif seconds < 7200 then
    return string.format("%dm", math.floor(seconds / 60))
  end
  return string.format("%.1fh", seconds / 3600)
end

-- settles away earnings since the last save; returns the report (or nil when
-- the absence is below minSeconds / first boot) and toasts through i18n
function sample.settleAway(ui)
  local stats = sample.loadStats()
  local now = os.time()
  local away = stats.lastPlayed and (now - stats.lastPlayed) or 0
  stats.lastPlayed = now
  local report
  if away >= sample.OFFLINE.minSeconds then
    report = sample.D.offline.advance(away, sample.OFFLINE, function()
      stats.totalGems = stats.totalGems + 1
      return sample.OFFLINE.secondsPerGem
    end)
    report.away = away
    report.gems = report.actions
    if ui and report.gems > 0 then
      ui:toast(sample.i18n:t("toast.away", report.gems, sample.formatAway(away)))
    end
  end
  sample.save:write("stats", stats)
  return report
end

-- ---------------------------------------------------------------- assets ----
-- the committed sample/assets page (generated by tools/assetgen.lua); the
-- manifest ratchet test keeps it in sync with disk in both directions
sample.ASSET_MANIFEST = {
  atlas = { src = "sample/assets/atlas.png" },
  layout = { src = "sample/assets/layout.lua" },
  select_sfx = { src = "sample/assets/select.wav" },
}

-- file-backed sfx (the committed wav); the nil contract keeps scenes safe
-- when a clip or the whole asset dir is missing
sample.audio = S.audio.new{ dirs = { "sample/assets" } }

-- ------------------------------------------------------------ milestones ----
-- derived unlocks over lifetime stats: store the stat, derive the unlock
sample.MILESTONES = {
  { id = "g10", labelKey = "milestone.g10", stat = "totalGems", at = 10 },
  { id = "g25", labelKey = "milestone.g25", stat = "totalGems", at = 25 },
  { id = "w1", labelKey = "milestone.w1", stat = "wins", at = 1 },
}

function sample.checkMilestones(ui)
  local stats = sample.loadStats()
  if not sample.ladder then
    sample.ladder = S.milestones.new(sample.MILESTONES, stats)
  else
    sample.ladder.stats = stats
  end
  local crossed = sample.ladder:check()
  for _, entry in ipairs(crossed) do
    if ui then ui:toast(sample.i18n:t("toast.unlocked", sample.i18n:t(entry.labelKey))) end
  end
  return crossed
end

-- ------------------------------------------------------------- launcher ----
function sample.register()
  S.scene.register("gh_menu", require("sample.menu"))
  S.scene.register("gh_game", require("sample.game"))
  S.scene.register("gh_results", require("sample.results"))
end

function sample.start()
  sample.register()
  S.scene.clear()
  S.scene.push("gh_menu")
end

sample.lastResult = nil

return sample
