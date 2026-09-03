local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local log = R("core.log")

T.case("log: level filtering keeps warn but drops debug at info level", function()
  log.setLevel("info")
  log.clear()
  log.debug("hidden %d", 1)
  log.warn("kept %d", 2)
  local dump = log.dump()
  T.isTrue(dump:find("kept 2", 1, true) ~= nil)
  T.isTrue(dump:find("hidden", 1, true) == nil)
end)

T.case("log: history is a bounded ring (oldest dropped)", function()
  log.setLevel("info")
  log.clear()
  -- 250 rapid prints can overflow the runner's stdout pipe (hard-kill mid-
  -- write); the ring is under test, not the console — silence print
  local realPrint = print
  print = function() end
  for i = 1, 250 do log.info("line %d", i) end
  print = realPrint
  local dump = log.dump()
  T.isTrue(dump:find("line 1\n", 1, true) == nil, "oldest entries must be dropped")
  T.isTrue(dump:find("line 250", 1, true) ~= nil)
end)

T.case("log: format args supported", function()
  log.clear()
  log.info("x=%d y=%s", 5, "s")
  T.isTrue(log.dump():find("x=5 y=s", 1, true) ~= nil)
end)
