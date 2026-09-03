local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local proc = R("render.proc")

T.case("proc: glow image is generated and cached per key", function()
  if not (love and love.graphics) then return end
  local a = proc.glowImage(16, 2)
  local b = proc.glowImage(16, 2)
  T.eq(a, b)
  T.eq(a:getWidth(), 16)
  local c = proc.glowImage(32, 2)
  T.isTrue(c ~= a)
end)

T.case("proc: pixel image is 1x1", function()
  if not (love and love.graphics) then return end
  local img = proc.pixelImage()
  T.eq(img:getWidth(), 1)
  T.eq(img:getHeight(), 1)
end)

T.case("proc: cachedCanvas draws once until invalidated", function()
  if not (love and love.graphics) then return end
  local draws = 0
  local c = proc.cachedCanvas(8, 8, function()
    draws = draws + 1
  end)
  c:get()
  c:get()
  c:get()
  T.eq(draws, 1)
  c:invalidate()
  c:get()
  T.eq(draws, 2)
end)
