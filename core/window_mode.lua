-- Window mode cycling with memory + graphics-reset broadcast. setMode
-- recreates the GL device and KILLS every canvas and shader: consumers
-- rebuild on the "graphics.reset" bus event (2d Trippy Hell window_mode.lua).

local window_mode = {}

local MODES = { "windowed", "borderless", "exclusive" }

function window_mode.new(opts)
  opts = opts or {}
  local W = {
    mode = opts.mode or "windowed",
    lastFullscreen = "desktop", -- which flavor toggle returns to
    bus = opts.bus,
    sandboxed = opts.sandboxed, -- never take fullscreen from automated runs
  }

  function W:isSandboxed()
    if self.sandboxed ~= nil then return self.sandboxed end
    return os.getenv and (os.getenv("FRAMEWORK_SANDBOX") ~= nil)
  end

  local function apply(mode)
    if not (love and love.window) then return end
    if W:isSandboxed() and mode ~= "windowed" then
      mode = "windowed" -- a hung fullscreen check locks the desktop
    end
    W.mode = mode
    if mode == "windowed" then
      love.window.setFullscreen(false)
    else
      W.lastFullscreen = (mode == "exclusive") and "exclusive" or "desktop"
      love.window.setFullscreen(true, mode == "exclusive" and "exclusive" or "desktop")
    end
    -- every canvas/shader just died; give consumers one frame to rebuild
    if W.bus then W.bus.emit("graphics.reset", mode) end
  end

  function W:set(mode) apply(mode) end

  function W:toggleFullscreen()
    if self.mode ~= "windowed" then
      apply("windowed")
    else
      apply(self.lastFullscreen == "exclusive" and "exclusive" or "borderless")
    end
  end

  function W:cycle()
    local nextMode = MODES[((self.mode == "windowed" and 1)
      or (self.mode == "borderless" and 2) or 3) % 3 + 1]
    apply(nextMode)
  end

  return W
end

return window_mode
