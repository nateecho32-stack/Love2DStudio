-- Editor smoke test: boot the editor scene over the stack, run frames, and
-- exercise place/select/drag/undo without touching real input devices.

local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local scene = R("core.scene")
local input = R("core.input")
local S = R("init")

T.case("editor: boots, draws frames, places and undoes", function()
  if not (love and love.graphics) then return end
  local editorScene = S.editor.new{
    S = S,
    scenePath = "scenes/editor_probe.lua", -- missing file: editor starts empty
    archetypes = {
      block = {
        size = { w = 24, h = 24 },
        tint = { 0.4, 0.4, 0.5 },
        schema = { hp = { type = "number", default = 10, min = 1, max = 50 } },
      },
    },
  }
  scene.register("editor_probe", editorScene)
  scene.push("editor_probe")
  input.update()

  T.isTrue(type(scene.top().draw) == "function", "editor scene must define draw")

  local ok, err = pcall(function()
    for _ = 1, 10 do
      scene.update(1 / 60)
      scene.draw()
    end
    -- place one block: switch tool, press + release at a world point
    editorScene.keypressed("tab")
    editorScene.mousepressed(500, 300, 1)
    editorScene.mousereleased(500, 300, 1)
    -- press again in place mode (another block), move, release
    editorScene.mousepressed(500, 300, 1)
    editorScene.mousemoved(520, 320, 20, 20)
    editorScene.mousereleased(520, 320, 1)
    editorScene.keypressed("z")
    -- duplicate path (the ctrl+D branch — had a deepcopy typo once)
    editorScene.duplicateSelection()
    editorScene.duplicateSelection()

    -- select tool: marquee over everything, rotate, copy/paste, delete all
    editorScene.keypressed("tab") -- place -> paint
    editorScene.keypressed("tab") -- paint -> select
    editorScene.mousepressed(300, 200, 1)   -- empty space: marquee starts
    editorScene.mousemoved(700, 450, 400, 250)
    editorScene.mousereleased(700, 450, 1)  -- selects all placed items
    editorScene.keypressed("q")             -- rotate the selection
    editorScene.keypressed("]")             -- scale up
    editorScene.keypressed("c")             -- (ctrl-less path: no-op, safe)
    editorScene.keypressed("delete")        -- delete selection (one command)

    -- paint a tile, then erase it via a command
    editorScene.keypressed("tab") -- select -> place... need paint:
    editorScene.keypressed("tab") -- place -> paint
    editorScene.mousepressed(400, 300, 1)   -- paint tile
    editorScene.mousepressed(400, 300, 2)   -- erase tile
  end)
  T.isTrue(ok, "editor interaction raised: " .. tostring(err))
  T.eq(scene.depth(), 1)
  scene.clear()
end)
