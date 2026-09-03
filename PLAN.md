# Love2d Studio — Plan of Record

Living roadmap. Working rules (from 2d Trippy Hell's PLAN.md): extend this
file, do not create new plan files; keep evidence per item ≤3 lines; "a green
test is not proof of a player-facing feature"; a finished thing moves to Done
and is not re-litigated.

## Working rules

- Nothing outside `Love2d Studio/` is ever modified; existing projects are read-only sources.
- Each pass ends with `run-tests.bat` green and, when visual, a `--shot` artifact someone looked at.
- New modules arrive with tests; the checks runner (`FRAMEWORK_CHECK`) + watchdog is the debugging tool of first resort.

## Pass 1–5 (DONE — foundation)

Core (scene/events/time/input/settings/assets/rng/registry/ecs/entities/deps/
log + utils), tools (tests/checks/capture), render (viewport/camera/pipeline/
lights/particles/postfx/proc/text/cull), save (serialize/migration/sidecars/
scenedata), audio (manager+synth), UI kit + fx, design_test, archetypes +
scene-data model. See git history in the Done section below for per-pass fixes.

## Engine completion campaign (DONE)

### Pass A — crash fixes + integration
Fixed: editor ctrl+D `deepcopy` typo, template `S.game` nil, embedded-path
root resolution (folder-name requires), audio variant randomization (docs now
true), physics `hasWorld` closure. Wired: settings persisted + live-applied
(demo settings overlay, Esc), keyboard/gamepad focus nav driven, thumbnails
on editor save, blur/focus pause via the bus, real console commands, synth
audio in scenes, ui/content/tools READMEs. 229/229; template boots; overlay shot.

### Pass B — game systems
physics/ (categories, queued contacts, raycast, sensors), transform rot/scale,
render/sprites + animator + state machine, core/transitions (fade/cross),
core/pathfind (A* + flood + mapPass), core/triggers. Fixed en route:
pathfind out-of-bounds infinite loop (mapPass nil cells walkable), contact
userdata lifetime, bus colon/dot convention, drain-queue reentrancy
(snapshot-swap). 253/253.

### Pass C — reference game
sample/ = Gem Haul: physics player/chaser/gems/spikes, exit trigger, loot
values, milestones + toasts, fx, synth SFX, sidecar stats, transitions,
editor-authorable level (falls back to DEFAULT_LAYOUT). Scripted WIN + LOSE
tests are the gate. 256/256; menu/game shots.

### Pass D — editor depth
Editor rewrite: multi-select (shift-click, marquee box-select, ctrl+A), group
move/rotate(Q/E)/scale([ ])/delete, copy/paste clipboard, undo HISTORY panel
(labels + click-to-jump), ui.textfield (scene name, entity name, string props)
with love.textinput routed through boot, zoom-to-mouse, snap cycling, tile
painting (4-tile procedural set, LMB/RMB, per-tile undo), prefab-from-selection
(persisted to scenes/prefabs.lua, palette-listed), play mode renders tiles.
261/261; editor shot.

### Pass E — infra + services
version.lua (single source, title bar, console `version`), render/shaders
library (hitflash/grayscale/dissolve/water/outline, pcall-wrapped),
core/i18n (locale registry, fallback chain, format args), core/window_mode
(3 modes with memory, graphics.reset bus broadcast, sandbox guard; F11;
scenes rebuild canvases on the event), tools/package.bat (allowlist staging,
forward-slash .love via .NET ZipFile — verified booting), GitHub Actions
workflow (installs LÖVE 11.5, runs suite, uploads shots). 265/265.

## Notable bugs the process caught (keep the lessons)

- "Draw raises no error" is vacuous when a scene never defined draw — smoke
  tests now assert the draw method exists.
- cmd.exe misparses parenthesized blocks in LF-only .bat files (package.bat).
- Compress-Archive writes backslash zip entries; LÖVE needs forward slashes.
- Test stdout bursts (250 prints) can overflow runner pipes — silence print
  when testing the ring, not the console.
- events.lua bus is dot-call convention; colon-calling silently no-ops.
- Physics: contacts are only valid during callbacks; destroying bodies fires
  end-contacts synchronously (drain must snapshot-swap; guard isDestroyed).

## Deferred by design (documented, not owed)

Networking (Trippy net/ facade blueprint), minigame hub shell (20 Games
model), dual-window co-op (SDL FFI), in-place Lua hot reload, editor scene
browser (list/new/delete scene files), editor rotation-aware picking.

## Done — verification evidence

- Suite: 265 passed, 0 failed (exit 0); every module has tests.
- Visual gates inspected: demo (settings overlay via STUDIO_SETTINGS_SHOT),
  editor (post-rewrite toolbar/hierarchy/history/inspector), play, gh_menu,
  gh_game.
- Scripted gameplay: Gem Haul WIN + LOSE + stats persistence.
- Template boots standalone; packaged .love boots standalone.
- Single-check runner + instruction watchdog used to catch the pathfind
  infinite loop in the wild.
