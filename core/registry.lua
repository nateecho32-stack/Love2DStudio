-- Generic id -> definition registry: archetypes, FX presets, audio families,
-- editor palette. Unknown ids return nil (the fallback seam), never raise.
-- Pattern from Void Place entities/init.lua.

local registry = {}

function registry.new()
  local R = { _byId = {}, _order = {} }

  function R:register(id, def)
    assert(type(id) == "string", "registry id must be a string")
    assert(def ~= nil, "registry def required for " .. id)
    if not self._byId[id] then self._order[#self._order + 1] = id end
    self._byId[id] = def
    return def
  end

  function R:get(id) return self._byId[id] end
  function R:has(id) return self._byId[id] ~= nil end
  function R:count() return #self._order end

  function R:ids()
    local out = {}
    for i = 1, #self._order do out[i] = self._order[i] end
    return out
  end

  function R:all()
    local out = {}
    for i = 1, #self._order do
      local id = self._order[i]
      out[i] = { id = id, def = self._byId[id] }
    end
    return out
  end

  return R
end

return registry
