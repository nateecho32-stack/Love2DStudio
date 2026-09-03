-- Love2d Studio public API.
--
-- Resolves its own paths, so it works standalone (require "init" inside this
-- folder), dotted (require "love2d_studio"), and embedded by folder name
-- (require "Love2d Studio" — the template's shape).

local here = (...) or "init"
local root
if here == "init" then
  root = ""
else
  root = here:match("^(.*)%.init$") or here -- "a.b.init" -> "a.b"; "Folder" -> "Folder"
end
local function R(path)
  return require(root ~= "" and root .. "." .. path or path)
end

local S = { _NAME = "Love2d Studio", _VERSION = "0.1.0" }
S.log      = R("core.log")
S.events   = R("core.events")
S.bus      = S.events.new()
S.scene    = R("core.scene")
S.time     = R("core.time")
S.input    = R("core.input")
S.assets   = R("core.assets")
S.rng      = R("core.rng")
S.timer    = R("core.timer")
S.pool     = R("core.pool")
S.grid     = R("core.grid")
S.math2    = R("core.math2")
S.tablex   = R("core.tablex")
S.deps     = R("core.deps")
S.settings = R("core.settings")
S.registry = R("core.registry")
S.boot     = R("core.boot")
S.render   = R("render.init")
S.save     = R("save.init")
S.audio    = R("audio.init")
S.ui       = R("ui.init")
S.tween    = R("ui.tween")
S.fx       = R("render.fx")
S.ecs      = R("core.ecs")
S.entities = R("core.entities")
S.scenedata = R("save.scenedata")
S.design_test = R("tools.design_test")
S.editor     = R("editor.init")
S.profiler   = R("tools.profiler")
S.console    = R("tools.console")
S.audit      = R("tools.audit")
S.manifest_check = R("tools.manifest_check")
S.atlas_pack  = R("tools.atlas_pack")
S.loudness_gate = R("tools.loudness_gate")
S.thumbnail   = R("save.thumbnail")
S.spawn      = R("content.spawn")
S.economy    = R("content.economy")
S.milestones = R("content.milestones")
S.loot       = R("content.loot")
S.variation  = R("content.variation")
S.offline    = R("content.offline")
S.physics    = R("physics.init")
S.pathfind   = R("core.pathfind")
S.triggers   = R("core.triggers")
S.transitions = R("core.transitions")
S.transitions.wire(S.scene)
S.sprites    = R("render.sprites")
S.shaders    = R("render.shaders")
S.i18n       = R("core.i18n")
S.window_mode = R("core.window_mode")
S.version    = R("version")
S._VERSION   = S.version.string -- single source of truth
S.fsx        = R("core.fsx")
S.tools    = {
  tests   = R("tools.tests"),
  capture = R("tools.capture"),
}

S.assets.setLogger(S.log)
S.boot.wire(S)
S.boot.setCapture(S.tools.capture)
S.require = R -- re-exported so game/demo code resolves modules the same way

-- Games stash their instances here (S.game.save, S.game.audio, ...) — the
-- template's main.lua expects it to exist
S.game = {}

return S
