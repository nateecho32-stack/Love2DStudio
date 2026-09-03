local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local migration = R("save.migration")

T.case("migration: current-version saves pass through unchanged", function()
  local wrapped = migration.wrap(3, { hp = 10 })
  local out, changed = migration.migrate(wrapped, {}, 3)
  T.eq(out.data, { hp = 10 })
  T.isTrue(not changed)
end)

T.case("migration: walks the chain step by step", function()
  local migrations = {
    { from = 1, fn = function(d) d.name = "unnamed" return d end },
    { from = 2, fn = function(d) d.gold = 0 return d end },
  }
  local out, changed = migration.migrate(migration.wrap(1, { hp = 5 }), migrations, 3)
  T.eq(out.data, { hp = 5, name = "unnamed", gold = 0 })
  T.eq(out.version, 3)
  T.isTrue(changed)
end)

T.case("migration: future versions are refused (downgrade protection)", function()
  local out, err = migration.migrate(migration.wrap(99, {}), {}, 3)
  T.isNil(out)
  T.eq(err, "unsupported_future_version")
end)

T.case("migration: missing step fails loudly with the version named", function()
  local out, err = migration.migrate(migration.wrap(2, {}), {}, 3)
  T.isNil(out)
  T.isTrue(tostring(err):find("2", 1, true) ~= nil)
end)

T.case("migration: failing step is contained and reported", function()
  local migrations = {
    { from = 1, fn = function() error("boom") end },
  }
  local out, err = migration.migrate(migration.wrap(1, {}), migrations, 2)
  T.isNil(out)
  T.isTrue(tostring(err):find("boom", 1, true) ~= nil)
end)

T.case("migration: steps may emit lost-content disclosure notes", function()
  local migrations = {
    { from = 1, fn = function(d)
      d.cursedItems = nil -- content removed between versions
      return d, "2 items from an older version no longer exist"
    end },
  }
  local out, changed, notes = migration.migrate(migration.wrap(1, {}), migrations, 2)
  T.isTrue(changed)
  T.eq(notes, { "2 items from an older version no longer exist" })
end)
