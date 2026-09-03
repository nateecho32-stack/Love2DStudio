-- Object pool with factory + reset. Adapted from Void Place engine/pool.lua.

local pool = {}

function pool.new(factory, reset)
  local P = { _factory = factory, _reset = reset, _free = {}, _live = 0 }

  function P:acquire()
    local obj
    if #self._free > 0 then
      obj = table.remove(self._free)
    else
      obj = self._factory()
    end
    self._live = self._live + 1
    return obj
  end

  function P:release(obj)
    if self._reset then self._reset(obj) end
    self._free[#self._free + 1] = obj
    self._live = math.max(0, self._live - 1)
  end

  function P:live() return self._live end
  function P:cached() return #self._free end
  return P
end

return pool
