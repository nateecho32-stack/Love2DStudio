-- Boot: CLI flag parsing, crash log, unfocus throttle, debounced blur pause,
-- hot-reload hatch, capture integration, and the standard per-frame pipeline.
-- Adapted from 2d Trippy Hell main.lua + window_mode.lua and Void Place main.lua.

local M = { opts = {} }

local refs -- wired via M.wire(S)
local capture
local blurTimer = nil
local blurredByUs = false

function M.wire(S)
  refs = S
end

function M.setCapture(c) capture = c end

-- parses love.load args; flags: test, shot, skipintro, audit, editor, play
function M.parse(args)
  local flags = {}
  args = args or {}
  for i = 1, #args do
    local a = args[i]
    if a == "--test" or a == "test" then flags.test = true end
    if a == "--shot" then flags.shot = args[i + 1] or "demo" end
    if a == "--skipintro" then flags.skipintro = true end
    if a == "--audit" then flags.audit = true end
    if a == "--editor" then flags.editor = true end
    if a == "--play" then flags.play = args[i + 1] or "scenes/sandbox.lua" end
    if a == "--sample" then flags.sample = true end
  end
  return flags
end

-- chains the LÖVE errorhandler so crashes also land in a timestamped file
-- (with the log tail) inside the game's save directory
function M.installCrashLog()
  if not (love and love.filesystem) then return end
  local previous = love.errorhandler
  love.errorhandler = function(msg)
    local ok = pcall(function()
      local stamp = os.date("%Y%m%d-%H%M%S")
      local body = table.concat({
        "CRASH " .. stamp,
        tostring(msg),
        debug.traceback("", 2),
        "--- recent log ---",
        refs and refs.log and refs.log.dump() or "(no log)",
      }, "\n")
      love.filesystem.write("crash_" .. stamp .. ".txt", body)
    end)
    if not ok and previous then return previous(msg) end
    if previous then return previous(msg) end
    return false -- let LÖVE print the default handler output
  end
end

-- opts: { first=, scenes={name=mod,...}, args=, throttleUnfocused=true,
--         pauseOnBlur=false, blurDelay=0.35, hotReload=true }
-- returns parsed flags; if flags.test the caller runs its test suite instead
function M.run(opts)
  M.opts = opts or {}
  refs.opts = M.opts
  M.installCrashLog()
  local flags = M.parse(M.opts.args)
  if flags.test then return flags end
  if M.opts.scenes then
    for name, mod in pairs(M.opts.scenes) do refs.scene.register(name, mod) end
  end
  local first = M.opts.first or (M.opts.scenes and next(M.opts.scenes))
  if flags.shot then
    -- deterministic screenshot run: push the named scene, capture quits when done
    if capture then capture.start(flags.shot, M.opts.shot or {}) end
    refs.scene.push(flags.shot)
  elseif first then
    refs.scene.push(first, { flags = flags })
  end
  refs.assets.ready()
  refs.log.info("boot complete (shot=%s)", tostring(flags.shot))
  return flags
end

local function throttleIfUnfocused()
  if M.opts.throttleUnfocused == false then return end
  if love and love.window and love.window.isFocused and not love.window.isFocused() then
    love.timer.sleep(1 / 20)
  end
end

local function updateBlur(dt)
  if not refs.bus then return end
  local focused = true
  if love and love.window and love.window.isFocused then focused = love.window.isFocused() end
  if not focused then
    if blurTimer == nil then blurTimer = 0 end
    blurTimer = blurTimer + dt
    local delay = M.opts.blurDelay or 0.35
    if blurTimer >= delay and not blurredByUs then
      blurredByUs = true
      refs.bus.emit("app.blurred")
      if M.opts.pauseOnBlur then refs.time.setPaused(true) end
    end
  else
    if blurredByUs then
      blurredByUs = false
      if M.opts.pauseOnBlur then refs.time.setPaused(false) end
    end
    if blurTimer ~= nil then
      blurTimer = nil
      refs.bus.emit("app.focused")
    end
  end
end

-- the standard frame: capture override -> throttle -> input edges -> scene update
function M.frame(dt)
  if capture and capture.active then dt = capture.step() end
  throttleIfUnfocused()
  updateBlur(dt)
  refs.input.update()
  refs.time.update(dt, function(sdt) refs.scene.update(sdt) end)
  if capture and capture.quitting then love.event.quit() end
end

function M.draw()
  refs.scene.draw()
end

function M.keypressed(key, scancode, isrepeat)
  if M.opts.hotReload ~= false and key == "r"
    and love and love.keyboard and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
    love.event.quit("restart")
    return
  end
  refs.scene.keypressed(key, scancode, isrepeat)
end

function M.mousepressed(x, y, b) refs.scene.mousepressed(x, y, b) end
function M.mousereleased(x, y, b) refs.scene.mousereleased(x, y, b) end
function M.mousemoved(x, y, dx, dy) refs.scene.mousemoved(x, y, dx, dy) end
function M.wheelmoved(x, y) refs.scene.wheelmoved(x, y) end

-- text input reaches the top scene (text fields); consoles intercept earlier
function M.textinput(text)
  local top = refs.scene.top()
  if top and type(top.textinput) == "function" then
    top.textinput(text)
  end
end

function M.resize(w, h)
  refs.bus.emit("resize", w, h)
  refs.scene.resize(w, h)
end

function M.focus(focused)
  refs.bus.emit(focused and "app.focus" or "app.blur", focused)
end

return M
