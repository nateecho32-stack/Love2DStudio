-- Asset generator: emits Gem Haul's committed assets (atlas page, generated
-- layout, UI sfx) into the SAVE dir under sample/assets/ — copy them into the
-- repo afterwards (manual step, documented in TESTRUNS). Frame art comes from
-- sample/art.lua, the same source the runtime fallback bake uses, so the
-- committed page and the procedural shapes cannot drift.
-- Run: FRAMEWORK_CHECK=tools.assetgen lovec .

local root = (...):match("^(.-)tools%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local S = R("init")
local atlas = R("tools.atlas_pack")
local gate = R("tools.loudness_gate")
local synth = R("audio.synth")
local art = R("sample.art")

-- minimal 16-bit mono PCM wav writer (LÖVE has no SoundData encoder; the
-- synth fixtures are mono so that is all the pipeline needs)
local function wavBytes(soundData)
  local n = soundData:getSampleCount()
  local rate = soundData:getSampleRate()
  local channels = soundData.getChannelCount
    and soundData:getChannelCount() or soundData:getChannels()
  assert(channels == 1, "wav writer handles the mono synth fixtures only")
  local function u32(v)
    return string.char(v % 256, math.floor(v / 256) % 256,
      math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
  end
  local function u16(v)
    return string.char(v % 256, math.floor(v / 256) % 256)
  end
  local parts = { "RIFF", u32(36 + n * 2), "WAVEfmt ", u32(16), u16(1), u16(1),
    u32(rate), u32(rate * 2), u16(2), u16(16), "data", u32(n * 2) }
  for i = 0, n - 1 do
    local s = math.max(-1, math.min(1, soundData:getSample(i)))
    local v = math.floor(s * (s < 0 and 32768 or 32767))
    if v < 0 then v = v + 65536 end
    parts[#parts + 1] = string.char(v % 256, math.floor(v / 256))
  end
  return table.concat(parts)
end

local function run()
  local failures = 0
  if not (love and love.graphics and love.filesystem) then
    print("assetgen needs the LÖVE runtime")
    return 1
  end

  -- atlas page + generated layout from the shared frame art
  local packed = atlas.pack(art.frames())
  if not S.fsx.write("sample/assets/atlas.png", packed.image:newImageData():encode("png")) then
    print("assetgen: failed to write atlas.png")
    failures = failures + 1
  end
  if not S.fsx.write("sample/assets/layout.lua", atlas.layoutSource(packed.layout)) then
    print("assetgen: failed to write layout.lua")
    failures = failures + 1
  end
  packed.image:release()

  -- UI sfx: a short triangle blip, verified against the loudness gate BEFORE
  -- it ships (the same check the asset gate test reruns against the repo)
  local sfx = synth.toneData(660, 0.12, { kind = "triangle", vol = 0.6 })
  local ok, peakDb = gate.check(sfx, gate.thresholdDb)
  if not ok then
    print(string.format("assetgen: sfx too quiet (peak %.1f dBFS)", peakDb))
    failures = failures + 1
  end
  if not S.fsx.write("sample/assets/select.wav", wavBytes(sfx)) then
    print("assetgen: failed to write select.wav")
    failures = failures + 1
  end

  -- read back through the manifest the game ships, so a generator drift
  -- fails HERE instead of in the asset gate test
  local manifest = require("sample.init").ASSET_MANIFEST
  for key, entry in pairs(manifest) do
    local info = love.filesystem.getInfo("sample/assets/" .. entry.src:match("([^/]+)$"))
    if not info then
      print("assetgen: manifest entry did not land: " .. key)
      failures = failures + 1
    end
  end

  print(failures == 0 and "assetgen: sample/assets written to the save dir"
    or ("assetgen: %d failure(s)"):format(failures))
  return failures
end

return { run = run }
