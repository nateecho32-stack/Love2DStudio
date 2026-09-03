-- Animated text: per-character drop-in with stagger. Compact adaptation of
-- Void Place render/text.lua (markup/glow variants come in a later pass).

local text = {}

local function easeOutCubic(t)
  t = t - 1
  return 1 + t * t * t
end

function text.new(str, font, opts)
  opts = opts or {}
  local chars = {}
  local ok, utf8 = pcall(require, "utf8")
  if ok and utf8 then
    for _, code in utf8.codes(str) do chars[#chars + 1] = utf8.char(code) end
  else
    for i = 1, #str do chars[i] = str:sub(i, i) end
  end

  local delay = opts.delay or 0
  local stagger = opts.stagger or 0.04
  local T = {
    chars = chars,
    font = font,
    color = opts.color or { 1, 1, 1, 1 },
    drop = opts.drop ~= false,
    stagger = stagger,
    t = 0,
    duration = delay + #chars * stagger + 0.18,
  }

  function T:update(dt) self.t = self.t + dt end
  function T:done() return self.t >= self.duration end

  function T:width()
    local w = 0
    for i = 1, #self.chars do w = w + self.font:getWidth(self.chars[i]) end
    return w
  end

  function T:draw(x, y)
    love.graphics.setFont(self.font)
    local col = self.color
    local cx = x
    for i = 1, #self.chars do
      local ch = self.chars[i]
      local start = delay + (i - 1) * self.stagger
      local k = math.min(1, math.max(0, (self.t - start) / 0.18))
      if k > 0 then
        local yo = T.drop and -(1 - easeOutCubic(k)) * 24 or 0
        love.graphics.setColor(col[1], col[2], col[3], (col[4] or 1) * k)
        love.graphics.print(ch, cx, y + yo)
      end
      cx = cx + self.font:getWidth(ch)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  return T
end

return text
