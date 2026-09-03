local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local model = R("editor.model")

T.case("commands: push runs redo; undo/redo flip state", function()
  local cmds = model.newCommandStack()
  local value = 0
  cmds:push({
    label = "set",
    redo = function() value = 5 end,
    undo = function() value = 0 end,
  })
  T.eq(value, 5) -- push executes immediately (the editor is already there)
  cmds:undo()
  T.eq(value, 0)
  cmds:redo()
  T.eq(value, 5)
end)

T.case("commands: new push clears the redo stack", function()
  local cmds = model.newCommandStack()
  cmds:push({ redo = function() end, undo = function() end })
  cmds:undo()
  T.isTrue(cmds:canRedo())
  cmds:push({ redo = function() end, undo = function() end })
  T.isTrue(not cmds:canRedo())
end)

T.case("commands: undo on an empty stack returns nil", function()
  local cmds = model.newCommandStack()
  T.isNil(cmds:undo())
  T.isNil(cmds:redo())
end)

T.case("pick: topmost item wins; misses return nil", function()
  local defs = function(id)
    return { size = { w = 20, h = 20 } }
  end
  local items = {
    { type = "a", x = 0, y = 0 },
    { type = "b", x = 5, y = 5 }, -- overlaps a
  }
  T.eq(model.pick(items, defs, 5, 5), 2)  -- later item on top
  T.eq(model.pick(items, defs, -9, -9), 1) -- inside a, outside b
  T.isNil(model.pick(items, defs, 500, 500))
end)

T.case("snap: rounds half away from zero to the grid; 0 disables", function()
  T.eq(model.snap(13, 8), 16)
  T.eq(model.snap(12, 8), 16)  -- 1.5 steps rounds up
  T.eq(model.snap(-13, 8), -16)
  T.eq(model.snap(13.7, 0), 13.7)
  T.eq(model.snap(13.7, nil), 13.7)
end)

T.case("commands: labels + jumpTo drive the history panel", function()
  local cmds = model.newCommandStack()
  local value = 0
  cmds:push({ label = "a", redo = function() value = 1 end, undo = function() value = 0 end })
  cmds:push({ label = "b", redo = function() value = 2 end, undo = function() value = 1 end })
  local labels, current = cmds:labels()
  T.eq(labels, { "a", "b" })
  T.eq(current, 2)
  cmds:jumpTo(1) -- undo one
  T.eq(value, 1)
  cmds:jumpTo(2) -- redo it
  T.eq(value, 2)
  cmds:jumpTo(0) -- undo everything
  T.eq(value, 0)
  T.isTrue(cmds:canRedo())
end)

T.case("pickAll: every item under the point", function()
  local defs = function() return { size = { w = 20, h = 20 } } end
  local items = {
    { type = "a", x = 0, y = 0 },
    { type = "b", x = 5, y = 5 },
    { type = "c", x = 100, y = 100 },
  }
  T.eq(model.pickAll(items, defs, 5, 5), { 1, 2 })
  T.eq(model.pickAll(items, defs, 100, 100), { 3 })
  T.eq(model.pickAll(items, defs, 50, 50), {})
end)

T.case("boxSelect: marquee catches intersecting items", function()
  local defs = function() return { size = { w = 20, h = 20 } } end
  local items = {
    { type = "a", x = 0, y = 0 },
    { type = "b", x = 50, y = 50 },
    { type = "c", x = 200, y = 200 },
  }
  -- marquee drawn in any direction normalizes
  T.eq(model.boxSelect(items, defs, -20, -20, 70, 70), { 1, 2 })
  T.eq(model.boxSelect(items, defs, 70, 70, -20, -20), { 1, 2 })
  T.eq(model.boxSelect(items, defs, 0, 0, 10, 10), { 1 })
end)

T.case("copyItems: deep copies props without sharing", function()
  local items = {
    { type = "goblin", x = 5, y = 6, rot = 0.5, scale = 2, props = { hp = 10, tags = { "elite" } } },
  }
  local copies = model.copyItems(items, { 1 })
  T.eq(copies[1].type, "goblin")
  T.eq(copies[1].props.hp, 10)
  copies[1].props.tags[1] = "changed"
  T.eq(items[1].props.tags[1], "elite", "copied props must not alias")
end)

T.case("serializeTable: prefab side-files round-trip", function()
  local src = { spike = { base = "spike", props = { sharp = true } }, count = 2 }
  local blob = model.serializeTable(src)
  local chunk = load("return " .. blob, "t") or load("return " .. blob)
  T.eq(chunk(), src)
end)
