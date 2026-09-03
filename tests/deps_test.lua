local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local deps = R("core.deps")

T.case("deps: lazy — nothing loads until first access", function()
  local loads = {}
  local function fakeRequire(path)
    loads[#loads + 1] = path
    return { path = path }
  end

  local d = deps.new({ camera = "game.camera", audio = "game.audio" }, nil, fakeRequire)
  T.eq(loads, {})
  T.isTrue(not d.isLoaded("camera"))

  local cam = d.camera
  T.eq(loads, { "game.camera" })
  T.isTrue(d.isLoaded("camera"))
  T.eq(d.camera, cam) -- cached on the instance
  T.eq(loads, { "game.camera" }) -- required only once
end)

T.case("deps: eager list preloads", function()
  local loads = {}
  local function fakeRequire(path)
    loads[#loads + 1] = path
    return {}
  end
  deps.new({ a = "a", b = "b", c = "c" }, { "a", "c" }, fakeRequire)
  T.eq(loads, { "a", "c" })
end)

T.case("deps: unknown key resolves to nil", function()
  local d = deps.new({}, nil, function() return {} end)
  T.isNil(d.missing)
end)

T.case("deps: _paths stays exposed for tooling", function()
  local d = deps.new({ camera = "game.camera" }, nil, function() return {} end)
  T.eq(d._paths, { camera = "game.camera" })
end)
