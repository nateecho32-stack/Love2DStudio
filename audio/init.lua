-- Audio manager: volume buses, SFX family resolver (<dir>/<family>/<name>),
-- file variants (_2.._4, random pick), _default fallback, per-clip makeup
-- gain (AI loudness variance), and pitch variance on play. Resolution rules
-- from 2d Trippy Hell game/systems/core/audio.lua; synth from audio/synth.lua.

local root = (...):match("^(.-)audio%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local synth = R("audio.synth")

local EXT_PRIORITY = { ".ogg", ".mp3", ".wav", ".flac" }
local MAX_VARIANTS = 4

local audio = {}

-- opts: { dirs = {"assets/sfx"}, clipGain = {["ui/click"] = 1.4},
--         buses = {master=1, music=1, sfx=1, ambient=1},
--         fs = {exists(path)}, newSource = fn(path, mode), random = fn }
function audio.new(opts)
  opts = opts or {}
  local A = {
    dirs = opts.dirs or { "assets/sfx" },
    clipGain = opts.clipGain or {},
    buses = {
      master = 1, music = 1, sfx = 1, ambient = 1,
    },
    musicSource = nil,
    _resolved = {},  -- base name -> exact path (without variant suffix)
    _sources = {},   -- base name -> baked Source (cloned per play)
    fs = opts.fs,
    newSource = opts.newSource or function(path, mode) return love.audio.newSource(path, mode) end,
    random = opts.random or function() return love and love.math and love.math.random() or 0.5 end,
  }
  for k, v in pairs(opts.buses or {}) do A.buses[k] = v end

  local function exists(path)
    if A.fs then return A.fs.exists(path) end
    if love and love.filesystem then
      local info = love.filesystem.getInfo(path)
      return info ~= nil
    end
    return false
  end

  -- resolves "family/name" to ALL existing variants of the newest ext found
  -- (base, _2.._4); play() picks among them randomly, music uses [1]
  function A:resolveAll(name)
    local cached = self._resolved[name]
    if cached then return cached end
    local stem = name:match("^(.+)%.[%w]+$") or name -- drop an explicit ext
    for _, dir in ipairs(self.dirs) do
      local folder = dir .. "/" .. stem
      for _, ext in ipairs(EXT_PRIORITY) do
        local variants = {}
        local base = folder .. ext
        if exists(base) then variants[#variants + 1] = base end
        for v = 2, MAX_VARIANTS do
          local variant = folder .. "_" .. v .. ext
          if exists(variant) then variants[#variants + 1] = variant end
        end
        if #variants > 0 then
          self._resolved[name] = variants
          return variants
        end
      end
      local fallback = dir .. "/" .. (stem:match("^(.*)/[^/]+$") and stem:gsub("[^/]+$", "_default") or "_default")
      for _, ext in ipairs(EXT_PRIORITY) do
        if exists(fallback .. ext) then
          self._resolved[name] = { fallback .. ext }
          return self._resolved[name]
        end
      end
    end
    return nil -- the nil contract: caller falls back (e.g. synth), never crashes
  end

  function A:resolve(name)
    local variants = self:resolveAll(name)
    return variants and variants[1] or nil
  end

  function A:play(name, opts)
    opts = opts or {}
    local variants = self:resolveAll(name)
    if not variants then return nil, "unresolved: " .. name end
    local path = variants[1]
    if #variants > 1 then
      path = variants[math.max(1, math.ceil(self.random() * #variants))]
    end
    local source = self.newSource(path, "static")
    local bus = self.buses[(opts.bus or "sfx")]
    local gain = (bus or 1) * (self.clipGain[name] or 1) * (opts.volume or 1)
    source:setVolume(math.min(1, gain))
    local variance = opts.pitchVariance
    if variance and self.random then
      source:setPitch(1 + (self.random() * 2 - 1) * variance)
    elseif opts.pitch then
      source:setPitch(opts.pitch)
    end
    source:play()
    return source
  end

  -- loops a music source through the music bus; replaces the previous one
  function A:playMusic(name, opts)
    opts = opts or {}
    if self.musicSource then
      pcall(self.musicSource.stop, self.musicSource)
      self.musicSource = nil
    end
    local path = self:resolve(name)
    if not path then return nil, "unresolved: " .. name end
    local source = self.newSource(path, "stream")
    source:setLoop(opts.loop ~= false)
    source:setVolume(self.buses.music * (self.buses.master or 1) * (opts.volume or 1))
    source:play()
    self.musicSource = source
    return source
  end

  function A:setBusVolume(bus, v)
    self.buses[bus] = math.min(1, math.max(0, v))
    if bus == "music" and self.musicSource then
      self.musicSource:setVolume(self.buses.music * (self.buses.master or 1))
    end
  end

  -- procedural fallbacks, routed through the sfx bus
  function A:tone(freq, dur, opts)
    opts = opts or {}
    local source = synth.sourceFrom(synth.toneData(freq, dur, opts))
    source:setVolume((self.buses.sfx or 1) * (self.buses.master or 1) * (opts.volume or 1))
    source:play()
    return source
  end

  return A
end

audio.synth = synth
return audio
