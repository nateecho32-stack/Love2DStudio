local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local audio = R("audio.init")

local function fakeSource(path)
  return {
    path = path, volume = 1, pitch = 1, played = 0, looping = false,
    setVolume = function(self, v) self.volume = v end,
    setPitch = function(self, p) self.pitch = p end,
    setLoop = function(self, l) self.looping = l end,
    play = function(self) self.played = self.played + 1 end,
    stop = function(self) self.played = 0 end,
  }
end

local function makeAudio(files, opts)
  opts = opts or {}
  return audio.new{
    dirs = opts.dirs or { "assets/sfx" },
    fs = { exists = function(p) return files[p] == true end }, -- dot-style calls
    newSource = fakeSource,
    random = function() return 0.5 end,
  }
end

T.case("audio: resolves family/name with the extension priority", function()
  local files = { ["assets/sfx/ui/click.ogg"] = true }
  local a = makeAudio(files)
  local src = a:play("ui/click")
  T.isTrue(src ~= nil)
  T.eq(src.path, "assets/sfx/ui/click.ogg")
end)

T.case("audio: prefers ogg over wav, then variants", function()
  local files = {
    ["assets/sfx/ui/click.wav"] = true,
    ["assets/sfx/ui/click.ogg"] = true,
  }
  local a = makeAudio(files)
  T.eq(a:resolve("ui/click"), "assets/sfx/ui/click.ogg")
end)

T.case("audio: variants _2.._4 resolve and play picks among them randomly", function()
  local files = {
    ["assets/sfx/e/hit.ogg"] = true,
    ["assets/sfx/e/hit_2.ogg"] = true,
    ["assets/sfx/e/hit_3.ogg"] = true,
  }
  local a = makeAudio(files)
  local variants = a:resolveAll("e/hit")
  T.eq(variants, {
    "assets/sfx/e/hit.ogg",
    "assets/sfx/e/hit_2.ogg",
    "assets/sfx/e/hit_3.ogg",
  })

  -- random=0.999 picks the last variant; random=0.001 the first
  a.random = function() return 0.999 end
  T.eq(a:play("e/hit").path, "assets/sfx/e/hit_3.ogg")
  a.random = function() return 0.001 end
  T.eq(a:play("e/hit").path, "assets/sfx/e/hit.ogg")
end)

T.case("audio: _default fallback when the exact clip is missing", function()
  local files = { ["assets/sfx/ui/_default.ogg"] = true }
  local a = makeAudio(files)
  T.eq(a:resolve("ui/whoosh"), "assets/sfx/ui/_default.ogg")
end)

T.case("audio: unresolved clips return nil (fallback contract)", function()
  local a = makeAudio({})
  local src, err = a:play("ui/nothing")
  T.isNil(src)
  T.isTrue(tostring(err):find("nothing", 1, true) ~= nil)
end)

T.case("audio: bus volumes and clip makeup gain combine", function()
  local files = { ["assets/sfx/ui/click.ogg"] = true }
  local a = makeAudio(files, {})
  a.clipGain["ui/click"] = 1.5
  a:setBusVolume("sfx", 0.5)
  local src = a:play("ui/click")
  T.near(src.volume, 0.75)
end)

T.case("audio: play routes through the named bus", function()
  local files = { ["assets/sfx/amb/wind.ogg"] = true }
  local a = makeAudio(files)
  a:setBusVolume("ambient", 0.25)
  a:setBusVolume("sfx", 1)
  local src = a:play("amb/wind", { bus = "ambient" })
  T.near(src.volume, 0.25)
end)

T.case("audio: pitch variance jitters around 1", function()
  local files = { ["assets/sfx/e/hit.ogg"] = true }
  local a = makeAudio(files)
  local src = a:play("e/hit", { pitchVariance = 0.05 })
  T.isTrue(src.pitch > 0.94 and src.pitch < 1.06)
end)

T.case("audio: playMusic swaps the music source through the music bus", function()
  local files = {
    ["assets/sfx/music/theme.ogg"] = true,
    ["assets/sfx/music/boss.ogg"] = true,
  }
  local a = makeAudio(files)
  local first = a:playMusic("music/theme")
  T.isTrue(first.looping)
  T.near(first.volume, 1)
  local second = a:playMusic("music/boss", { volume = 0.5 })
  T.near(second.volume, 0.5)
  T.eq(second.played, 1)
end)

T.case("audio: synth tone builds and plays without files", function()
  if not (love and love.sound and love.audio) then return end
  local a = makeAudio({})
  local src = a:tone(440, 0.05, { kind = "square", vol = 0.4 })
  T.isTrue(src ~= nil)
end)
