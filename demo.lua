-- Render demo: world grid + blocks under a camera, particles, point lights,
-- postfx, and HUD text. Controls: WASD/arrows move, mouse wheel zoom, click
-- for a burst, space bursts at the player, P cycles postfx, L toggles
-- lighting, Q cycles particle quality, F toggles fullscreen, Esc quits.

local here = (...) or "demo"
local root = here == "demo" and "" or (here:match("^(.*)%.demo$") or "")
local S = require(root ~= "" and root or "init")

local scene = {}
local R            -- render stack
local player = { x = 0, y = 0 }
local t = 0
local title
local blocks = {}
local flashes = {} -- {x, y} ttl light positions
local drng         -- persistent demo rng (a fresh one every frame never varies)
local U            -- ui kit (settings overlay)
local settings     -- persisted studio settings
local settingsOpen = false

local POSTFX_CYCLE = { "off", "low", "high" }
local QUALITY_CYCLE = { "off", "low", "medium", "high" }

local function makeSettings()
  return S.settings.new{
    file = "studio_settings.dat",
    version = 1,
    defaults = {
      video = { postfx = "low", particles = "medium", shake = 1 },
      audio = { master = 0.8, sfx = 0.8 },
    },
    rules = {
      ["video.postfx"] = { values = { "off", "low", "high" } },
      ["video.particles"] = { values = { "off", "low", "medium", "high" } },
      ["video.shake"] = { min = 0, max = 2 },
      ["audio.master"] = { min = 0, max = 1 },
      ["audio.sfx"] = { min = 0, max = 1 },
    },
  }
end

local function applySettings()
  R.postfx:setPreset(settings:get("video.postfx"))
  R.particles:setQuality(settings:get("video.particles"))
  R.camera.shakeScale = settings:get("video.shake")
  if S.game.audio then
    S.game.audio:setBusVolume("master", settings:get("audio.master"))
    S.game.audio:setBusVolume("sfx", settings:get("audio.sfx"))
  end
end

local function cycle(list, current)
  for i, v in ipairs(list) do
    if v == current then return list[i % #list + 1] end
  end
  return list[1]
end

local function burst(x, y)
  R.particles:emit("spark", x, y)
  R.lights:add(x, y, 120, 1, 0.7, 0.3, 1.4, 0.35)
  R.camera:shake(7, 0.25)
  if S.game.audio then
    -- zero-asset audio: descending thump through the sfx bus
    S.game.audio:tone(190, 0.08, { kind = "square", vol = 0.1, sweepTo = 60 })
  end
end

local function drawWorld()
  local cam = R.camera
  local view = cam:getView()

  -- world-space grid (drawn across the view only)
  love.graphics.setColor(0.14, 0.16, 0.2)
  local gx0 = math.floor(view.x / 64) * 64
  local gy0 = math.floor(view.y / 64) * 64
  for gx = gx0, view.x + view.w + 64, 64 do
    love.graphics.line(gx, view.y, gx, view.y + view.h)
  end
  for gy = gy0, view.y + view.h + 64, 64 do
    love.graphics.line(view.x, gy, view.x + view.w, gy)
  end

  -- decorative blocks, culled
  for i = 1, #blocks do
    local b = blocks[i]
    if R.cull.rect(view, b.x, b.y, b.w, b.h) then
      love.graphics.setColor(b.r, b.g, b.b)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end
  end

  -- the "player"
  love.graphics.setColor(0.95, 0.65, 0.25)
  love.graphics.rectangle("fill", player.x - 14, player.y - 14, 28, 28)
end

local function drawSettingsOverlay()
  local vw, vh = R.viewport.width, R.viewport.height
  local pw, ph = 460, 330
  local px, py = (vw - pw) / 2, (vh - ph) / 2

  -- dim + modal panel; keyboard/gamepad nav through the focus system
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, vw, vh)
  U:panel(px, py, pw, ph)
  U:label(px + 16, py + 12, "Settings", { color = U.theme.accent })

  local y = py + 44
  if U:button("postfx", px + 16, y, pw - 32, 24,
      "Post-FX: " .. tostring(settings:get("video.postfx"))) then
    local cur = settings:get("video.postfx")
    settings:set("video.postfx", cycle(POSTFX_CYCLE, cur))
    applySettings(); settings:save()
  end
  y = y + 32
  if U:button("particles", px + 16, y, pw - 32, 24,
      "Particles: " .. tostring(settings:get("video.particles"))) then
    local cur = settings:get("video.particles")
    settings:set("video.particles", cycle(QUALITY_CYCLE, cur))
    applySettings(); settings:save()
  end
  y = y + 32
  U:label(px + 16, y, string.format("Screen shake %.2f", settings:get("video.shake")), { color = U.theme.dim })
  settings:set("video.shake", U:slider("shake", px + 16, y + 14, pw - 32, settings:get("video.shake")))
  y = y + 44
  U:label(px + 16, y, string.format("Master volume %d%%", math.floor(settings:get("audio.master") * 100)), { color = U.theme.dim })
  settings:set("audio.master", U:slider("master", px + 16, y + 14, pw - 32, settings:get("audio.master")))
  y = y + 44
  U:label(px + 16, y, string.format("SFX volume %d%%", math.floor(settings:get("audio.sfx") * 100)), { color = U.theme.dim })
  settings:set("audio.sfx", U:slider("sfx", px + 16, y + 14, pw - 32, settings:get("audio.sfx")))
  y = y + 44
  if U:button("apply", px + 16, y, 130, 24, "Apply & Save") then
    applySettings(); settings:save()
    U:toast("settings saved")
  end
  if U:button("close", px + 158, y, 130, 24, "Close (Esc)") then
    settingsOpen = false
  end
  if U:button("quit", px + 300, y, 130, 24, "Quit") then
    love.event.quit()
  end
  U:label(px + 16, py + ph - 22, "arrows/gamepad navigate — enter/A confirms", { color = U.theme.dim })
  applySettings() -- sliders apply live; save happens on button actions
end

local function drawHud()
  -- one beginFrame per frame: HUD and the settings overlay share the pass,
  -- so the overlay's widgets own the focus order while it is open
  local mx, my = R.viewport:getMouse()
  local down = love.mouse.isDown(1)
  local confirm = S.input.pressed("uiConfirm")
  U:beginFrame(mx, my, down, 0, confirm)

  if title then title:draw(16, 12) end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.format(
    "fps %d | postfx %s (P) | lighting %s (L) | particles %s (Q) | particles alive %d",
    love.timer.getFPS(),
    R.postfx:current(),
    R.pipeline.lighting and "on" or "off",
    R.particles.quality,
    R.particles:count()), 16, 40)
  love.graphics.print("wasd move | wheel zoom | click/space burst | E editor | F5 play | Esc settings | f fullscreen", 16, 58)
  U:drawToasts(16, 80)
  if settingsOpen then
    drawSettingsOverlay()
  end
end

function scene.enter()
  drng = S.rng.new(os.time())
  R = S.render.new{    width = 960, height = 540, -- letterboxes inside a 1280x720 window on purpose
    bounds = { x = -640, y = -480, w = 1280, h = 960 },
    postfx = "low",
    lighting = true,
    ambient = { 0.16, 0.15, 0.22 },
  }

  local rng = S.rng.new(7)
  for i = 1, 50 do
    blocks[i] = {
      x = rng:float(-600, 580), y = rng:float(-440, 420),
      w = rng:float(20, 90), h = rng:float(20, 90),
      r = rng:float(0.15, 0.45), g = rng:float(0.15, 0.4), b = rng:float(0.2, 0.5),
    }
  end

  R.particles:registerPreset("spark", {
    count = 26, life = { 0.25, 0.6 }, speed = { 80, 340 },
    size = { 3, 7 }, fade = "both", gravity = 90, drag = 1.5,
    spin = { -4, 4 }, colors = {
      { 1, 0.85, 0.45 }, { 1, 0.6, 0.2 }, { 1, 1, 0.9 },
    },
  })
  R.particles:registerPreset("smoke", {
    count = 2, life = { 0.5, 1.0 }, speed = { 10, 40 },
    angle = { -math.pi / 2 - 0.6, -math.pi / 2 + 0.6 },
    size = { 5, 9 }, sizeEnd = { 14, 22 }, fade = "fade",
    gravity = -30, drag = 1, blend = "alpha",
    colors = { { 0.35, 0.35, 0.4 } },
  })

  R.pipeline:addLayer("world", drawWorld, 0)
  R.pipeline:addLayer("particles", function() R.particles:draw() end, 5)
  R.pipeline:addHud("hud", drawHud, 0)

  title = R.text.new("LOVE2D STUDIO — RENDER PASS", S.assets.font(nil, 16))

  S.input.define({
    left  = { keys = { "left", "a" } },
    right = { keys = { "right", "d" } },
    up    = { keys = { "up", "w" } },
    down  = { keys = { "down", "s" } },
    uiUp    = { keys = { "up" }, buttons = { "dpup" } },
    uiDown  = { keys = { "down" }, buttons = { "dpdown" } },
    uiLeft  = { keys = { "left" }, buttons = { "dpleft" } },
    uiRight = { keys = { "right" }, buttons = { "dpright" } },
    uiConfirm = { keys = { "return", "space" }, buttons = { "a" } },
  })

  U = S.ui.new{ font = S.assets.font(nil, 13), width = 1280, height = 720 }
  settings = makeSettings()
  settings:load()
  -- visual-regression hook: STUDIO_SETTINGS_SHOT=1 opens the overlay at boot
  if os.getenv("STUDIO_SETTINGS_SHOT") then settingsOpen = true end

  R:resize(love.graphics.getDimensions())
  scene.state = player -- smoke test reads this for NaN checks
  applySettings()

  -- fullscreen switches kill every canvas/shader: rebuild on the bus event
  scene._resetHandle = S.bus.on("graphics.reset", function()
    R:onGraphicsReset()
    R:resize(love.graphics.getDimensions())
  end)
end

function scene.exit()
  if scene._resetHandle then S.bus.off(scene._resetHandle) scene._resetHandle = nil end
end

function scene.update(dt)
  t = t + dt
  U:update(dt)
  if settingsOpen then
    -- focus nav while the modal is up; the world holds still
    if S.input.pressed("uiUp") then U:moveFocus(-1) end
    if S.input.pressed("uiDown") then U:moveFocus(1) end
    return
  end
  local vx = (S.input.down("right") and 1 or 0) - (S.input.down("left") and 1 or 0)
  local vy = (S.input.down("down") and 1 or 0) - (S.input.down("up") and 1 or 0)
  player.x = player.x + vx * 260 * dt
  player.y = player.y + vy * 260 * dt
  if (vx ~= 0 or vy ~= 0) and drng:chance(dt * 20) then
    R.particles:emit("smoke", player.x, player.y + 12)
  end

  R.camera:follow(player.x, player.y, dt)
  R.camera:update(dt)
  R.particles:update(dt)
  R.lights:update(dt)
  title:update(dt)

  -- lights are rebuilt each frame: persistent player light, pulsing orbs,
  -- plus short-ttl flashes from bursts
  R.lights:clear()
  R.lights:add(player.x, player.y, 170, 1, 0.85, 0.6, 1.15)
  for i = 0, 2 do
    local ox, oy = math.sin(t * 0.7 + i * 2.1) * 380, math.cos(t * 0.5 + i * 1.7) * 300
    local pulse = 0.6 + 0.4 * math.sin(t * 2 + i * 3)
    if i == 0 then
      R.lights:add(ox, oy, 190, 0.35, 0.5, 1, pulse)
    elseif i == 1 then
      R.lights:add(ox, oy, 160, 0.8, 0.3, 0.9, pulse)
    else
      R.lights:add(ox, oy, 170, 0.3, 0.9, 0.6, pulse)
    end
  end
end

function scene.draw()
  R.pipeline:draw()
end

function scene.keypressed(key)
  if key == "escape" then
    -- settings modal: Esc closes it; from the world it opens
    settingsOpen = not settingsOpen
    return
  end
  if settingsOpen then return end -- modal owns input; nav runs in update
  if key == "space" then
    burst(player.x, player.y)
  elseif key == "p" then
    R.postfx:setPreset(cycle(POSTFX_CYCLE, R.postfx:current()))
    if settings then settings:set("video.postfx", R.postfx:current()) settings:save() end
  elseif key == "l" then
    R.pipeline.lighting = not R.pipeline.lighting
  elseif key == "q" then
    R.particles:setQuality(cycle(QUALITY_CYCLE, R.particles.quality))
    if settings then settings:set("video.particles", R.particles.quality) settings:save() end
  elseif key == "e" then
    S.scene.push("editor")
  elseif key == "f5" then
    S.scene.push("play", { path = "scenes/sandbox.lua" })
  elseif key == "f" then
    love.window.setFullscreen(not love.window.getFullscreen())
    -- setMode destroyed every canvas and shader: rebuild, then the resize
    -- event refills sizes
    R:onGraphicsReset()
    R:resize(love.graphics.getDimensions())
  end
end

function scene.mousepressed(x, y)
  if settingsOpen then return end -- the modal owns clicks
  if not R.viewport:contains(x, y) then return end
  local lx, ly = R.viewport:toLogical(x, y)
  local wx, wy = R.camera:toWorld(lx, ly)
  burst(wx, wy)
  R.particles:emit("smoke", wx, wy)
end

function scene.wheelmoved(_, y)
  R.camera:setZoom(R.camera.zoom * (y > 0 and 1.15 or 1 / 1.15))
end

function scene.resize(w, h)
  R:resize(w, h)
end

return scene
