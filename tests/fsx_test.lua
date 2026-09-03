-- Real-filesystem writes: LÖVE 11 silently fails nested-path writes unless
-- parents exist. This suite lives because editor Save, sidecar saves,
-- thumbnails, and audit reports ALL shipped broken behind fake-fs tests.

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local fsx = R("core.fsx")
local scenedata = R("save.scenedata")
local save = R("save.init")
local S = R("init")

T.case("fsx: nested writes succeed through ensureParent/write", function()
  if not (love and love.filesystem) then return end
  T.isTrue(fsx.write("deep/nested/dir/file.txt", "hello"))
  T.eq(love.filesystem.read("deep/nested/dir/file.txt"), "hello")
  T.isTrue(fsx.write("deep/nested/other.txt", "x")) -- existing dirs reused
end)

T.case("scenedata: editor Save path works on the real filesystem", function()
  if not (love and love.filesystem) then return end
  T.isTrue(scenedata.saveToFile("scenes/fsx_probe.lua", {
    version = 1, name = "probe", entities = { { type = "wall", x = 1, y = 2, props = {} } },
  }))
  local loaded = scenedata.loadFromFile("scenes/fsx_probe.lua")
  T.isTrue(loaded ~= nil, "scene must round-trip on the real fs")
  T.eq(loaded.entities[1].type, "wall")
end)

T.case("save: sidecar writes create their slot directory", function()
  if not (love and love.filesystem) then return end
  local s = save.new{ dir = "saves/fsx_probe", version = 1 }
  T.isTrue(s:write("stats", { gems = 5 }))
  local stats = s:read("stats")
  T.eq(stats.gems, 5)
end)

T.case("audit: pump-based run writes a report with screenshots", function()
  if not (love and love.graphics) then return end
  local scene = R("core.scene")
  local probeScene = {
    enter = function() end,
    update = function() end,
    draw = function() love.graphics.clear(0.2, 0.2, 0.2) end,
  }
  scene.clear()
  local run = S.audit.begin{
    S = S,
    scenes = { probe = probeScene },
    frames = 5,
    outDir = "audits/test_probe",
    quit = false, -- never quit the suite
  }
  T.isTrue(S.audit.active())
  for _ = 1, 30 do
    if S.audit.active() then S.audit.pump(1 / 60) else break end
  end
  T.isTrue(not S.audit.active())
  for _ = 1, 10 do
    if S.audit.settle() then break end
  end
  local report = love.filesystem.read("audits/test_probe/report.md")
  T.isTrue(report ~= nil, "the report must actually land on disk")
  T.isTrue(report:find("probe", 1, true) ~= nil)
  T.eq(run.exitCode, 0)
  -- screenshots flush at real frame ends; settle() burns those frames — but
  -- in-suite there is no presented frame, so PNG presence is CLI-only
  scene.clear()
end)
