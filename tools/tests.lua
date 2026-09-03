-- Tiny test harness: register cases, deep-equal/near asserts, run with counts
-- and an exit-code-friendly boolean. Adapted from Void Place tools/tests.lua.

local tests = { cases = {}, passed = 0, failed = 0 }

local root = (...):match("^(.-)tools%.") or ""
function tests.require(path)
  return require(root ~= "" and root .. "." .. path or path)
end

function tests.case(name, fn)
  tests.cases[#tests.cases + 1] = { name = name, fn = fn }
end

local function deepEq(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if not deepEq(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil and b[k] ~= nil then return false end
  end
  return true
end

function tests.eq(a, b, msg)
  if not deepEq(a, b) then
    error(msg or ("expected equality, got " .. tostring(a) .. " vs " .. tostring(b)), 2)
  end
end

function tests.near(a, b, eps, msg)
  eps = eps or 1e-6
  if math.abs(a - b) > eps then
    error(msg or ("expected " .. tostring(a) .. " ~= " .. tostring(b) .. " within " .. eps), 2)
  end
end

function tests.isTrue(v, msg)
  if v ~= true then error(msg or "expected true, got " .. tostring(v), 2) end
end

function tests.isNil(v, msg)
  if v ~= nil then error(msg or "expected nil, got " .. tostring(v), 2) end
end

-- expects fn to raise; returns the error message
function tests.fails(fn, msg)
  local ok, err = pcall(fn)
  if ok then error(msg or "expected fn to raise an error", 2) end
  return err
end

function tests.run(filter)
  tests.passed, tests.failed = 0, 0
  for _, case in ipairs(tests.cases) do
    if not filter or case.name:find(filter, 1, true) then
      local ok, err = pcall(case.fn)
      if ok then
        tests.passed = tests.passed + 1
        print("PASS " .. case.name)
      else
        tests.failed = tests.failed + 1
        print("FAIL " .. case.name .. "\n  " .. tostring(err))
      end
    end
  end
  print(string.format("\n%d passed, %d failed", tests.passed, tests.failed))
  return tests.failed == 0
end

-- requires every tests/*.lua (each registers its cases), then runs them.
-- Uses love.filesystem when available so this works inside a .love bundle.
function tests.runAll(dir, filter)
  dir = dir or "tests"
  local items = {}
  if love and love.filesystem then
    items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    for _, item in ipairs(items) do
      if item:sub(-4) == ".lua" then
        local ok, err = pcall(tests.require, dir .. "." .. item:gsub("%.lua$", ""))
        if not ok then
          tests.failed = tests.failed + 1
          print("FAIL loading " .. dir .. "." .. item .. "\n  " .. tostring(err))
        end
      end
    end
  end
  return tests.run(filter)
end

return tests
