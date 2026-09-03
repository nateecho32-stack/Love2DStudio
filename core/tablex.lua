-- Table helpers. Adapted from Vimur src/utils/table_utils.lua.

local M = {}

function M.copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

function M.deepCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and M.deepCopy(v) or v
  end
  return out
end

-- shallow merge; src wins; returns dst
function M.merge(dst, src)
  for k, v in pairs(src) do dst[k] = v end
  return dst
end

function M.keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  return out
end

function M.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function M.contains(t, v)
  for _, x in pairs(t) do if x == v then return true end end
  return false
end

function M.indexOf(t, v)
  for i = 1, #t do if t[i] == v then return i end end
  return nil
end

function M.reversed(t)
  local out = {}
  for i = #t, 1, -1 do out[#out + 1] = t[i] end
  return out
end

return M
