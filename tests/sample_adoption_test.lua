-- Adoption gate: Gem Haul's player-facing strings resolve through the i18n
-- registry and the lazy deps registry loads engines on demand (Pass F).

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local sample = R("sample.init")

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
