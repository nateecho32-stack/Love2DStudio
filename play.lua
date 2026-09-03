-- Play mode: loads a scene FILE (the editor's format), spawns the ecs via
-- the archetype registry, and runs it with a small system set. This is
-- play-from-editor (Pass 8): the same data the editor writes is what plays.
-- Push with { path = "scenes/whatever.lua" }.

local here = (...) or "play"
local root = here == "play" and "" or (here:match("^(.*)%.play$") or "")
local S = require(root ~= "" and root or "init")

local scene = {}
local R, E, F, player

-- live handle for the console's "entities" command
scene.ecs = function() return E and E.ecs or nil end

local ARCHETYPES = S.require(root ~= "" and root .. ".archetypes" or "archetypes")

local TILE = 32
local TILESET = {
  { 0.25, 0.5, 0.28 }, { 0.45, 0.35, 0.24 }, { 0.42, 0.44, 0.5 }, { 0.2, 0.35, 0.6 },
}

local function drawTiles(view)
  if not scene.tiles then return end
  local cx0 = math.floor(view.x / TILE)
  local cy0 = math.floor(view.y / TILE)
  local cx1 = math.floor((view.x + view.w) / TILE)
  local cy1 = math.floor((view.y + view.h) / TILE)
  for cy = cy0, cy1 do
    for cx = cx0, cx1 do
      local id = scene.tiles[cx .. "," .. cy]
      if id and TILESET[id] then
        love.graphics.setColor(TILESET[id][1], TILESET[id][2], TILESET[id][3], 0.85)
        love.graphics.rectangle("fill", cx * TILE, cy * TILE, TILE, TILE)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function registerArchetypes()
  for id, def in pairs(ARCHETYPES) do
    E:define(id, def)
  end
end

local function drawWorld()
  -- entities, procedurally drawn from their archetype tint/size
  E.ecs:each("transform", function(id, transform)
    local arch = E.ecs:get(id, "archetype")
    if not arch then return end
    local def = ARCHETYPES[arch.id] or { size = { w = 24, h = 24 }, tint = { 0.5, 0.5, 0.55 } }
    love.graphics.setColor(def.tint[1], def.tint[2], def.tint[3], 1)
    love.graphics.rectangle("fill",
      transform.x - def.size.w / 2, transform.y - def.size.h / 2, def.size.w, def.size.h)
  end)
  F:drawWorld()
end

local function drawHud()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format(
    "playing %s | %d entities | wasd move | click burst | F1 back | Esc quit",
    scene.path, E.ecs:alive()), 12, 10)
  if scene.missingFile then
    love.graphics.setColor(1, 0.8, 0.4)
    love.graphics.print("scene file not found — showing the built-in starter layout", 12, 26)
    love.graphics.setColor(1, 1, 1)
  end
end

function scene.enter(args)
  scene.path = (args and args.path) or "scenes/sandbox.lua"
  -- blur/focus pause through the event bus (the subscriber boot's emitters
  -- were waiting for)
  scene._blurHandle = S.bus.on("app.blurred", function() S.time.setPaused(true) end)
  scene._focusHandle = S.bus.on("app.focused", function() S.time.setPaused(false) end)
  scene._resetHandle = S.bus.on("graphics.reset", function()
    if R then R:onGraphicsReset() R:resize(love.graphics.getDimensions()) end
  end)
  R = S.render.new{ width = 1280, height = 720, lighting = false }
  E = S.entities.new{ ecs = S.ecs.new() }
  registerArchetypes()
  F = S.fx.new{
    camera = R.camera,
    time = S.time,
    particles = R.particles,
    timers = S.timer,
    font = S.assets.font(nil, 12),
  }

  local data, loadErr = S.scenedata.loadFromFile(scene.path)
  scene.missingFile = (data == nil)
  if not data then
    -- first-run fallback: a small built-in layout so play is never an empty void
    data = { version = 1, name = "starter", entities = {
      { type = "player_spawn", x = 0, y = 0, props = {} },
      { type = "block", x = -120, y = -60, props = {} },
      { type = "block", x = 180, y = 40, props = {} },
      { type = "torch", x = 40, y = -80, props = {} },
      { type = "goblin", x = 150, y = -40, props = { speed = 50 } },
    } }
    S.log.warn("play: %s (%s) — using the built-in starter layout", scene.path, tostring(loadErr))
  end
  E:deserialize(data.entities or {})
  scene.name = data.name or "untitled"
  scene.tiles = data.tiles

  -- find the player spawn (last one wins)
  player = { x = 0, y = 0 }
  E.ecs:each("archetype", function(id, arch)
    if arch.id == "player_spawn" then
      local transform = E.ecs:get(id, "transform")
      player.x, player.y = transform.x, transform.y
    end
  end)
  R.camera:moveTo(player.x, player.y)
  R.camera:setViewSize(R.viewport.width, R.viewport.height)

  -- goblin patrol: drift on x, bounce around the spawn
  E.ecs:each("archetype", function(id, arch)
    if arch.id == "goblin" then
      local transform = E.ecs:get(id, "transform")
      E.ecs:add(id, "patrol", { ox = transform.x, dir = 1 })
    end
  end)
  E.ecs:addSystem("patrol", function(world, dt)
    world:each("patrol", function(id, patrol)
      local transform = world:get(id, "transform")
      local arch = world:get(id, "archetype")
      local speed = arch.props.speed
      transform.x = transform.x + patrol.dir * speed * dt
      if math.abs(transform.x - patrol.ox) > 120 then patrol.dir = -patrol.dir end
    end)
  end, 1)

  R.pipeline:addLayer("tiles", function()
    drawTiles(R.camera:getView())
  end, -1)
  R.pipeline:addLayer("world", drawWorld, 0)
  R.pipeline:addLayer("particles", function() R.particles:draw() end, 5)
  R.pipeline:addLayer("fx", function() F:drawWorld() end, 6)
  R.pipeline:addHud("hud", drawHud, 0)
  R.pipeline:addHud("fxscreen", function() F:drawScreen(R.viewport) end, 9)

  R.particles:registerPreset("spark", {
    count = 14, life = { 0.2, 0.5 }, speed = { 60, 260 },
    size = { 2, 5 }, fade = "both", gravity = 60, drag = 2,
    colors = { { 1, 0.8, 0.4 }, { 1, 1, 0.85 } },
  })

  S.input.define({
    left  = { keys = { "left", "a" } },
    right = { keys = { "right", "d" } },
    up    = { keys = { "up", "w" } },
    down  = { keys = { "down", "s" } },
  })
  R:resize(love.graphics.getDimensions())
end

function scene.update(dt)
  local vx = (S.input.down("right") and 1 or 0) - (S.input.down("left") and 1 or 0)
  local vy = (S.input.down("down") and 1 or 0) - (S.input.down("up") and 1 or 0)
  player.x = player.x + vx * 240 * dt
  player.y = player.y + vy * 240 * dt
  R.camera:follow(player.x, player.y, dt)
  R.camera:update(dt)
  E.ecs:update(dt)
  R.particles:update(dt)
  F:update(dt)
end

function scene.exit()
  if scene._blurHandle then S.bus.off(scene._blurHandle) scene._blurHandle = nil end
  if scene._focusHandle then S.bus.off(scene._focusHandle) scene._focusHandle = nil end
  if scene._resetHandle then S.bus.off(scene._resetHandle) scene._resetHandle = nil end
  S.time.setPaused(false)
end

function scene.draw()
  R.pipeline:draw()
  if S.time.paused then
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, R.viewport.width, R.viewport.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("paused — click the window to resume", R.viewport.width / 2 - 110, R.viewport.height / 2)
  end
end

function scene.mousepressed(x, y)
  local lx, ly = R.viewport:toLogical(x, y)
  local wx, wy = R.camera:toWorld(lx, ly)
  R.particles:emit("spark", wx, wy)
  F:play("hit", wx, wy)
  -- zero-asset audio: a short descending thump through the sfx bus
  if S.game.audio then
    S.game.audio:tone(220, 0.09, { kind = "square", vol = 0.12, sweepTo = 70 })
  end
end

function scene.keypressed(key)
  if key == "f1" then
    -- return to whatever opened us (the editor), or quit if we are the root
    if S.scene.depth() > 1 then S.scene.pop() else love.event.quit() end
  elseif key == "escape" then
    love.event.quit()
  end
end

function scene.resize(w, h)
  R:resize(w, h)
end

return scene
