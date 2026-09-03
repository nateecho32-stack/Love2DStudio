local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local i18n = R("core.i18n")
local windowMode = R("core.window_mode")
local shaders = R("render.shaders")
local version = R("version")

T.case("i18n: fallback chain active -> en -> key", function()
  local I = i18n.new{}
  I:registerLocale("en", { strings = { play = "Play", gems = "Gems: %d" } })
  I:registerLocale("de", { strings = { play = "Spielen" } })
  I:setLocale("de")
  T.eq(I:t("play"), "Spielen")
  T.eq(I:t("gems", 3), "Gems: 3")   -- falls back to en, formats
  T.eq(I:t("nope.deep"), "nope.deep") -- unknown keys return visibly
  I:setLocale("xx")                  -- refused; stays de
  T.eq(I:t("play"), "Spielen")
  T.eq(I:localeIds(), { "de", "en" })
end)

T.case("window mode: cycles with memory and sandbox guard", function()
  local applied = {}
  local fakeLove = {
    -- dot-style to match the module's love.window.setFullscreen(...) calls
    setFullscreen = function(on, mode)
      applied[#applied + 1] = on and (mode or "desktop") or "windowed"
      return true
    end,
  }
  local realWindow = love and love.window
  if love then love.window = fakeLove end

  local events = {}
  local W = windowMode.new{
    bus = { emit = function(name, mode) events[#events + 1] = name .. ":" .. mode end },
    sandboxed = false, -- fake window: cycle logic must run even under FRAMEWORK_SANDBOX
  }
  W:toggleFullscreen()               -- windowed -> borderless
  W:toggleFullscreen()               -- back to windowed
  W:set("exclusive")
  W:toggleFullscreen()               -- exclusive -> windowed
  W:toggleFullscreen()               -- windowed -> remembers exclusive
  T.eq(#applied, 5)
  for i = 1, #applied do
    T.eq(applied[i], ({ "desktop", "windowed", "exclusive", "windowed", "exclusive" })[i],
      "apply #" .. i .. " recorded " .. tostring(applied[i]))
  end
  T.eq(#events, 5, "every apply must broadcast graphics.reset")

  -- sandboxed instances never leave windowed
  local WS = windowMode.new{ sandboxed = true }
  WS:set("exclusive")
  T.eq(WS.mode, "windowed")

  if love then love.window = realWindow end
end)

T.case("shader library: compiles or degrades, never crashes", function()
  if not (love and love.graphics) then return end
  local L = shaders.new()
  for _, name in ipairs({ "hitflash", "grayscale", "dissolve", "water", "outline" }) do
    local shader = L:get(name)
    T.isTrue(shader ~= nil, name .. " should compile on this driver")
  end
  T.isNil(L:get("nonexistent"))

  -- draw through a shader with and without success paths
  local canvas = love.graphics.newCanvas(8, 8)
  local target = love.graphics.newCanvas(8, 8)
  love.graphics.setCanvas(target)
  local ok = pcall(function()
    L:draw("hitflash", canvas, { amount = 0.5 })
    L:draw("nope", canvas) -- missing shader: plain-draw fallback
  end)
  love.graphics.setCanvas()
  T.isTrue(ok)
  canvas:release()
  target:release()
end)

T.case("version: single source of truth is well-formed", function()
  T.eq(type(version.major), "number")
  T.eq(version.string, version.major .. "." .. version.minor .. "." .. version.patch)
end)
