-- Asset gates: Gem Haul's committed sample/assets page must stay in sync
-- with its manifest (manifest_check, both directions), the shipped sfx must
-- clear the loudness gate, and the atlas+layout pair must load as a working
-- sprite set. Headless runs skip (real files need the real filesystem).

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local S = R("init")
local sample = R("sample.init")

T.case("gem haul assets: manifest matches disk in both directions", function()
  if not (love and love.filesystem) then return end
  local failures = S.manifest_check.run(sample.ASSET_MANIFEST, { watchDir = "sample/assets" })
  T.eq(failures, {})
end)

T.case("gem haul assets: shipped sfx clears the loudness gate", function()
  if not (love and love.sound) then return end
  local data = love.sound.newSoundData("sample/assets/select.wav")
  local ok, peakDb = S.loudness_gate.check(data, S.loudness_gate.thresholdDb)
  T.isTrue(ok, string.format("select.wav peaks at %.1f dBFS, gate is %d",
    peakDb, S.loudness_gate.thresholdDb))
end)

T.case("gem haul assets: atlas+layout pair loads as a sprite set", function()
  if not (love and love.graphics) then return end
  local layout = R("sample.assets.layout")
  T.isTrue(layout ~= nil and layout.player_1 ~= nil, "committed layout must parse")
  local image = love.graphics.newImage("sample/assets/atlas.png")
  local sprites = S.sprites.new{ layout = layout, image = image, defaultAnchor = "center" }
  -- every frame in the layout must resolve to a quad inside the page bounds
  for key, frame in pairs(layout) do
    local sprite = sprites:get(key)
    T.isTrue(sprite ~= nil, "frame " .. key .. " did not resolve")
    T.isTrue(frame.x + frame.w <= image:getWidth() and frame.y + frame.h <= image:getHeight(),
      "frame " .. key .. " escapes the atlas page")
  end
end)
