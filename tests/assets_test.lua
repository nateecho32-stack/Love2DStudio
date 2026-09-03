local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local assets = R("core.assets")

T.case("assets: onReady defers until ready(), then runs inline", function()
  assets.clear()
  local ran = 0
  assets.onReady(function() ran = ran + 1 end)
  T.eq(ran, 0)
  assets.ready()
  T.eq(ran, 1)
  assets.onReady(function() ran = ran + 1 end) -- after boot: runs immediately
  T.eq(ran, 2)
end)

T.case("assets: missing image returns nil (fallback contract), not an error", function()
  if not (love and love.graphics) then return end -- needs a graphics context
  local img = assets.image("definitely/missing_file.png")
  T.isNil(img)
end)

T.case("assets: default font loads and caches", function()
  if not (love and love.graphics) then return end
  assets.clear()
  local f1 = assets.font(nil, 12)
  local f2 = assets.font(nil, 12)
  T.isTrue(f1 ~= nil)
  T.eq(f1, f2)
end)
