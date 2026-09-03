-- Profiler overlay: rolling frame-time graph, fps, and named counters.
-- Pattern from Void Place tools/profiler.lua + Trippy performance.lua ideas.

local profiler = {}

function profiler.new(opts)
  opts = opts or {}
  local history = opts.history or 180
  local P = {
    history = {},
    max = 33.3,            -- graph scale in ms
    counters = {},
    clock = opts.clock or function() return love and love.timer.getTime() or 0 end,
    _t0 = nil,
    frameMs = 0,
    fps = 0,
    _fpsAccum = 0,
    _fpsFrames = 0,
    _fpsTimer = 0,
  }

  function P:beginFrame()
    self._t0 = self.clock()
  end

  function P:endFrame()
    if not self._t0 then return end
    local now = self.clock()
    self.frameMs = (now - self._t0) * 1000
    self._t0 = nil
    local h = self.history
    h[#h + 1] = self.frameMs
    if #h > history then table.remove(h, 1) end
    self._fpsAccum = self._fpsAccum + self.frameMs
    self._fpsFrames = self._fpsFrames + 1
    self._fpsTimer = self._fpsTimer + self.frameMs
    if self._fpsTimer >= 500 then
      self.fps = math.floor(self._fpsFrames * 1000 / self._fpsTimer + 0.5)
      self._fpsAccum, self._fpsFrames, self._fpsTimer = 0, 0, 0
    end
  end

  function P:counter(name, value)
    self.counters[name] = value
  end

  function P:p95()
    local sorted = {}
    for i = 1, #self.history do sorted[i] = self.history[i] end
    table.sort(sorted)
    if #sorted == 0 then return 0 end
    return sorted[math.max(1, math.ceil(#sorted * 0.95))]
  end

  -- HUD-space draw; call after the pipeline
  function P:draw(x, y, w, h)
    if not love or not love.graphics then return end
    w, h = w or 220, h or 48
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y, w, h)
    local barW = w / (opts.history or 180)
    for i = 1, #self.history do
      local ms = self.history[i]
      local barH = math.min(1, ms / self.max) * (h - 18)
      love.graphics.setColor(ms > 16.7 and 0.9 or 0.4, ms > 16.7 and 0.3 or 0.8, 0.4, 1)
      love.graphics.rectangle("fill", x + (i - 1) * barW, y + h - 14 - barH, math.max(1, barW - 1), barH)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("%d fps | %.1f ms | p95 %.1f ms", self.fps, self.frameMs, self:p95()), x + 4, y + 2)
    local cy = y + 16
    for name, value in pairs(self.counters) do
      love.graphics.print(name .. ": " .. tostring(value), x + 4, cy)
      cy = cy + 12
    end
  end

  return P
end

return profiler
