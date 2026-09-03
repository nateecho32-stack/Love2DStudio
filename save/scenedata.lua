-- Scene files as versioned data: { version = n, name = "...", entities =
-- { { type =, x =, y =, props = {...} } } }. This is the editor's file
-- format (Pass 6) and the runtime loader's input (play-from-editor, Pass 8).

local root = (...):match("^(.-)save%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local serialize = R("save.serialize")
local migration = R("save.migration")
local fsx = R("core.fsx")

local scenedata = {}
scenedata.VERSION = 1

function scenedata.newTable(name)
  return { version = scenedata.VERSION, name = name or "untitled", entities = {} }
end

function scenedata.encode(scene)
  scene.version = scene.version or scenedata.VERSION
  return serialize.encode(scene)
end

-- returns sceneTable | nil, err
function scenedata.decode(body)
  local scene, err = serialize.decode(body)
  if not scene then return nil, err end
  if type(scene.entities) ~= "table" then scene.entities = {} end
  return scene
end

-- fs injectable for tests; defaults to love.filesystem (dot-style methods)
-- returns true | nil, err (naming the file)
function scenedata.saveToFile(path, scene, fs)
  local f = fs or love.filesystem
  if not fs then fsx.ensureParent(path) end -- nested writes fail silently otherwise
  local ok, err = f.write(path, scenedata.encode(scene))
  if not ok then return nil, path .. ": write_failed (" .. tostring(err) .. ")" end
  return true
end

-- returns sceneTable | nil, err ; runs version migrations when given
function scenedata.loadFromFile(path, fs, migrations, currentVersion)
  local f = fs or love.filesystem
  local body = f.read(path)
  if not body then return nil, path .. ": no such scene" end
  local scene, err = scenedata.decode(body)
  if not scene then return nil, path .. ": corrupt (" .. tostring(err) .. ")" end
  currentVersion = currentVersion or scenedata.VERSION
  if (scene.version or 1) > currentVersion then
    return nil, path .. ": unsupported_future_version"
  end
  if migrations and #migrations > 0 then
    local wrapped, changed, notes = migration.migrate(
      { version = scene.version or 1, data = scene }, migrations, currentVersion)
    if not wrapped then return nil, path .. ": " .. tostring(changed) end
    scene = wrapped.data
    scene.notes = notes
  end
  return scene
end

return scenedata
