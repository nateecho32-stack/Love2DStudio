-- The render pipeline: world layers -> world canvas; point lights -> light
-- canvas; multiply composite into out; postfx to screen; HUD last in logical
-- space. Adapted from Void Place render/init.lua, Burning renderer.lua and
-- Trippy postfx.lua's beginCapture/endCapture/apply shape.

local pipeline = {}

function pipeline.new(opts)
  local P = {
    vp = assert(opts.viewport, "pipeline needs a viewport"),
    cam = opts.camera,
    lights = opts.lights,
    postfx = opts.postfx,
    lighting = (opts.lighting ~= false) and (opts.lights ~= nil),
    bgColor = opts.bgColor or { 0.05, 0.05, 0.07 },
    _layers = {},
    _huds = {},
    _canvases = nil,
  }

  local function insertSorted(list, item)
    local i = 1
    while i <= #list and list[i].order <= item.order do i = i + 1 end
    table.insert(list, i, item)
  end

  local function removeNamed(list, name)
    for i = 1, #list do
      if list[i].name == name then
        table.remove(list, i)
        return true
      end
    end
    return false
  end

  function P:addLayer(name, fn, order)
    self:removeLayer(name)
    insertSorted(self._layers, { name = name, fn = fn, order = order or 0 })
  end

  function P:removeLayer(name) return removeNamed(self._layers, name) end
  function P:addHud(name, fn, order)
    self:removeHud(name)
    insertSorted(self._huds, { name = name, fn = fn, order = order or 0 })
  end
  function P:removeHud(name) return removeNamed(self._huds, name) end

  function P:layerNames()
    local out = {}
    for i, l in ipairs(self._layers) do out[i] = l.name end
    return out
  end

  function P:canvases()
    if not self._canvases then
      local vp = self.vp
      self._canvases = {
        world = love.graphics.newCanvas(vp.width, vp.height),
        light = love.graphics.newCanvas(vp.width, vp.height),
        out = love.graphics.newCanvas(vp.width, vp.height),
      }
    end
    return self._canvases
  end

  function P:onResize()
    if self._canvases then
      for _, c in pairs(self._canvases) do pcall(c.release, c) end
      self._canvases = nil
    end
    if self.postfx then self.postfx:resize(self.vp.width, self.vp.height) end
  end

  -- after love.window.setMode the GPU objects are already gone; drop refs and
  -- rebuild (postfx shaders invalidate too)
  function P:onGraphicsReset()
    self._canvases = nil
    if self.postfx then self.postfx:invalidate() end
    self:onResize()
  end

  function P:draw()
    local vp, cam = self.vp, self.cam
    local c = self:canvases()

    -- 1. world layers (camera space)
    love.graphics.setCanvas(c.world)
    love.graphics.clear(P.bgColor[1], P.bgColor[2], P.bgColor[3], 1)
    love.graphics.setColor(1, 1, 1, 1)
    if cam then cam:apply(vp) end
    for i = 1, #self._layers do self._layers[i].fn() end
    if cam then cam:pop() end

    -- 2. lights (camera space, additive onto ambient base)
    if P.lighting and P.lights then
      love.graphics.setCanvas(c.light)
      local amb = P.lights.ambient
      love.graphics.clear(amb[1], amb[2], amb[3], 1)
      love.graphics.setColor(1, 1, 1, 1)
      if cam then cam:apply(vp) end
      P.lights:draw()
      if cam then cam:pop() end
    end

    -- 3. composite world x light -> out
    love.graphics.setCanvas(c.out)
    love.graphics.clear(0, 0, 0, 1)
    vp:apply()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c.world, 0, 0)
    if P.lighting and P.lights then
      love.graphics.setBlendMode("multiply", "premultiplied")
      love.graphics.draw(c.light, 0, 0)
      love.graphics.setBlendMode("alpha")
    end
    vp:pop()

    -- 4. postfx reads out and writes the real screen
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    if P.postfx then
      P.postfx:apply(c.out, vp)
    else
      vp:apply()
      love.graphics.draw(c.out, 0, 0)
      vp:pop()
    end

    -- 5. HUD last, in logical space (never gets world postfx)
    love.graphics.setColor(1, 1, 1, 1)
    vp:apply()
    for i = 1, #self._huds do self._huds[i].fn() end
    vp:pop()
  end

  return P
end

return pipeline
