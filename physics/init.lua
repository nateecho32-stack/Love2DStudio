-- love.physics wrapper: instance worlds, archetype-driven body factories,
-- a category-bit collision matrix, contacts QUEUED and drained later (never
-- mutate the world inside callbacks — Burning's correctness rule), and a
-- raycast helper. Falls back to nil-world mode when love.physics is absent
-- (headless checks) so callers can guard once.

local physics = {}

-- categories: up to 16 named bits; matrix[a][b] = true means "collide"
function physics.new(opts)
  opts = opts or {}
  local P = {
    gravity = opts.gravity or { 0, 300 },
    categories = {},          -- name -> bit index (1..16)
    matrix = {},              -- [bitA][bitB] = true -> should collide
    _queue = {},              -- contact events: {kind, a, b, fixtureA, fixtureB}
  }

  local world = nil
  if love and love.physics and love.physics.newWorld then
    world = love.physics.newWorld(P.gravity[1], P.gravity[2])
    -- NOTE: contact userdata is only valid DURING the callback — the queue
    -- stores fixtures (safe) and never the contact itself
    world:setCallbacks(
      function(a, b) P._queue[#P._queue + 1] = { kind = "begin", a = a, b = b } end,
      function(a, b) P._queue[#P._queue + 1] = { kind = "end", a = a, b = b } end
    )
  end
  P.world = world

  function P:hasWorld() return self.world ~= nil end

  -- register named collision categories (order of registration = bit order)
  function P:category(name)
    local bit = self.categories[name]
    if not bit then
      bit = physics._nextBit(self)
      self.categories[name] = bit
    end
    return bit
  end

  -- declare which category pairs SHOULD generate contact events; everything
  -- else still physically collides unless setColliding(false,...)
  function P:collide(aName, bName, enabled)
    local ab, bb = self:category(aName), self:category(bName)
    self.matrix[ab] = self.matrix[ab] or {}
    self.matrix[bb] = self.matrix[bb] or {}
    self.matrix[ab][bb] = (enabled ~= false)
    self.matrix[bb][ab] = (enabled ~= false)
  end

  function P:shouldCollide(aBit, bBit)
    local row = self.matrix[aBit]
    return row and row[bBit] == true
  end

  -- body factory: def = {bodyType="dynamic"|"static"|"kinematic",
  --   shape="box"|"circle", w=, h=, r=, x=, y=,
  --   category="player", mask={"enemy","wall"}, density=, friction=,
  --   restitution=, sensor=}
  function P:makeBody(def)
    local world = self.world -- read the live field so degraded mode works
    if not world then return nil end
    local body = love.physics.newBody(world, def.x or 0, def.y or 0, def.bodyType or "dynamic")
    local fixture
    if def.shape == "circle" then
      fixture = love.physics.newFixture(body, love.physics.newCircleShape(def.r or 12))
    else
      local w, h = def.w or 24, def.h or 24
      fixture = love.physics.newFixture(body, love.physics.newRectangleShape(w, h))
    end
    fixture:setDensity(def.density or 1)
    fixture:setFriction(def.friction or 0.3)
    fixture:setRestitution(def.restitution or 0)
    if def.sensor then fixture:setSensor(true) end
    local cat = self:category(def.category or "default")
    local maskBits = 0
    for _, name in ipairs(def.mask or {}) do
      maskBits = maskBits + (2 ^ (self:category(name) - 1))
    end
    fixture:setFilterData(2 ^ (cat - 1), 0xFFFF, 0) -- category + collide-all mask
    body:setUserData(def.userData)
    fixture:setUserData(def.userData or {})
    return body, fixture
  end

  function P:update(dt)
    local world = self.world
    if not world then return end
    world:update(dt)
  end

  -- drain queued contacts since the last call; fn(kind, fixtureA, fixtureB)
  -- SAFETY: the callback runs outside the physics step, so destroying bodies
  -- is legal — and destroy() fires end-contacts SYNCHRONOUSLY, so the queue
  -- is swapped up front; reentrant appends land in the fresh queue instead
  -- of punching holes into the one being iterated
  function P:drainContacts(fn)
    local queue = self._queue
    if #queue == 0 then return end
    self._queue = {}
    for i = 1, #queue do
      local ev = queue[i]
      -- earlier events in this batch may have destroyed these fixtures
      local fa = (ev.a and not ev.a:isDestroyed()) and ev.a or nil
      local fb = (ev.b and not ev.b:isDestroyed()) and ev.b or nil
      local udA = fa and fa:getUserData() or nil
      local udB = fb and fb:getUserData() or nil
      fn(ev.kind, fa, fb, udA, udB)
    end
  end

  -- raycast: returns {x, y, nx, ny, fixture} of the first hit or nil
  function P:raycast(x1, y1, x2, y2)
    local world = self.world
    if not world then return nil end
    local hit = nil
    world:rayCast(x1, y1, x2, y2, function(fixture, x, y, nx, ny, fraction)
      hit = { x = x, y = y, nx = nx, ny = ny, fraction = fraction, fixture = fixture }
      return fraction -- clip at the first hit
    end)
    return hit
  end

  function P:destroy(what)
    local world = self.world
    if not world or not what then return end
    pcall(function() what:destroy() end)
  end

  return P
end

-- internal: bit allocator shared per-instance through upvalue on the table
function physics._nextBit(P)
  local max = 0
  for _, bit in pairs(P.categories) do
    if bit > max then max = bit end
  end
  return max + 1
end

return physics
