-- Adoption gate: Gem Haul's player-facing strings resolve through the i18n
-- registry and the lazy deps registry loads engines on demand (Pass F).

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local sample = R("sample.init")
local design = R("tools.design_test")
local scene = R("core.scene")
local input = R("core.input")

local function fakeBackend()
  return {
    keys = {},
    keyDown = function(self, k) return self.keys[k] == true end,
    gamepad = function() return nil end,
  }
end

-- stats isolation: point the game's save at an in-memory fs (same contract
-- as sample_test's) so nav runs never pollute real stats
local function fakeFs()
  local files = {}
  return {
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
    remove = function(path) files[path] = nil return true end,
    list = function(dir)
      local out = {}
      for path in pairs(files) do
        local name = path:match("^" .. dir .. "/(.+)$")
        if name then out[#out + 1] = name end
      end
      return out
    end,
  }
end

T.case("gem haul i18n: en locale covers every game string with exact text", function()
  local I = sample.i18n
  T.eq(I:t("menu.title"), "GEM HAUL")
  T.eq(I:t("menu.play"), "Play (Enter)")
  T.eq(I:t("menu.quit"), "Quit (Esc)")
  T.eq(I:t("menu.stats", 120, 40, 6, 2), "best 120 | lifetime gems 40 | runs 6 (2 wins)")
  T.eq(I:t("game.exit_open"), "EXIT")
  T.eq(I:t("game.exit_closed", 1, 3), "EXIT 1/3")
  T.eq(I:t("game.hud", 42, "♥♥♥", 2, 3, 80), "time 42   hearts ♥♥♥   gems 2/3   score 80")
  T.eq(I:t("game.help"), "wasd/arrows move — collect gems, reach the exit — F1 back to studio")
  T.eq(I:t("results.win"), "HAUL COMPLETE")
  T.eq(I:t("results.lose"), "HAUL FAILED")
  T.eq(I:t("results.score", 100, 3, 12.5), "score 100   gems 3   time left 12.5s")
  T.eq(I:t("results.new_best"), "NEW BEST")
  T.eq(I:t("results.again"), "Play Again (Enter)")
  T.eq(I:t("results.menu"), "Menu (Esc)")
  T.eq(I:t("toast.unlocked", "first win"), "UNLOCKED: first win")
end)

T.case("gem haul i18n: partial locale falls back to en, unknown key returns itself", function()
  local I = sample.i18n
  I:registerLocale("xx", { name = "Test", strings = { ["menu.title"] = "GEM TRANSPORT" } })
  I:setLocale("xx")
  T.eq(I:t("menu.title"), "GEM TRANSPORT")
  T.eq(I:t("menu.play"), "Play (Enter)", "missing key must fall back to en")
  T.eq(I:t("no.such.key"), "no.such.key", "unknown key must return itself")
  I:setLocale("zz") -- unregistered locale: refused
  T.eq(I:t("menu.title"), "GEM TRANSPORT", "locale must not change to an unregistered id")
  I:setLocale("en")
  T.eq(I:t("menu.title"), "GEM HAUL")
end)

T.case("gem haul milestones: labels resolve through the locale registry", function()
  for _, entry in ipairs(sample.MILESTONES) do
    T.isTrue(sample.i18n:t(entry.labelKey) ~= entry.labelKey,
      "milestone key must be registered: " .. tostring(entry.labelKey))
  end
  T.eq(sample.i18n:t("milestone.w1"), "first win")
end)

T.case("gem haul deps: engines load lazily on first access", function()
  T.isTrue(sample.D.i18n ~= nil and sample.D.isLoaded("i18n"), "i18n is eager")
  T.isTrue(sample.D.isLoaded("sprites") == false, "sprites must stay cold at boot")
  local sprites = sample.D.sprites
  T.isTrue(sprites ~= nil and type(sprites.new) == "function")
  T.isTrue(sample.D.isLoaded("sprites"), "first access must load and cache")
  T.isTrue(sample.D.isLoaded("atlas_pack") == false, "untouched keys stay cold")
  T.eq(sample.D.no_such_key, nil)
end)

T.case("gem haul chaser: routes around a wall instead of grinding into it", function()
  if not (love and love.physics) then return end
  sample.save._fs = fakeFs()
  sample.ladder = nil
  -- wall band across the chaser's direct line, walkable gaps above/below:
  -- a direct-seek chaser pins against the west wall face forever, a
  -- pathfinding one detours through a gap and still drains the player
  local layout = {
    version = 1, name = "chaser_nav",
    entities = {
      { type = "player_spawn", x = 200, y = 0, props = {} },
      { type = "wall", x = 0, y = -96, props = {} },
      { type = "wall", x = 0, y = -32, props = {} },
      { type = "wall", x = 0, y = 32, props = {} },
      { type = "wall", x = 0, y = 96, props = {} },
      { type = "exit_zone", x = 480, y = 0, props = { gemsRequired = 1 } },
    },
  }
  sample.register()
  scene.clear()
  scene.push("gh_game", { layout = layout })
  local gameScene = scene.top()
  local be = fakeBackend()
  input.clear()
  input.setBackend(be)
  input.define({
    left = { keys = { "left", "a" } }, right = { keys = { "right", "d" } },
    up = { keys = { "up", "w" } }, down = { keys = { "down", "s" } },
  })
  input.update()

  local lastState, crossedWall, detoured = nil, false, false
  for _ = 1, 1800 do
    input.update()
    scene.update(1 / 60)
    lastState = gameScene.hooks.state()
    if lastState.chaserX and lastState.chaserX > 30 then crossedWall = true end
    if math.abs(lastState.chaserY or 0) > 140 then detoured = true end
    if lastState.finished then break end
  end
  T.isTrue(detoured, "the chaser must leave the direct line to find a gap")
  T.isTrue(crossedWall, "the chaser must get past the wall line (direct seek pins at x=-36)")
  T.isTrue(lastState.finished, "the detour must still end in contact (hearts drain)")
  T.eq(lastState.hearts, 0)
  scene.clear()
end)

T.case("gem haul atlas chain: bake -> quads -> animated player frame + hitflash", function()
  if not (love and love.graphics) then return end
  sample.save._fs = fakeFs()
  sample.ladder = nil
  sample.register()
  scene.clear()
  scene.push("gh_game", { layout = sample.DEFAULT_LAYOUT })
  local gameScene = scene.top()
  local be = fakeBackend()
  input.clear()
  input.setBackend(be)
  input.define({
    left = { keys = { "left", "a" } }, right = { keys = { "right", "d" } },
    up = { keys = { "up", "w" } }, down = { keys = { "down", "s" } },
  })
  input.update()
  for _ = 1, 10 do input.update(); scene.update(1 / 60) end

  local atlas = gameScene.hooks.atlas()
  T.isTrue(atlas ~= nil and atlas.spr ~= nil, "atlas hook must surface the sprite set")
  T.isTrue(atlas.spr.image ~= nil, "the runtime atlas must be baked under real graphics")
  T.isTrue(atlas.spr.layout.player_1 ~= nil, "player frame must be in the packed layout")
  T.eq(atlas.playerFrame, "player_1")
  local sprite = atlas.spr:get("player_1")
  T.isTrue(sprite ~= nil and sprite.quad ~= nil)
  local f = sprite.frame
  local ok, drew = pcall(function()
    return atlas.shaders:hitFlash(atlas.spr.image, 0.8,
      { sprite.quad, 0, 0, 0, 1, 1, f.w / 2 + f.ox, f.h / 2 + f.oy })
  end)
  T.isTrue(ok, "hitflash draw raised")
  T.isTrue(type(drew) == "boolean", "hitflash must report which path it took")
  scene.clear()
end)

-- tuning snapshot: away-earnings balance cannot drift silently (AGENTS rule:
-- tuning configs go through design_test snapshots)
local OFFLINE_SNAPSHOT = {
  secondsPerGem = 30, efficiency = 0.6, minSeconds = 60, maxActions = 2000,
}
T.case("gem haul offline: tuning table matches its design_test snapshot", function()
  local ok, detail = design.assertUnchanged(sample.OFFLINE, OFFLINE_SNAPSHOT)
  T.isTrue(ok, detail)
end)

T.case("gem haul offline: away time grants efficiency-scaled gems, then nothing", function()
  sample.save._fs = fakeFs()
  sample.ladder = nil
  -- first boot: no lastPlayed -> nothing, but the stamp lands
  T.eq(sample.settleAway(nil), nil)
  T.isTrue(sample.loadStats().lastPlayed ~= nil, "first settle must stamp lastPlayed")
  -- one hour away -> floor(3600 * efficiency / secondsPerGem) gems
  local expected = math.floor(3600 * sample.OFFLINE.efficiency / sample.OFFLINE.secondsPerGem)
  local stats = sample.loadStats()
  stats.lastPlayed = os.time() - 3600
  sample.save:write("stats", stats)
  local report = sample.settleAway(nil)
  T.isTrue(report ~= nil, "an hour away must settle")
  T.eq(report.gems, expected)
  T.eq(report.actions, expected)
  T.isTrue(sample.loadStats().totalGems >= expected, "granted gems must persist")
  -- settling again immediately is below minSeconds: nil report, no gems
  local before = sample.loadStats().totalGems
  T.eq(sample.settleAway(nil), nil)
  T.eq(sample.loadStats().totalGems, before)
end)

T.case("gem haul archetypes: every schema carries the name string prop", function()
  local ARCHETYPES = R("sample.archetypes")
  for id, def in pairs(ARCHETYPES) do
    T.isTrue(def.schema.name ~= nil and def.schema.name.type == "string",
      id .. " must let the editor's name field survive validate into gameplay")
  end
end)
