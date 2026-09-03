local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local save = R("save.init")

local function fakeFs()
  local files = {}
  return {
    files = files,
    read = function(path) return files[path] end,
    write = function(path, body) files[path] = body return true end,
    remove = function(path) files[path] = nil return true end,
    list = function(dir)
      local out = {}
      for path in pairs(files) do
        local name = path:match("^" .. dir .. "/(.+)$")
        if name then out[#out + 1] = name end
      end
      return out
    end,
  }
end

T.case("save: sidecar-per-system write/read round-trips", function()
  local fs = fakeFs()
  local s = save.new{ dir = "saves/slot1", version = 1, fs = fs }
  T.isTrue(s:write("player", { hp = 7, bag = { "rope" } }))
  T.isTrue(s:write("world", { seed = 42 }))
  local player = s:read("player")
  T.eq(player, { hp = 7, bag = { "rope" } })
  T.eq(s:read("world"), { seed = 42 })
  T.eq(s:systems(), { "player", "world" })
end)

T.case("save: a failed write names the exact file", function()
  local fs = fakeFs()
  fs.write = function() return false, "disk full" end
  local s = save.new{ dir = "saves/slot1", version = 1, fs = fs }  local ok, err = s:write("story", {})
  T.isTrue(not ok)
  T.isTrue(tostring(err):find("story.dat", 1, true) ~= nil, "must name the failed sidecar")
end)

T.case("save: corrupt data fails with the file named", function()
  local fs = fakeFs()
  local s = save.new{ dir = "s", version = 1, fs = fs }
  fs.files["s/player.dat"] = "return { broken"
  local data, err = s:read("player")
  T.isNil(data)
  T.isTrue(tostring(err):find("player.dat", 1, true) ~= nil)
end)

T.case("save: migrations run on read; notes are disclosed", function()
  local fs = fakeFs()
  local s = save.new{
    dir = "s", version = 2, fs = fs,
    migrations = {
      { from = 1, fn = function(d) d.relics = d.relics or 0 return d, "relics backfilled" end },
    },
  }
  s:write("progress", { relics = 3 })
  -- simulate an old file on disk
  fs.files["s/progress.dat"] = "return { version = 1, data = { hp = 4 } }"
  local data = s:read("progress")
  T.eq(data, { hp = 4, relics = 0 })
  T.eq(s.notes, { "relics backfilled" })
end)

T.case("save: future-version file is refused, not silently downgraded", function()
  local fs = fakeFs()
  local s = save.new{ dir = "s", version = 2, fs = fs }
  fs.files["s/player.dat"] = "return { version = 9, data = {} }"
  local data, err = s:read("player")
  T.isNil(data)
  T.isTrue(tostring(err):find("future", 1, true) ~= nil)
end)

T.case("save: delete + exists + missing reads", function()
  local fs = fakeFs()
  local s = save.new{ dir = "s", version = 1, fs = fs }
  T.isTrue(not s:exists("ghost"))
  local data, err = s:read("ghost")
  T.isNil(data)
  T.isTrue(tostring(err):find("no save", 1, true) ~= nil)
  s:write("x", {})
  T.isTrue(s:exists("x"))
  T.isTrue(s:delete("x"))
  T.isTrue(not s:exists("x"))
end)

T.case("save: autosave ladder snaps to the nearest rung", function()
  T.eq(save.nearestLadder(0), 0)
  T.eq(save.nearestLadder(45), 30)
  T.eq(save.nearestLadder(61), 60)
  T.eq(save.nearestLadder(2000), 1800)
end)
