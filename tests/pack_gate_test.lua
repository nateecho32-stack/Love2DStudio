local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local atlas = R("tools.atlas_pack")
local gate = R("tools.loudness_gate")
local synth = R("audio.synth")

local function frame(w, h, drawFn)
  local data = love.image.newImageData(w, h)
  drawFn(data)
  return data
end

T.case("atlas: trimBounds finds the opaque sub-rectangle", function()
  local data = frame(16, 16, function(d)
    for y = 4, 9 do
      for x = 6, 11 do d:setPixel(x, y, 255, 255, 255, 255) end
    end
  end)
  local x, y, w, h = atlas.trimBounds(data)
  T.eq(x, 6); T.eq(y, 4); T.eq(w, 6); T.eq(h, 6)
end)

T.case("atlas: fully transparent frame falls back to full bounds", function()
  local data = frame(8, 8, function() end)
  local x, y, w, h = atlas.trimBounds(data)
  T.eq(x, 0); T.eq(y, 0); T.eq(w, 8); T.eq(h, 8)
end)

T.case("atlas: pack produces a deterministic layout with trim offsets", function()
  if not (love and love.graphics) then return end
  local a = frame(8, 8, function(d)
    for y = 2, 5 do for x = 2, 5 do d:setPixel(x, y, 255, 0, 0, 255) end end
  end)
  local b = frame(8, 8, function(d)
    for y = 0, 7 do for x = 0, 7 do d:setPixel(x, y, 0, 255, 0, 255) end end
  end)
  local packed = atlas.pack({ b = b, a = a }) -- unordered pairs: layout must be deterministic
  T.eq(packed.layout.a.ox, 2)
  T.eq(packed.layout.a.oy, 2)
  T.eq(packed.layout.a.w, 4)
  T.eq(packed.layout.b.ox, 0) -- fully opaque frame trims to itself
  T.isTrue(packed.width >= 8)

  -- generated layout source parses back to the same table
  local src = atlas.layoutSource(packed.layout)
  local chunk = load(src, "layout", "t")
  if not chunk then chunk = load(src, "layout") end
  local decoded = chunk()
  T.eq(decoded.a.ox, 2)
  T.eq(decoded.b.w, 8)
  packed.image:release()
end)

T.case("atlas: packed canvas holds trimmed content at the cell origin", function()
  if not (love and love.graphics) then return end
  -- frame a: opaque rect at (2,2)-(5,5) in an 8x8 canvas — everything else
  -- is padding. The cell must start with CONTENT pixels; drawing the full
  -- frame there instead left quads sampling padding (caught by the Gem Haul
  -- adoption shot, Pass H).
  local a = frame(8, 8, function(d)
    for y = 2, 5 do for x = 2, 5 do d:setPixel(x, y, 255, 0, 0, 255) end end
  end)
  local b = frame(8, 8, function(d)
    for y = 0, 7 do for x = 0, 7 do d:setPixel(x, y, 0, 255, 0, 255) end end
  end)
  local packed = atlas.pack({ a = a, b = b }) -- b pads a's cell, giving slack to probe
  local f = packed.layout.a
  local img = packed.image:newImageData()
  for _, probe in ipairs({ { 0, 0 }, { f.w - 1, 0 }, { 0, f.h - 1 }, { f.w - 1, f.h - 1 } }) do
    local _, _, _, alpha = img:getPixel(f.x + probe[1], f.y + probe[2])
    T.isTrue(alpha > 0, "cell corner must be content, not padding")
  end
  -- and the padding ring just outside the content box must stay transparent
  local _, _, _, outsideA = img:getPixel(f.x + f.w, f.y + f.h)
  T.isTrue(outsideA == 0, "cell must not bleed past the trim box")
  packed.image:release()
end)

T.case("loudness gate: healthy clip passes, quiet clip fails", function()
  if not (love and love.sound) then return end
  local loud = synth.toneData(440, 0.1, { vol = 0.8 })
  local quiet = synth.build(0.1, function() return 0.001 end)
  local okLoud, peakLoud = gate.check(loud, -12)
  local okQuiet, peakQuiet = gate.check(quiet, -12)
  T.isTrue(okLoud, "0.8-amplitude tone must pass -12 dBFS")
  T.isTrue(peakLoud > -5)
  T.isTrue(not okQuiet)
  T.isTrue(peakQuiet < -12)
end)

T.case("loudness gate: silence fails with -999 dB", function()
  if not (love and love.sound) then return end
  local silence = synth.build(0.05, function() return 0 end)
  local ok, peakDb = gate.check(silence, -12)
  T.isTrue(not ok)
  T.near(peakDb, -999)
end)
