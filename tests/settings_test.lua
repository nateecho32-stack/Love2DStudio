local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local settings = R("core.settings")

local function makeStudio()
  return settings.new({
    file = "settings.dat",
    version = 3,
    defaults = {
      video = { vsync = 1, preset = "high" },
      audio = { master = 0.8 },
      gameplay = { screenShake = 1, playerName = "player" },
    },
    rules = {
      ["video.vsync"] = { values = { 0, 1 } },
      ["video.preset"] = { values = { "off", "low", "high" } },
      ["audio.master"] = { min = 0, max = 1 },
      ["gameplay.screenShake"] = { min = 0, max = 2, integer = true },
      ["gameplay.playerName"] = { maxLen = 8, nonempty = true },
    },
  })
end

T.case("settings: defaults are the schema", function()
  local s = makeStudio()
  T.eq(s:get("video.vsync"), 1)
  T.eq(s:get("video.preset"), "high")
  T.eq(s:get("audio.master"), 0.8)
  T.isNil(s:get("nope.nada"))
end)

T.case("settings: set validates, clamps and rounds", function()
  local s = makeStudio()
  T.isNil(s:set("video.preset", "ultra"))            -- enum rejects
  T.isNil(s:set("video.vsync", 2))                   -- enum rejects numbers too
  T.isNil(s:set("audio.master", 0 / 0))              -- NaN rejected
  T.isNil(s:set("gameplay.playerName", ""))          -- nonempty

  T.isTrue(s:set("audio.master", 1.7))               -- clamped
  T.near(s:get("audio.master"), 1)

  T.isTrue(s:set("gameplay.screenShake", 1.6))       -- integer rule rounds
  T.eq(s:get("gameplay.screenShake"), 2)

  T.isTrue(s:set("gameplay.playerName", "0123456789"))
  T.eq(s:get("gameplay.playerName"), "01234567")     -- truncated to maxLen
end)

T.case("settings: serialize/load round-trips (defaults give the types)", function()
  local s = makeStudio()
  s:set("audio.master", 0.5)
  s:set("gameplay.playerName", "a=b\nc") -- escapes, short enough for maxLen
  s:set("video.vsync", 0)
  local blob = s:serialize()

  local s2 = makeStudio()
  local ok, accepted = s2:load(function() return blob end)
  T.isTrue(ok)
  T.near(s2:get("audio.master"), 0.5)
  T.eq(s2:get("gameplay.playerName"), "a=b\nc")
  T.eq(s2:get("video.vsync"), 0)
  T.eq(s2:get("gameplay.screenShake"), 1)            -- untouched default survives
end)

T.case("settings: unknown keys are dropped, wrong types fall back", function()
  local s = makeStudio()
  local blob = "version=1\nhacked=true\naudio.master=oops\nvideo.vsync=1\n"
  local ok, accepted = s:load(function() return blob end)
  T.isTrue(ok)
  T.eq(accepted, 1)                                  -- "oops" fails coercion; only vsync lands
  T.isNil(s:get("hacked"))
end)

T.case("settings: future-version guard refuses the file", function()
  local s = makeStudio()
  local ok, accepted, healed, fileVersion = s:load(function() return "version=99\naudio.master=0.1\n" end)
  T.isTrue(not ok)
  T.eq(fileVersion, 99)
  T.near(s:get("audio.master"), 0.8)                 -- defaults untouched
end)

T.case("settings: one-time heals fire for older files", function()
  local healed = 0
  local s = settings.new({
    file = "settings.dat",
    version = 3,
    defaults = { audio = { master = 0.8 } },
    heals = {
      { min = 2, fn = function(st) healed = healed + 1 st:set("audio.master", 0) end },
    },
  })
  s:load(function() return "version=1\naudio.master=0.9\n" end)
  T.eq(healed, 1)
  T.near(s:get("audio.master"), 0)

  -- same-version file: no heal
  local healed2 = 0
  local s2 = settings.new({
    version = 3,
    defaults = { audio = { master = 0.8 } },
    heals = { { min = 2, fn = function() healed2 = healed2 + 1 end } },
  })
  s2:load(function() return "version=3\n" end)
  T.eq(healed2, 0)
end)

T.case("settings: empty/missing file loads nothing", function()
  local s = makeStudio()
  local ok, accepted = s:load(function() return nil end)
  T.isTrue(not ok)
  T.eq(accepted, 0)
end)
