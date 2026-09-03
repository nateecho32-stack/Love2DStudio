-- Procedural SFX synth: games ship with zero audio files when they want.
-- Per-sample SoundData builders from Burning src/systems/audio.lua; tone
-- primitive from Dead Meridian / PVZ Gambling.

local M = { sampleRate = 44100 }

local function envelope(t, dur, attack, release)
  local a = attack or 0.005
  local r = release or 0.05
  if t < a then return t / a end
  if t > dur - r then
    local remain = dur - t
    if remain <= 0 then return 0 end
    return remain / r
  end
  return 1
end

local function sampleAt(phase, kind, rng)
  if kind == "square" then return phase % 1 < 0.5 and 0.8 or -0.8 end
  if kind == "saw" then return (phase % 1) * 2 - 1 end
  if kind == "triangle" then
    local p = phase % 1
    return p < 0.5 and (p * 4 - 1) or (3 - p * 4)
  end
  if kind == "noise" then return rng() * 2 - 1 end
  return math.sin(phase * 2 * math.pi) -- sine
end

-- opts: { kind = "sine"|"square"|"saw"|"triangle"|"noise", vol = 0.5,
--         sweepTo = freq, attack = 0.005, release = 0.05 }
function M.toneData(freq, dur, opts)
  opts = opts or {}
  local rate = M.sampleRate
  local n = math.max(1, math.floor(dur * rate))
  local data = love.sound.newSoundData(n, rate, 16, 1)
  local vol = opts.vol or 0.5
  local rng = opts.random or function() return love and love.math and love.math.random() or 0 end
  local phase = 0
  for i = 0, n - 1 do
    local t = i / rate
    local k = t / dur
    local f = freq
    if opts.sweepTo then f = freq + (opts.sweepTo - freq) * k end
    phase = phase + f / rate
    local env = envelope(t, dur, opts.attack, opts.release)
    data:setSample(i, sampleAt(phase, opts.kind, rng) * vol * env)
  end
  return data
end

-- Burning's escape hatch: fn(t01, i) -> sample (-1..1) renders any shape
function M.build(seconds, fn)
  local rate = M.sampleRate
  local n = math.max(1, math.floor(seconds * rate))
  local data = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do
    data:setSample(i, fn(i / rate, i))
  end
  return data
end

function M.sourceFrom(data)
  return love.audio.newSource(data, "static")
end

-- returns a played Source (call from love context; caller manages lifetime)
function M.tone(freq, dur, opts)
  return M.sourceFrom(M.toneData(freq, dur, opts))
end

return M
