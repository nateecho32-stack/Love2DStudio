-- Versioned save wrapper with an auditable step-migration chain.
-- Pattern from 2d Trippy Hell save/migration.lua + Dead Meridian's v1-v3 chain.

local M = {}

-- the on-disk shape every save file uses
function M.wrap(version, data)
  return { version = version, data = data }
end

-- migrations: array of { from = n, fn = function(data) return newData, note? end }
-- the chain walks from -> (from+1) -> ... -> currentVersion
-- returns migratedWrap, changed | nil, err
function M.migrate(wrapped, migrations, currentVersion)
  if type(wrapped) ~= "table" then return nil, "save is not a table" end
  local version = tonumber(wrapped.version) or 1
  if version > currentVersion then
    -- an older binary must refuse a newer file: merging would silently
    -- downgrade and destroy future-version data on re-save
    return nil, "unsupported_future_version"
  end
  if not wrapped.data then return nil, "save has no data" end

  local data = wrapped.data
  local changed = false
  local notes = nil

  while version < currentVersion do
    local step
    for _, m in ipairs(migrations) do
      if m.from == version then step = m break end
    end
    if not step then return nil, "missing migration from version " .. version end
    local ok, newData, note = pcall(step.fn, data)
    if not ok then return nil, "migration " .. version .. " failed: " .. tostring(newData) end
    data = newData
    if note then
      notes = notes or {}
      notes[#notes + 1] = note
    end
    version = version + 1
    changed = true
  end

  wrapped.version = currentVersion
  wrapped.data = data
  return wrapped, changed, notes
end

return M
