-- Logical-resolution viewport: letterbox scaling, optional integer scaling,
-- and screen<->logical coordinate mapping (mouse picking lives here).
-- Adapted from Vimur src/ui/viewport.lua + Burning src/render/renderer.lua.

local viewport = {}

function viewport.new(opts)
  opts = opts or {}
  local V = {
    width = opts.width or 1280,
    height = opts.height or 720,
    integerScale = opts.integerScale or false,
    -- default the window to the logical size so the viewport is correct even
    -- before the first resize
    winW = opts.winW or opts.width or 1280,
    winH = opts.winH or opts.height or 720,
  }

  function V:resize(w, h)
    self.winW, self.winH = w, h
  end

  function V:scale()
    local s = math.min(self.winW / self.width, self.winH / self.height)
    if self.integerScale then s = math.max(1, math.floor(s)) end
    return s
  end

  function V:offsets()
    local s = self:scale()
    return (self.winW - self.width * s) / 2, (self.winH - self.height * s) / 2
  end

  -- everything between apply/pop is drawn in logical coordinates
  function V:apply()
    love.graphics.push()
    local ox, oy = self:offsets()
    love.graphics.translate(ox, oy)
    local s = self:scale()
    love.graphics.scale(s, s)
  end

  function V:pop() love.graphics.pop() end

  function V:toLogical(sx, sy)
    local s = self:scale()
    local ox, oy = self:offsets()
    return (sx - ox) / s, (sy - oy) / s
  end

  function V:toScreen(lx, ly)
    local s = self:scale()
    local ox, oy = self:offsets()
    return lx * s + ox, ly * s + oy
  end

  function V:getMouse()
    local mx, my = love.mouse.getPosition()
    return self:toLogical(mx, my)
  end

  -- is a window-space point inside the letterboxed area?
  function V:contains(sx, sy)
    local lx, ly = self:toLogical(sx, sy)
    return lx >= 0 and lx < self.width and ly >= 0 and ly < self.height
  end

  return V
end

return viewport
