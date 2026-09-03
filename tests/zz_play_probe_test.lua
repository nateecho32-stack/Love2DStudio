-- TEMPORARY probe: why is --shot play black? Dump canvases + pixel samples.
local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")
local input = R("core.input")
local S = R("init")

local function dump(name, canvas)
  canvas:newImageData():encode("png", "probe_" .. name .. ".png")
end

local function px(canvas, x, y)
  local r, g, b = canvas:newImageData():getPixel(x or 32, y or 32)
  return string.format("(%.3f, %.3f, %.3f)", r, g, b)
end

T.case("zz play probe", function()
  local files = {}
  local fs = {
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
  }
  S.scenedata.saveToFile("scenes/play_probe.lua", {
    version = 1, name = "probe",
    entities = {
      { type = "player_spawn", x = 0, y = 0, props = {} },
      { type = "block", x = 60, y = 0, props = {} },
    },
  }, fs)
  local realLoad = S.scenedata.loadFromFile
  S.scenedata.loadFromFile = function(path, f, ...) return realLoad(path, fs, ...) end

  local playScene = S.require("play")
  scene.register("play_probe", playScene)
  scene.push("play_probe", { path = "scenes/play_probe.lua" })
  input.update()

  local ok, err = pcall(function()
    for _ = 1, 5 do
      scene.update(1 / 60)
      scene.draw()
    end
  end)
  print("PROBE play frames ok = " .. tostring(ok) .. " err = " .. tostring(err))

  -- reach into the play scene's render stack via the pipeline registry hack:
  -- the scene module doesn't expose R, so re-derive from the last draw state:
  -- instead just screenshot the real screen like --shot does
  love.graphics.captureScreenshot(function(image)
    love.filesystem.write("probe_play_screen.png", image:encode("png"))
    print("PROBE E screen dumped")
  end)
  scene.update(1 / 60)
  scene.draw()
  scene.clear()
  S.scenedata.loadFromFile = realLoad
  T.isTrue(true)
end)
