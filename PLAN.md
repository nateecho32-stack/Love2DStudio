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

## Library adoption + editor polish (DONE)

### Pass F — i18n + deps glue
sample.i18n (en locale, 19 keys) now feeds every player-facing string in
menu/game/results/milestone toasts; sample.D lazily loads the adopted engines
(sprites/shaders/pathfind/atlas_pack/offline). Fixed pre-existing infra_test
window-mode case that failed under the mandated FRAMEWORK_SANDBOX env. 273/273;
gh_menu shot.

### Pass G — pathfind chaser
Walls rasterized into a 32px blocked-cell grid (inflated 14px); the chaser
repaths A* every 0.25s and detours through gaps, direct-seek fallback kept.
Fixed the stale core/pathfind.lua header (predicate is "passable"). New nav
test proves direct-seek pins at the wall face while the A* chaser crosses and
still drains hearts; WIN/LOSE untouched. 274/274; gh_game shot.

### Pass H — atlas chain + hitflash
Gem Haul bakes its procedural art into a runtime atlas at scene enter
(atlas_pack -> sprites/animator, pcall-guarded) and draws player/gems/chaser
through it; the invuln blink is now the hitflash shader with CPU fallback.
FIXED atlas_pack.pack baking full frames while layouts described trimmed
content — quads sampled padding; invisible to number-only gate tests, caught
by the gh_game shot (content ratchet added). sprites.defaultAnchor now
implemented ("center"), anchors made content-relative. 277/277; gh_game shot.

### Pass I — offline earnings + asset gates
sample.settleAway re-runs the gem cadence through content/offline.advance on
menu enter (tuning snapshot-gated); commitRun stamps lastPlayed. sample/assets
committed (atlas+layout+select.wav via tools/assetgen.lua, art shared with the
runtime bake); the game loads the committed page first and gates it with a
manifest ratchet, a loudness check, and a pair-loads test. 282/282; gh_menu shot.

### Pass J — GitHub-facing docs
docs/ (setup, usage, embedding guide, editor, testing, packaging) linked from
README; stale CI badge/workflow text removed (workflow deleted in eb9d1a1 —
runners have no GL). Fixed template main.lua dead --editor branch (pushed an
unregistered scene): editor now constructed + registered, scenePath added to
template config. Suite re-run green on the same tree.

### Pass K — editor fixes (fix.md cleared)
pick/pickAll/boxSelect are rotation- and scale-aware now: points inverse-rotate
into the item frame, marquees run SAT against the oriented box. Every archetype
schema (demo + sample) carries the `name` string prop so the inspector's entity
name survives entities:validate into gameplay. fix.md is a clean slate.
287/287; editor shot.

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
- Packer gates asserting layout numbers never see canvas content — the atlas
  shipped with quads sampling padding until a real game drew it (Pass H shot).

## Deferred by design (documented, not owed)

Networking (Trippy net/ facade blueprint), minigame hub shell (20 Games
model), dual-window co-op (SDL FFI), in-place Lua hot reload, editor scene
browser (list/new/delete scene files).

## Done — verification evidence

- Suite: 287 passed, 0 failed (exit 0) under FRAMEWORK_SANDBOX=1; every
  module has tests, coverage ratchet intact.
- Visual gates inspected this campaign: gh_menu (i18n/offline), gh_game
  (sprite atlas + chaser), editor (post picking rewrite).
- Scripted gameplay: Gem Haul WIN + LOSE + chaser nav detour + stats
  persistence + asset gates + offline earnings math.
- The adopted libraries all have consumers: i18n, pathfind, sprites/animator,
  atlas_pack, shaders, offline, deps, manifest_check, loudness_gate.
- Template boots standalone; packaged .love boots standalone.
- Single-check runner + instruction watchdog used throughout the campaign.
