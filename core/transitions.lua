-- Scene transitions: switch scenes under a fade overlay. The current stack
-- is frozen into a canvas, the real push/replace happens, then a tiny overlay
-- scene draws the frozen frame fading away (or fades through black) and pops
-- itself when finished.

local transitions = {}
local sceneMod = nil -- injected via wire() to avoid a require cycle

function transitions.wire(sceneModule) sceneMod = sceneModule end

local spec = nil

local function freezeCurrent()
  if not (love and love.graphics) then return nil end
  local ok, w, h = pcall(love.graphics.getDimensions)
  if not ok then return nil end
  local canvas = love.graphics.newCanvas(w, h)
  love.graphics.setCanvas(canvas)
  pcall(function() sceneMod.draw() end)
  love.graphics.setCanvas()
  return canvas
end

local overlay = {}

function overlay.enter() end
function overlay.update(dt)
  if not spec then sceneMod.pop() return end
  spec.t = spec.t + dt
  if spec.t >= spec.dur then
    spec = nil
    sceneMod.pop() -- reveal the new scene beneath
  end
end
function overlay.draw()
  if not spec or not love.graphics then return end
  local k = math.min(1, spec.t / spec.dur) -- 0 -> 1 over the transition
  if spec.kind == "cross" and spec.frozen then
    love.graphics.setColor(1, 1, 1, 1 - k)
    love.graphics.draw(spec.frozen, 0, 0)
  else
    -- fade through black: dark until halfway, then lighten
    local a = k < 0.5 and (k / 0.5) or (1 - (k - 0.5) / 0.5)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- transitions.push("game", args, { kind = "fade"|"cross", dur = 0.35 })
function transitions.push(name, args, opts)
  assert(sceneMod, "transitions.wire(scene) first")
  opts = opts or {}
  local frozen = (opts.kind ~= "none") and freezeCurrent() or nil
  sceneMod.push(name, args)
  sceneMod.register("__transition", overlay)
  spec = { kind = opts.kind or "fade", dur = opts.dur or 0.35, t = 0, frozen = frozen }
  sceneMod.push("__transition")
end

function transitions.replace(name, args, opts)
  assert(sceneMod, "transitions.wire(scene) first")
  opts = opts or {}
  local frozen = (opts.kind ~= "none") and freezeCurrent() or nil
  sceneMod.replace(name, args)
  sceneMod.register("__transition", overlay)
  spec = { kind = opts.kind or "fade", dur = opts.dur or 0.35, t = 0, frozen = frozen }
  sceneMod.push("__transition")
end

function transitions.active() return spec ~= nil end

return transitions
