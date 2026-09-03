-- Design-invariant helpers: protect game BALANCE the way Void Place's suite
-- does — trade-direction orderings, tuning-table snapshots ("these systems
-- cannot touch these numbers"), seeded Monte-Carlo bands, and pacing budgets.
-- All helpers return (ok, detail) so they compose with any test harness.

local design = {}

local function deepEqual(a, b, path)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then
    return false, (path or "?") .. ": " .. tostring(a) .. " vs " .. tostring(b)
  end
  for k, v in pairs(a) do
    local ok, detail = deepEqual(v, b[k], (path and path .. "." or "") .. tostring(k))
    if not ok then return false, detail end
  end
  for k in pairs(b) do
    if a[k] == nil and b[k] ~= nil then
      return false, (path and path .. "." or "") .. tostring(k) .. ": missing on left"
    end
  end
  return true
end

design.deepEqual = deepEqual

-- snapshot a tuning table; later, assertUnchanged proves some system cannot
-- mutate balance (Void Place's "palettes change colour and nothing else")
design.snapshot = function(config) return design.deepcopy(config) end

function design.deepcopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = type(v) == "table" and design.deepcopy(v) or v
  end
  return out
end

function design.assertUnchanged(config, snapshot)
  return deepEqual(config, snapshot)
end

-- trade-direction invariants: "if that trade ever inverts, the mechanic is dead"
function design.assertIncreasing(values)
  for i = 2, #values do
    if values[i] <= values[i - 1] then
      return false, "not increasing at index " .. i .. ": " .. tostring(values[i - 1]) .. " -> " .. tostring(values[i])
    end
  end
  return true
end

function design.assertDecreasing(values)
  for i = 2, #values do
    if values[i] >= values[i - 1] then
      return false, "not decreasing at index " .. i .. ": " .. tostring(values[i - 1]) .. " -> " .. tostring(values[i])
    end
  end
  return true
end

-- seeded Monte-Carlo driver: run fn(rng) n times, collect results
function design.monteCarlo(n, rng, fn)
  local out = {}
  for _ = 1, n do out[#out + 1] = fn(rng) end
  return out
end

-- every result must land inside [lo, hi] (spawn intervals, drop rates, ...)
function design.assertBand(results, lo, hi)
  for i = 1, #results do
    local v = results[i]
    if v ~= v or v < lo or v > hi then
      return false, "result " .. i .. " escaped band [" .. lo .. ", " .. hi .. "]: " .. tostring(v)
    end
  end
  return true
end

-- pacing budget: the fn must take between minSec and maxSec of wall clock
-- (Void Place's "intro must complete within 8-16 seconds")
function design.assertTimeBudget(fn, minSec, maxSec)
  local started = os.clock()
  local ok, err = pcall(fn)
  if not ok then return false, "budgeted fn raised: " .. tostring(err) end
  local elapsed = os.clock() - started
  if minSec and elapsed < minSec then return false, "too fast: " .. elapsed .. "s < " .. minSec .. "s" end
  if maxSec and elapsed > maxSec then return false, "too slow: " .. elapsed .. "s > " .. maxSec .. "s" end
  return true
end

return design
