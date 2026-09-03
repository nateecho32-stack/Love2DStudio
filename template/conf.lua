-- Template game conf. Every number here is deliberate:
-- identity makes saves land in YOUR folder (the #1 conf bug in the audit),
-- resizable + vsync + min sizes match the proven 1280x720 baseline.

function love.conf(t)
  t.identity = "my-game"          -- CHANGE THIS: save-directory name
  t.version = "11.5"
  t.window.title = "My Game"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.resizable = true
  t.window.vsync = 1

  -- automated runs must never take exclusive fullscreen or vsync
  if os.getenv("FRAMEWORK_SANDBOX") then
    t.window.width = 800
    t.window.height = 450
    t.window.vsync = 0
  end
end
