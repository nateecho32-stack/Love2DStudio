-- Standalone entry: `love "Love2d Studio"` (or run.bat).
-- Flags: --test (suite), --shot <scene>, --editor, --play <sceneFile>,
-- --audit, plus the FRAMEWORK_CHECK single-check mode.
-- In runtime: backtick = dev console, F3 = profiler overlay.

local S = require("init")
local demo = require("demo")
local archetypes = require("archetypes")

local function runTests()
  print("Love2d Studio " .. S._VERSION .. " — test suite\n")
  local ok = S.tools.tests.runAll("tests")
  love.event.quit(ok and 0 or 1)
end

function love.load(args)
  S.log.setLevel("info")

  local flags = S.boot.parse(args)
  if flags.test then
    runTests()
    return
  end

  if os.getenv and os.getenv("FRAMEWORK_CHECK") then
    require("tools.checks")
    return
  end

  S.log.info("Love2d Studio %s booting", S._VERSION)
  love.window.setTitle("Love2d Studio " .. S._VERSION)
  S.scene.register("demo", demo)

  -- window mode cycling (F11); graphics.reset broadcasts to every scene
  local windowMode = S.window_mode.new{ bus = S.bus }
  S.dev = S.dev or {}
  S.dev.windowMode = windowMode

  -- dev console (backtick toggles, consumes input while open)
  local console = S.console.new{ font = S.assets.font(nil, 13) }
  console:register("help", "list commands", function()
    local names = {}
    for name in pairs(console.commands) do names[#names + 1] = name end
    table.sort(names)
    return table.concat(names, ", ")
  end)
  console:register("fps", "show fps", function() return love.timer.getFPS() .. " fps" end)
  console:register("reload", "restart the runtime", function() love.event.quit("restart") end)
  console:register("entities", "count live entities in the top scene", function()
    local top = S.scene.top()
    local ecs = top and type(top.ecs) == "function" and top.ecs()
    if ecs then return ecs:alive() .. " entities (alive)" end
    return "top scene has no ecs"
  end)
  console:register("scene", "show the scene stack", function()
    return S.scene.topName() .. " (depth " .. S.scene.depth() .. ")"
  end)
  console:register("version", "show the studio version", function()
    return "Love2d Studio " .. S._VERSION
  end)

  -- studio-level audio instance: no asset files shipped, tones only
  S.game.audio = S.audio.new{}

  -- profiler overlay (F3)
  local profiler = S.profiler.new{}
  local showProfiler = false

  -- editor scene (--editor, or E key from the demo)
  local editorScene = S.editor.new{
    S = S,
    scenePath = "scenes/sandbox.lua",
    archetypes = archetypes,
  }
  S.scene.register("editor", editorScene)

  -- play mode: --play <file>, or F5 from the editor; console can switch files
  local playScene = S.require("play")
  S.scene.register("play", playScene)
  console:register("play", "play <sceneFile>: open a scene file in play mode", function(path)
    path = path or "scenes/sandbox.lua"
    S.scene.clear()
    S.scene.push("play", { path = path })
    return "playing " .. path
  end)

  -- the reference game (Gem Haul): --sample, or the console command
  local sample = S.require("sample.init")
  console:register("sample", "launch the Gem Haul reference game", function()
    sample.start()
    return "gem haul started"
  end)

  if flags.audit then
    -- stateful pump: screenshots only flush at real frame ends, so the audit
    -- runs across frames instead of inside love.load
    local run = S.audit.begin{
      S = S,
      scenes = { demo = demo, editor = editorScene, play = playScene },
      frames = 60,
    }
    S.dev = { audit = run } -- minimal dev table for audit mode
    S.assets.ready()
    return -- no scene pushed here; the pump owns the stack
  end

  if flags.editor then
    S.scene.push("editor")
  elseif flags.sample then
    sample.start()
  elseif flags.play then
    S.scene.push("play", { path = flags.play })
  elseif flags.shot then
    sample.register()
    S.boot.run({
      scenes = {
        demo = demo, editor = editorScene, play = playScene,
        gh_menu = S.require("sample.menu"),
        gh_game = S.require("sample.game"),
        gh_results = S.require("sample.results"),
      },
      args = { "--shot", flags.shot },
    })
  else
    S.scene.push("demo")
  end
  S.assets.ready()

  -- expose dev tools to scenes through the studio table
  S.dev = {
    console = console,
    profiler = profiler,
    windowMode = windowMode,
    showProfiler = function() return showProfiler end,
    toggleProfiler = function() showProfiler = not showProfiler end,
  }
end

function love.update(dt)
  if S.dev and S.dev.audit then
    if S.audit.active() then
      S.audit.pump(dt)
    else
      S.audit.settle() -- writes the report, quits when screenshots flushed
    end
    return
  end
  if S.dev and S.dev.profiler then S.dev.profiler:endFrame() end
  S.boot.frame(dt)
end

function love.draw()
  if S.dev and S.dev.profiler then S.dev.profiler:beginFrame() end
  S.scene.draw()
  if S.dev and S.dev.console then
    S.dev.console:draw()
    if S.dev.showProfiler() then
      local winW = select(1, love.graphics.getDimensions())
      S.dev.profiler:draw(winW - 232, 8)
    end
  end
  S.tools.capture.maybeShoot()
end

function love.keypressed(key, scancode, isrepeat)
  if S.dev then
    if key == "backquote" then
      S.dev.console:toggle()
      return
    end
    if S.dev.console.open then
      S.dev.console:keypressed(key) -- console consumes everything while open
      return
    end
  if key == "f3" then
    S.dev.toggleProfiler()
    return
  end
  if key == "f11" and S.dev.windowMode then
    S.dev.windowMode:toggleFullscreen()
    return
  end
  end
  S.boot.keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
  if S.dev and S.dev.console:textinput(text) then return end
  S.boot.textinput(text)
end

function love.mousepressed(x, y, b) S.boot.mousepressed(x, y, b) end
function love.mousereleased(x, y, b) S.boot.mousereleased(x, y, b) end
function love.mousemoved(x, y, dx, dy) S.boot.mousemoved(x, y, dx, dy) end
function love.wheelmoved(x, y) S.boot.wheelmoved(x, y) end
function love.resize(w, h) S.boot.resize(w, h) end
function love.focus(f) S.boot.focus(f) end
