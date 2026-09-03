-- Play mode smoke test: load a scene file, run frames, click (fx burst),
-- pop back. This test exists because play mode crashed on its first draw
-- for a whole pass without any test noticing ("draw raises no error" was
-- vacuously true while the screen was black).

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")
local input = R("core.input")
local S = R("init")

T.case("play: boots a scene file, draws frames, bursts, pops back", function()
  if not (love and love.graphics) then return end

  -- write a scene file through the real save path
  local files = {}
  local fs = {
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
  }
  T.isTrue(S.scenedata.saveToFile("scenes/play_probe.lua", {
    version = 1,
    name = "probe",
    entities = {
      { type = "player_spawn", x = 0, y = 0, props = {} },
      { type = "goblin", x = 60, y = 0, props = { speed = 30 } },
      { type = "block", x = -60, y = 0, props = {} },
    },
  }, fs))

  -- make the studio read/write through the fake fs for this scene
  local realLoad = S.scenedata.loadFromFile
  S.scenedata.loadFromFile = function(path, f, ...)
    return realLoad(path, fs, ...)
  end

  local playScene = S.require("play")
  scene.register("play_probe", playScene)
  scene.register("under", {}) -- a scene underneath, so F1 has something to pop to
  scene.push("under")
  scene.push("play_probe", { path = "scenes/play_probe.lua" })
  input.update()

  -- the vacuous-draw lesson: a scene without a draw method silently renders
  -- nothing, so the invariant is asserted, not assumed
  T.isTrue(type(scene.top().draw) == "function", "play scene must define draw")

  local ok, err = pcall(function()
    for _ = 1, 30 do
      scene.update(1 / 60)
      scene.draw()
    end
    playScene.mousepressed(640, 360, 1) -- fx burst path (was the crash)
    scene.update(1 / 60)
    scene.draw()
    playScene.keypressed("f1") -- pops back when stacked
  end)
  S.scenedata.loadFromFile = realLoad -- restore BEFORE asserting (asserts throw)
  T.isTrue(ok, "play interaction raised: " .. tostring(err))
  T.eq(scene.depth(), 1) -- F1 popped play_probe, "under" remains
  scene.clear()
end)
