-- Lazy dependency registry: keys resolve to modules on first access, so cold
-- boot stays cheap and circular requires disappear.
-- Adapted from 2d Trippy Hell game/state/deps.lua.

local deps = {}

-- paths: { key = "module.path", ... }
-- eager: array of keys to load immediately
-- requireFn: injectable for tests
function deps.new(paths, eager, requireFn)
  local M = { _paths = paths }
  local req = requireFn or require

  local function loadKey(key)
    local path = paths[key]
    if not path then return nil end
    local mod = req(path)
    rawset(M, key, mod)
    return mod
  end

  function M.isLoaded(key) return rawget(M, key) ~= nil end

  function M.preload(keys)
    if not keys then return end
    for i = 1, #keys do loadKey(keys[i]) end
  end

  setmetatable(M, {
    __index = function(_, key)
      if type(key) ~= "string" then return nil end
      return loadKey(key)
    end,
  })

  M.preload(eager)
  return M
end

return deps
