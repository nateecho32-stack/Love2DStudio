-- Render stack facade: builds viewport + camera + pipeline + lights +
-- particles + postfx, routes resize / graphics-reset through everything in
-- the right order, and exposes cull + text helpers. A game typically holds
-- one R per scene and wires it into boot's resize path.

local root = (...):match("^(.-)render%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local viewport = R("render.viewport")
local camera = R("render.camera")
local lightsMod = R("render.light")
local particlesMod = R("render.particles")
local postfxMod = R("render.postfx")
local pipelineMod = R("render.pipeline")
local cull = R("render.cull")
local text = R("render.text")

local render = {}

function render.new(opts)
  opts = opts or {}
  local vp = viewport.new{
    width = opts.width or 1280,
    height = opts.height or 720,
    integerScale = opts.integerScale,
  }
  local cam = camera.new{
    x = opts.cameraX, y = opts.cameraY,
    zoom = opts.zoom, bounds = opts.bounds,
    followSpeed = opts.followSpeed,
  }
  cam:setViewSize(vp.width, vp.height)
  local lights = lightsMod.new{ ambient = opts.ambient }
  local particles = particlesMod.new{ budget = opts.particleBudget }
  local fx = postfxMod.new()
  fx:setPreset(opts.postfx or "off")
  fx:resize(vp.width, vp.height)
  local pipe = pipelineMod.new{
    viewport = vp,
    camera = cam,
    lights = lights,
    postfx = fx,
    lighting = opts.lighting,
    bgColor = opts.bgColor,
  }

  local S = {
    viewport = vp,
    camera = cam,
    lights = lights,
    particles = particles,
    postfx = fx,
    pipeline = pipe,
    cull = cull,
    text = text,
  }

  function S:resize(w, h)
    vp:resize(w, h)
    pipe:onResize()
  end

  -- call after love.window.setMode / setFullscreen (canvases + shaders die)
  function S:onGraphicsReset()
    pipe:onGraphicsReset()
  end

  return S
end

return render
