-- Save orchestrator: sidecar-per-system files (a partial write failure names
-- the exact file), versioned migrations, lost-content disclosure, and an
-- autosave preset ladder. Adapted from 2d Trippy Hell save/save.lua and
-- run_lifecycle.lua's sidecar discipline.

local root = (...):match("^(.-)save%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local serialize = R("save.serialize")
local migration = R("save.migration")
local fsx = R("core.fsx")

local save = {}

save.AUTOSAVE_LADDER = { 0, 30, 60, 120, 300, 600, 900, 1800 }

-- snaps a raw seconds value to the nearest ladder rung (settings UI helper)
function save.nearestLadder(seconds)
  local best, bestDist
  for _, rung in ipairs(save.AUTOSAVE_LADDER) do
    local dist = math.abs(rung - seconds)
    if not bestDist or dist < bestDist then best, bestDist = rung, dist end
  end
  return best
end

-- opts: { dir=, version=, migrations=, fs= } — fs injectable for tests:
-- fs.read(path) -> string|nil, fs.write(path, body) -> ok, fs.remove(path), fs.list(dir)
function save.new(opts)
  opts = opts or {}
  local S = {
    dir = opts.dir or "saves/slot1",
    version = opts.version or 1,
    migrations = opts.migrations or {},
    _fs = opts.fs,
    notes = {}, -- lost-content / heal disclosures from the last read
  }

  -- dot-style fs adapter matching love.filesystem's own call shape
  local function fs()
    if S._fs then return S._fs end
    return {
      read = function(path) return love.filesystem.read(path) end,
      write = function(path, body) return love.filesystem.write(path, body) end,
      remove = function(path) return love.filesystem.remove(path) end,
      list = function(dir) return love.filesystem.getDirectoryItems(dir) end,
    }
  end

  function S:path(system) return S.dir .. "/" .. system .. ".dat" end

  -- writes ONE system's sidecar; the caller learns exactly which file failed
  function S:write(system, data)
    local body = serialize.encode(migration.wrap(S.version, data))
    if not S._fs then fsx.ensureParent(S:path(system)) end -- nested dirs
    local ok, err = fs().write(S:path(system), body)
    if not ok then return false, system .. ".dat: write_failed (" .. tostring(err) .. ")" end
    return true
  end

  -- returns data | nil, err ; S.notes carries disclosures
  function S:read(system)
    S.notes = {}
    local body = fs().read(S:path(system))
    if not body then return nil, system .. ".dat: no save" end
    local decoded, err = serialize.decode(body)
    if not decoded then return nil, system .. ".dat: corrupt (" .. tostring(err) .. ")" end
    local migrated, changed, notes = migration.migrate(decoded, S.migrations, S.version)
    if not migrated then return nil, system .. ".dat: " .. tostring(changed) end
    S.notes = notes or {}
    return migrated.data, changed
  end

  function S:exists(system)
    return fs().read(S:path(system)) ~= nil
  end

  function S:delete(system)
    return fs().remove(S:path(system)) and true or false
  end

  function S:systems()
    local out = {}
    for _, item in ipairs(fs().list(S.dir) or {}) do
      local name = item:match("^(.+)%.dat$")
      if name then out[#out + 1] = name end
    end
    table.sort(out)
    return out
  end

  return S
end

return save
