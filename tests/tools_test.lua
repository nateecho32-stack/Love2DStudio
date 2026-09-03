local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local profiler = R("tools.profiler")
local console = R("tools.console")
local manifest_check = R("tools.manifest_check")

T.case("profiler: frame history, fps and p95", function()
  local t = 0
  local phase = 0
  local p = profiler.new{ history = 10, clock = function()
    phase = phase + 1
    if phase % 2 == 0 then t = t + 0.016 end -- only endFrame advances time
    return t
  end }
  counting = true
  for _ = 1, 40 do -- 40 x 16ms: crosses the 500ms fps window
    p:beginFrame()
    p:endFrame()
  end
  counting = false
  T.eq(#p.history, 10) -- history capped
  T.near(p.frameMs, 16, 0.5)
  T.isTrue(p.fps >= 55 and p.fps <= 65)
  T.isTrue(p:p95() > 10)
  p:counter("draws", 42)
  T.eq(p.counters.draws, 42)
end)

T.case("console: commands execute with args; unknown names error", function()
  local c = console.new{}
  local got = nil
  c:register("echo", "echo <text>", function(...)
    got = table.concat({ ... }, " ")
    return "ok"
  end)
  c:execute("echo hello world")
  T.eq(got, "hello world")
  local last = c.lines[#c.lines]
  T.eq(last.text, "ok")
  c:execute("nope")
  T.isTrue(c.lines[#c.lines].text:find("unknown command", 1, true) ~= nil)
end)

T.case("console: toggle/textinput/keypressed consume input", function()
  local c = console.new{}
  c:register("add", "add <a> <b>", function(a, b) return tonumber(a) + tonumber(b) end)
  T.isTrue(not c:keypressed("backquote")) -- closed: not consumed
  c:toggle()
  T.isTrue(c.open)
  T.isTrue(c:textinput("add"))
  T.isTrue(c:textinput(" "))
  T.isTrue(c:textinput("3"))
  T.isTrue(c:textinput(" "))
  T.isTrue(c:textinput("4"))
  T.isTrue(c:keypressed("return"))
  local last = c.lines[#c.lines]
  T.eq(last.text, "7")
  T.isTrue(c:keypressed("backquote")) -- open: consumed, closes
  T.isTrue(not c.open)
end)

T.case("manifest check: missing entries and orphan files both fail", function()
  local files = {
    ["assets/sprites/goblin.png"] = true,
    ["assets/sprites/ghost.png"] = true, -- on disk but NOT in the manifest: orphan
  }
  local fs = {
    exists = function(path) return files[path] == true end,
    list = function(dir)
      local out = {}
      for path in pairs(files) do
        local name = path:match("^" .. dir .. "/(.+)$")
        if name then out[#out + 1] = name end
      end
      return out
    end,
  }
  local failures = manifest_check.run({
    goblin = { src = "assets/sprites/goblin.png" },
    torch = { src = "assets/sprites/torch.png" }, -- in manifest but missing on disk
  }, { watchDir = "assets/sprites", existsFn = fs.exists, listFn = fs.list })

  local kinds = {}
  for _, f in ipairs(failures) do kinds[f.kind] = (kinds[f.kind] or 0) + 1 end
  T.eq(kinds.missing, 1)
  T.eq(kinds.orphan, 1)
end)

T.case("manifest check: clean manifest produces no failures", function()
  local fs = {
    exists = function() return true end,
    list = function() return { "goblin.png" } end,
  }
  local failures = manifest_check.run({
    goblin = { src = "assets/sprites/goblin.png" },
  }, { watchDir = "assets/sprites", existsFn = fs.exists, listFn = fs.list })
  T.eq(failures, {})
end)
