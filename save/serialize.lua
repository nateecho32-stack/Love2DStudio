-- Safe serializer: plain-Lua tables <-> loadable source. Functions, userdata
-- and threads are DROPPED (documented contract: saves store data, not code).
-- Adapted from Vimur src/save/save.lua and 2d Trippy Hell save/serialize.lua.

local M = {}

local function quote(s)
  -- %q alone round-trips quotes, backslashes and newlines (it emits a
  -- backslash-newline escape); extra rewriting only corrupts it
  return string.format("%q", s)
end

local MAX_DEPTH = 60

local function enc(v, depth, seen, out)
  local tv = type(v)
  if tv == "number" or tv == "boolean" then
    out[#out + 1] = tostring(v)
  elseif tv == "string" then
    out[#out + 1] = quote(v)
  elseif tv == "table" then
    if seen[v] or depth > MAX_DEPTH then
      out[#out + 1] = "nil" -- cycles and runaway depth drop, never hang
      return
    end
    seen[v] = true
    out[#out + 1] = "{"
    local first = true
    for _, av in ipairs(v) do
      if not first then out[#out + 1] = "," end
      first = false
      enc(av, depth + 1, seen, out)
    end
    for k, kv in pairs(v) do
      local isArrayIndex = type(k) == "number" and k % 1 == 0 and k >= 1 and k <= #v
      if not isArrayIndex then
        if not first then out[#out + 1] = "," end
        first = false
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          out[#out + 1] = k .. "="
        else
          out[#out + 1] = "["
          enc(k, depth + 1, seen, out)
          out[#out + 1] = "]="
        end
        enc(kv, depth + 1, seen, out)
      end
    end
    seen[v] = nil
    out[#out + 1] = "}"
  else
    out[#out + 1] = "nil" -- functions/userdata/threads dropped
  end
end

function M.encode(t)
  local out = { "return " }
  enc(t, 0, {}, out)
  out[#out + 1] = "\n"
  return table.concat(out)
end

-- returns value | nil, err
function M.decode(src)
  if type(src) ~= "string" then return nil, "not a string" end
  local chunk, err = load(src, "save", "t")
  if not chunk then chunk, err = load(src, "save") end -- LuaJIT 5.1 fallback
  if not chunk then return nil, err end
  if setfenv then setfenv(chunk, {}) end -- no stdlib access from save data
  local ok, result = pcall(chunk)
  if not ok then return nil, result end
  if type(result) ~= "table" then return nil, "save root must be a table" end
  return result
end

return M
