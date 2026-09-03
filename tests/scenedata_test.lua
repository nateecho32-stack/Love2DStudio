local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scenedata = R("save.scenedata")

local function fakeFs()
  local files = {}
  return {
    files = files,
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
  }
end

T.case("scenedata: save/load round-trips a scene table", function()
  local fs = fakeFs()
  local scene = scenedata.newTable("arena")
  scene.entities = {
    { type = "wall", x = 10, y = 20, props = { hp = 5 } },
    { type = "torch", x = 30, y = 40, props = {} },
  }
  T.isTrue(scenedata.saveToFile("scenes/arena.lua", scene, fs))
  local loaded = scenedata.loadFromFile("scenes/arena.lua", fs)
  T.eq(loaded.name, "arena")
  T.eq(#loaded.entities, 2)
  T.eq(loaded.entities[1], { type = "wall", x = 10, y = 20, props = { hp = 5 } })
end)

T.case("scenedata: missing file names the path", function()
  local fs = fakeFs()
  local scene, err = scenedata.loadFromFile("scenes/ghost.lua", fs)
  T.isNil(scene)
  T.isTrue(tostring(err):find("ghost.lua", 1, true) ~= nil)
end)

T.case("scenedata: future versions refused", function()
  local fs = fakeFs()
  fs.files["scenes/s.lua"] = "return { version = 99, entities = {} }"
  local scene, err = scenedata.loadFromFile("scenes/s.lua", fs)
  T.isNil(scene)
  T.isTrue(tostring(err):find("future", 1, true) ~= nil)
end)

T.case("scenedata: migrations run on load", function()
  local fs = fakeFs()
  fs.files["scenes/old.lua"] =
    'return { version = 1, name = "old", entities = { { type = "crate", x = 1, y = 2 } } }'
  local scene = scenedata.loadFromFile("scenes/old.lua", fs, {
    { from = 1, fn = function(s)
      for _, e in ipairs(s.entities) do e.props = e.props or {} end
      return s
    end },
  }, 2) -- file is v1; current version is 2, so the step runs
  T.eq(scene.entities[1].props, {})
  T.eq(scene.notes, nil) -- no notes emitted; disclosure only when present
end)
