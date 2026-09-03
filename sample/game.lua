-- Gem Haul gameplay: the reference consumer of the whole engine — physics,
-- entities/archetypes, triggers, loot values, milestones, fx, synth audio,
-- scene transitions, and editor-authored scene files. Copy this folder to
-- start a real game.

local root = (...) and ((...):match("^(.-)sample%.") or "") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local S = R("init")
local sample = R("sample.init")
local ARCHETYPES = R("sample.archetypes")
local art = R("sample.art")

local GEM_VALUE = { common = 10, rare = 30, epic = 50 }

local scene = {}
local R, F, E, U, PHYS, TR
local playerBody, chaserBody
local hearts, gems, gemsRequired, score, timeLeft, invuln
local finished
-- chaser navigation (Pass G): waypoints from A* over the wall grid
local CHASER_CELL = 32
local chaserPath, chaserRepath, chaserPassable
-- sprite chain (Pass H): runtime atlas + animators; empty atlas -> procedural
local SPR, SH, playerAnim, chaserAnim, gemAnims = nil, nil, nil, nil, {}

local function finish(win)
  if finished then return end
  finished = true
  local result = {
    win = win,
    gems = gems,
    score = win and (score + math.floor(timeLeft * 2)) or score,
    timeLeft = timeLeft,
  }
  sample.lastResult = result
  sample.commitRun(result)
  if S.game.audio then
    S.game.audio:tone(win and 520 or 200, 0.25,
      { kind = "triangle", vol = 0.15, sweepTo = win and 780 or 90 })
  end
  S.transitions.replace("gh_results", nil, { kind = "fade", dur = 0.45 })
end

local function spawnBodyFor(type, x, y, props)
  if type == "wall" then
    return PHYS:makeBody{ bodyType = "static", x = x, y = y, w = 48, h = 48,
      category = "wall", userData = { kind = "wall" } }
  elseif type == "gem" then
    return PHYS:makeBody{ bodyType = "static", x = x, y = y, shape = "circle", r = 9,
      category = "pickup", sensor = true, userData = { kind = "gem" } }
  elseif type == "spike" then
    return PHYS:makeBody{ bodyType = "static", x = x, y = y, shape = "circle", r = 11,
      category = "hazard", sensor = true, userData = { kind = "spike" } }
  end
  return nil
end

local function drawWorld()
  -- editor content: gems through the sprite chain (animator fallbacks keep
  -- the procedural shapes); walls/spikes/exit stay inline (flat rects and a
  -- live text label gain nothing from an atlas)
  E.ecs:each("transform", function(id, transform)
    local arch = E.ecs:get(id, "archetype")
    if not arch then return end
    local def = ARCHETYPES[arch.id]
    if not def then return end
    local s = transform.scale or 1
    if arch.id == "gem" then
      local bob = math.sin((love.timer.getTime or function() return 0 end)() * 3 + id) * 3
      local anim = gemAnims[id]
      if not anim then
        anim = sample.D.sprites.animator(SPR)
        anim.fallback = function(fx, fy)
          love.graphics.setColor(def.tint[1], def.tint[2], def.tint[3], 0.9)
          love.graphics.circle("fill", fx, fy, def.size.w / 2)
          love.graphics.setColor(1, 1, 1, 0.7)
          love.graphics.circle("line", fx, fy, def.size.w / 2)
        end
        anim:play("gem_spin")
        anim.t = (id % 7) * 0.09 -- desync phases across gems
        gemAnims[id] = anim
      end
      anim:draw(transform.x, transform.y + bob)
    elseif arch.id == "exit_zone" then
      local open = gems >= gemsRequired
      love.graphics.setColor(def.tint[1], def.tint[2], def.tint[3], open and 0.9 or 0.25)
      love.graphics.rectangle("fill", transform.x - def.size.w / 2, transform.y - def.size.h / 2,
        def.size.w, def.size.h)
      love.graphics.setColor(1, 1, 1, open and 1 or 0.4)
      love.graphics.print(open and sample.i18n:t("game.exit_open")
        or sample.i18n:t("game.exit_closed", gems, gemsRequired),
        transform.x - 26, transform.y - 34)
    else
      love.graphics.setColor(def.tint[1], def.tint[2], def.tint[3], 1)
      love.graphics.rectangle("fill", transform.x - def.size.w / 2, transform.y - def.size.h / 2,
        def.size.w * s, def.size.h * s)
    end
  end)

  -- the player (physics-driven): sprite frame when the atlas is live, with
  -- the invuln blink upgraded to the hitflash shader (CPU blink kept as the
  -- shaderless fallback)
  if playerBody then
    local frameKey = playerAnim and playerAnim:frame()
    local sprite = frameKey and SPR and SPR:get(frameKey)
    if sprite then
      local f = sprite.frame
      local px, py = playerBody:getX(), playerBody:getY()
      local drawArgs = { sprite.quad, px, py, 0, 1, 1, f.w / 2, f.h / 2 }
      local flashK = invuln > 0 and (0.55 + 0.45 * math.sin(invuln * 24)) or 0
      if flashK > 0 and SH then
        if not SH:hitFlash(SPR.image, flashK, drawArgs) then
          love.graphics.setColor(1, 1, 1, 0.4)
          love.graphics.circle("fill", px, py, 13)
        end
      else
        love.graphics.draw(SPR.image, unpack(drawArgs))
      end
    else
      local flash = invuln > 0 and (math.floor(invuln * 10) % 2 == 0) or false
      love.graphics.setColor(flash and { 1, 1, 1, 0.4 } or { 0.95, 0.65, 0.25, 1 })
      love.graphics.circle("fill", playerBody:getX(), playerBody:getY(), 13)
    end
  end
  -- the chaser
  if chaserBody then
    chaserAnim:draw(chaserBody:getX(), chaserBody:getY())
  end
  F:drawWorld()
end

local function drawHud()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(sample.i18n:t("game.hud",
    timeLeft, ("♥"):rep(hearts), gems, gemsRequired, score), 14, 10)
  love.graphics.print(sample.i18n:t("game.help"), 14, 30)
end

function scene.enter(args)
  args = args or {}
  R = S.render.new{ width = 1280, height = 720, lighting = false, postfx = "off" }
  E = S.entities.new{ ecs = S.ecs.new() }
  for id, def in pairs(ARCHETYPES) do E:define(id, def) end
  F = S.fx.new{
    camera = R.camera, time = S.time, particles = R.particles,
    timers = S.timer, font = S.assets.font(nil, 12),
  }
  U = S.ui.new{ font = S.assets.font(nil, 13) }
  PHYS = S.physics.new{ gravity = { 0, 0 } } -- top-down
  PHYS:collide("player", "pickup")
  PHYS:collide("player", "hazard")
  TR = S.triggers.new(E.ecs, { bus = S.bus })

  -- level: an explicit layout (tests), the editor's file when present, or
  -- the built-in default
  local data = args.layout or S.scenedata.loadFromFile(sample.SCENE_FILE)
  if not data then data = sample.DEFAULT_LAYOUT end
  E:deserialize(data.entities or data)

  hearts, gems, score, timeLeft = 3, 0, 0, 60
  finished = false
  invuln = 0
  gemsRequired = 3

  -- build physics + triggers from the deserialized entities
  local spawnX, spawnY = 0, 0
  local wallRects = {}
  E.ecs:each("transform", function(id, transform)
    local arch = E.ecs:get(id, "archetype")
    if not arch then return end
    if arch.id == "player_spawn" then
      spawnX, spawnY = transform.x, transform.y
      E.ecs:destroy(id)
    elseif arch.id == "exit_zone" then
      gemsRequired = arch.props.gemsRequired or 3
      E.ecs:add(id, "trigger", {
        w = ARCHETYPES.exit_zone.size.w, h = ARCHETYPES.exit_zone.size.h,
        onEnter = function()
          if gems >= gemsRequired then finish(true) end
        end,
      })
    else
      if arch.id == "wall" then
        wallRects[#wallRects + 1] = { x = transform.x, y = transform.y }
      end
      local body = spawnBodyFor(arch.id, transform.x, transform.y, arch.props)
      if body then
        E.ecs:add(id, "body", { ref = body })
        if arch.id == "gem" or arch.id == "spike" then
          -- remember which entity each sensor belongs to
          local fx = body:getFixtures()[1]
          local ud = fx:getUserData()
          ud.entityId = id
          fx:setUserData(ud)
        end
      end
    end
  end)
  E.ecs:update(0) -- sweep the destroyed spawn markers

  -- chaser navigation grid: rasterize the walls into coarse blocked cells,
  -- inflated by the chaser's radius so A* paths keep the body clear of corners
  local blocked = {}
  for _, r in ipairs(wallRects) do
    local x0 = r.x - 24 - 14
    local x1 = r.x + 24 + 14
    local y0 = r.y - 24 - 14
    local y1 = r.y + 24 + 14
    for cy = math.floor(y0 / CHASER_CELL), math.floor(y1 / CHASER_CELL) do
      for cx = math.floor(x0 / CHASER_CELL), math.floor(x1 / CHASER_CELL) do
        local px, py = cx * CHASER_CELL + CHASER_CELL / 2, cy * CHASER_CELL + CHASER_CELL / 2
        if px >= x0 and px <= x1 and py >= y0 and py <= y1 then
          blocked[cx .. "," .. cy] = true
        end
      end
    end
  end
  chaserPassable = function(cx, cy) return not blocked[cx .. "," .. cy] end
  chaserPath, chaserRepath = nil, 0

  -- Pass H: bake the procedural art into a runtime atlas so the game consumes
  -- the full asset chain (atlas_pack -> sprites/animator). pcall-guarded: any
  -- failure leaves the atlas empty and drawWorld's animator fallbacks (the
  -- same inline shapes as before) take over — the nil-return contract.
  gemAnims = {}
  SPR = sample.D.sprites.new{ defaultAnchor = "center" }
  SH = sample.D.shaders.new()
  SPR:registerClip("player_idle", { frames = { "player_1" }, fps = 4 })
  SPR:registerClip("chaser_move", { frames = { "chaser_1", "chaser_2" }, fps = 6 })
  SPR:registerClip("gem_spin", { frames = { "gem_1", "gem_2", "gem_3", "gem_4" }, fps = 6 })
  -- prefer the committed atlas (ships in the .love); re-bake at runtime when
  -- it is missing or stale, and fall back to the inline shapes when both fail
  local okAtlas = pcall(function()
    local layout = R("sample.assets.layout")
    assert(layout and layout.player_1 and layout.gem_4, "committed layout missing frames")
    SPR.layout = layout
    SPR:setImage(love.graphics.newImage("sample/assets/atlas.png"))
  end)
  if not okAtlas then
    local okBake, bakeErr = pcall(function()
      local packed = sample.D.atlas_pack.pack(art.frames())
      SPR.layout = packed.layout
      SPR:setImage(packed.image)
    end)
    if not okBake then
      S.log.warn("sample atlas unavailable, procedural shapes only: %s", tostring(bakeErr))
    end
  end
  playerAnim = sample.D.sprites.animator(SPR)
  playerAnim.fallback = function(fx, fy)
    love.graphics.setColor(0.95, 0.65, 0.25, 1)
    love.graphics.circle("fill", fx, fy, 13)
  end
  playerAnim:play("player_idle")
  chaserAnim = sample.D.sprites.animator(SPR)
  chaserAnim.fallback = function(fx, fy)
    love.graphics.setColor(0.85, 0.3, 0.4, 1)
    love.graphics.circle("fill", fx, fy, 12)
  end
  chaserAnim:play("chaser_move")

  playerBody = PHYS:makeBody{ bodyType = "dynamic", x = spawnX, y = spawnY,
    shape = "circle", r = 13, category = "player", friction = 0,
    restitution = 0, userData = { kind = "player" } }
  playerBody:setLinearDamping(3)
  -- the chaser starts BEHIND the spawn so a committed runner outruns it
  chaserBody = PHYS:makeBody{ bodyType = "dynamic", x = spawnX - 260, y = spawnY + 30,
    shape = "circle", r = 12, category = "hazard", userData = { kind = "chaser" } }

  R.camera:moveTo(spawnX, spawnY)
  R.pipeline:addLayer("world", drawWorld, 0)
  R.pipeline:addLayer("particles", function() R.particles:draw() end, 5)
  R.pipeline:addHud("hud", drawHud, 0)
  R:resize(love.graphics.getDimensions())

  S.input.define({
    left  = { keys = { "left", "a" }, buttons = { "dpleft" } },
    right = { keys = { "right", "d" }, buttons = { "dpright" } },
    up    = { keys = { "up", "w" }, buttons = { "dpup" } },
    down  = { keys = { "down", "s" }, buttons = { "dpdown" } },
  })
end

local function hurt(x, y, fromX, fromY)
  if finished or not playerBody then return end
  -- knockback on EVERY hazard contact so overlapping bodies always separate
  -- (a persistent overlap fires begin only once)
  local dx, dy = x - fromX, y - fromY
  local len = math.max(1, math.sqrt(dx * dx + dy * dy))
  playerBody:applyLinearImpulse(dx / len * 260, dy / len * 260)
  if invuln > 0 then return end
  hearts = hearts - 1
  invuln = 1.2
  F:play("hit", x, y)
  R.camera:shake(8, 0.25)
  if S.game.audio then
    S.game.audio:tone(160, 0.12, { kind = "square", vol = 0.15, sweepTo = 60 })
  end
  if hearts <= 0 then
    finish(false)
  end
end

function scene.update(dt)
  if finished then return end
  timeLeft = timeLeft - dt
  invuln = math.max(0, invuln - dt)
  if timeLeft <= 0 then
    finish(false)
    return
  end

  -- player steering (held back during invuln so knockback can separate the
  -- bodies — a continuous overlap only fires begin once)
  if playerBody and invuln <= 0 then
    local vx = (S.input.down("right") and 1 or 0) - (S.input.down("left") and 1 or 0)
    local vy = (S.input.down("down") and 1 or 0) - (S.input.down("up") and 1 or 0)
    local len = math.sqrt(vx * vx + vy * vy)
    if len > 0 then vx, vy = vx / len, vy / len end
    playerBody:setLinearVelocity(vx * 260, vy * 260)
  end
  if playerBody then
    TR:watch("player", playerBody:getX(), playerBody:getY())
  end

  -- chaser seek: A* waypoints around walls, repathing on a cadence; direct
  -- seek as the fallback when the path is exhausted or no route exists
  if chaserBody and playerBody then
    chaserRepath = chaserRepath - dt
    if chaserRepath <= 0 then
      chaserRepath = 0.25
      chaserPath = sample.D.pathfind.astar(
        math.floor(chaserBody:getX() / CHASER_CELL), math.floor(chaserBody:getY() / CHASER_CELL),
        math.floor(playerBody:getX() / CHASER_CELL), math.floor(playerBody:getY() / CHASER_CELL),
        chaserPassable, { maxNodes = 2000 })
    end
    local tx, ty = playerBody:getX(), playerBody:getY()
    if chaserPath and #chaserPath > 0 then
      local wp = chaserPath[1]
      local wx, wy = wp.x * CHASER_CELL + CHASER_CELL / 2, wp.y * CHASER_CELL + CHASER_CELL / 2
      if math.abs(wx - chaserBody:getX()) < 10 and math.abs(wy - chaserBody:getY()) < 10 then
        table.remove(chaserPath, 1) -- waypoint reached
      else
        tx, ty = wx, wy
      end
    end
    local dx = tx - chaserBody:getX()
    local dy = ty - chaserBody:getY()
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    chaserBody:setLinearVelocity(dx / len * 95, dy / len * 95)
  end

  PHYS:update(dt)

  -- contacts resolve AFTER the step (the queued-contact contract)
  PHYS:drainContacts(function(kind, fa, fb)
    if kind ~= "begin" then return end
    local ua = fa and fa:getUserData() or {}
    local ub = fb and fb:getUserData() or {}
    local playerSide = ua.kind == "player" and ub or (ub.kind == "player" and ua or nil)
    if not playerSide then
      -- chaser bumping the player's fixture pair is handled above; chaser vs
      -- walls/gems are ignored
      return
    end
    if playerSide.kind == "gem" then
      local entityId = playerSide.entityId
      gems = gems + 1
      local arch = E.ecs:get(entityId, "archetype")
      score = score + (GEM_VALUE[arch and arch.props.tier or "common"] or 10)
      local body = E.ecs:get(entityId, "body")
      if body then PHYS:destroy(body.ref) end
      E.ecs:destroy(entityId)
      if S.game.audio then
        S.game.audio:tone(660, 0.08, { kind = "triangle", vol = 0.12, sweepTo = 990 })
      end
      if playerBody then
        F:play("coin", playerBody:getX(), playerBody:getY() - 20)
      end
    elseif playerSide.kind == "spike" then
      if playerBody then hurt(playerBody:getX(), playerBody:getY(),
        fa:getBody():getX(), fa:getBody():getY()) end
    elseif playerSide.kind == "chaser" then
      if playerBody then hurt(playerBody:getX(), playerBody:getY(),
        chaserBody:getX(), chaserBody:getY()) end
    end
  end)
  E.ecs:update(0) -- sweep collected gems

  TR:update()
  if playerBody then R.camera:follow(playerBody:getX(), playerBody:getY(), dt) end
  R.camera:update(dt)
  R.particles:update(dt)
  F:update(dt)
  for _, anim in pairs(gemAnims) do anim:update(dt) end
  if playerAnim then playerAnim:update(dt) end
  if chaserAnim then chaserAnim:update(dt) end
end

function scene.draw()
  R.pipeline:draw()
end

function scene.keypressed(key)
  if key == "f1" then
    if S.scene.depth() > 1 then S.scene.pop() else S.scene.replace("gh_menu") end
  elseif key == "escape" then
    finish(false)
  end
end

function scene.resize(w, h) R:resize(w, h) end
function scene.exit()
  -- bodies belong to this scene's world; drop refs so GC can reclaim
  playerBody, chaserBody = nil, nil
end

-- test hooks: the scripted win/lose driver
scene.hooks = {}
scene.hooks.state = function()
  return { hearts = hearts, gems = gems, score = score, timeLeft = timeLeft,
           finished = finished, gemsRequired = gemsRequired,
           playerX = playerBody and playerBody:getX() or nil,
           chaserX = chaserBody and chaserBody:getX() or nil,
           chaserY = chaserBody and chaserBody:getY() or nil }
end
-- Pass H test surface: the atlas/shader chain for the adoption gate
scene.hooks.atlas = function()
  return { spr = SPR, shaders = SH,
           playerFrame = playerAnim and playerAnim:frame() or nil }
end

return scene
