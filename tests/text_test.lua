local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local text = R("render.text")

local function font()
  if love and love.graphics then return love.graphics.newFont(12) end
  return { getWidth = function() return 6 end }
end

T.case("text: becomes done after its duration", function()
  local t = text.new("hi", font(), { stagger = 0.04 })
  T.isTrue(not t:done())
  t:update(1)
  T.isTrue(t:done())
end)

T.case("text: utf8 strings split into characters, not bytes", function()
  local t = text.new("héllo", font())
  T.eq(#t.chars, 5)
end)

T.case("text: width sums character widths", function()
  local f = font()
  local t = text.new("abc", f)
  T.eq(t:width(), f:getWidth("a") + f:getWidth("b") + f:getWidth("c"))
end)

T.case("text: draw runs without error (drop-in animation)", function()
  if not (love and love.graphics) then return end
  local t = text.new("abc", love.graphics.newFont(12))
  local ok = pcall(function()
    love.graphics.setCanvas(love.graphics.newCanvas(64, 64))
    for _ = 1, 30 do
      t:update(1 / 60)
      t:draw(4, 4)
    end
    love.graphics.setCanvas()
  end)
  T.isTrue(ok, "text draw raised")
end)
