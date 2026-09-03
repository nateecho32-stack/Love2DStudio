-- Generic single-check runner: with FRAMEWORK_CHECK=<module> set, running the
-- studio (or a game embedding it) executes that module and exits with the
-- failure count. Two module styles are supported:
--   1. check modules exposing run() -> failures (or a `failures` number)
--   2. test-registrar modules (they return nothing, require gives `true`);
--      their cases are registered in the shared harness and run here
-- FRAMEWORK_TIMEOUT_OPS arms a debug.sethook instruction watchdog so a hung
-- check cannot hang the machine (2d Trippy Hell lua_quality_runner lesson).

local name = os.getenv and os.getenv("FRAMEWORK_CHECK") or nil
if not name or name == "" then
  error("FRAMEWORK_CHECK env var must name the module to run, e.g. FRAMEWORK_CHECK=tests.rng_test")
end

local budget = tonumber(os.getenv("FRAMEWORK_TIMEOUT_OPS") or "")
if budget and budget > 0 then
  debug.sethook(function()
    error("check exceeded instruction budget (" .. budget .. " ops)")
  end, "", budget)
end

local root = (...):match("^(.-)tools%.") or ""
local function R(path) return require(root ~= "" and root .. "." .. path or path) end

local ok, mod = pcall(R, name)
if not ok then
  print("check load failed: " .. tostring(mod))
  if os and os.exit then os.exit(1) end
  error(mod)
end

local failures = 0
if type(mod) == "table" and type(mod.run) == "function" then
  failures = mod.run() or 0
elseif type(mod) == "table" and type(mod.failures) == "number" then
  failures = mod.failures
else
  -- registrar module: require loaded its cases into the harness; run them
  local T = R("tools.tests")
  print("running registered cases for " .. name)
  if not T.run() then failures = T.failed end
end

print(string.format("check %s: %d failures", name, failures))
if os and os.exit then os.exit(failures == 0 and 0 or 1) end
