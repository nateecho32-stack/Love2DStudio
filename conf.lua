-- Standalone config for `love "Love2d Studio"`.
-- Games embedding the studio keep their own conf.lua at game root; a conf
-- inside a subfolder is inert to LÖVE.

function love.conf(t)
  t.identity = "love2d-studio"
  t.version = "11.5"
  t.window.title = "Love2d Studio"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.resizable = true
  t.window.vsync = 1

  -- Automated runs must never take exclusive fullscreen or vsync.
  -- (2d Trippy Hell lesson: a hung check in exclusive fullscreen locks the desktop.)
  if os.getenv("FRAMEWORK_SANDBOX") then
    t.window.width = 800
    t.window.height = 450
    t.window.vsync = 0
  end
end
