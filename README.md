# Love2d Studio

[![LÖVE](https://img.shields.io/badge/L%C3%96VE-11.5-blue)](https://love2d.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A zero-dependency LÖVE2D framework + toolset: the engine plumbing every 2D game
rewrites per project (scenes, input, settings, saves, audio, UI), a full
in-game **scene editor**, and a small reference game (**Gem Haul**) that
dogfoods all of it. Target: LÖVE 11.5, Lua 5.1/LuaJIT idioms, **no third-party
libraries** — every module is small and dependency-free.

## Features

- **Boot & lifecycle** — callback forwarding, CLI flags, crash log, unfocus
  pause, hot-reload hatch
- **Scenes** — registry + stack with modal draw, fade/cross transitions,
  resize broadcast
- **Input** — action mapping over keyboard + gamepad (deadzones, per-frame
  edges, injectable backend)
- **Time** — time scale, pause, real/game dt, optional fixed-step with
  interpolation alpha
- **Settings & saves** — defaults-as-schema settings with validation and
  versioned store; sidecar-per-system saves with safe serializer and versioned
  migrations
- **Audio** — buses, sound families with variants, makeup gain, procedural
  synth (the demo ships no asset files — it synthesizes everything)
- **UI kit** — theme, widgets, tooltips, toasts, overlay stack, focus nav,
  tweening
- **Render** — viewport/camera, canvas pipeline, particles, postfx, text,
  culling, sprite atlas playback + animator, per-entity shader library
  (hitflash/dissolve/water/outline)
- **Gameplay** — ECS component stores, physics wrapper (categories, queued
  contacts, raycast), A* pathfinding, trigger volumes, timers, object pools,
  spatial hash, seeded RNG streams
- **Content** — spawn director, economy, milestones, loot tables, variation,
  offline progression
- **i18n & window modes** — locale registry with fallback chains; three
  display modes with memory
- **Dev tools** — in-game console (backtick), profiler overlay (F3), test
  harness with automatic discovery, deterministic screenshot capture,
  `--audit` scene boot check, .love packaging script

## Requirements & install

1. Install [LÖVE 11.5](https://love2d.org) (or put `love`/`lovec` on your PATH).
2. Clone the repo:

```bat
git clone https://github.com/nateecho32-stack/Love2DStudio.git
cd Love2DStudio
```

## Quick start

```bat
run.bat          REM launches the demo scene (grid + ball)
run-tests.bat    REM runs the full test suite, exits 0 on pass
```

On macOS/Linux use `love .` directly. More ways to boot:

```bat
lovec . --sample              REM the Gem Haul reference game
lovec . --editor              REM the scene editor
lovec . --play scenes/sandbox.lua
lovec . --shot editor         REM screenshot a scene and quit
lovec . --audit               REM boot every scene, screenshot, write report.md
```

In the runtime: **backtick** toggles the dev console, **F3** the profiler
overlay, **F11** cycles window modes.

## Documentation

| | |
|---|---|
| [Setup](docs/setup.md) | Install LÖVE, clone, first run, where runtime files land, troubleshooting |
| [Running the studio](docs/usage.md) | Boot flags, runtime hotkeys, dev console commands, crash logs |
| [Your own game](docs/your-own-game.md) | Copy-in embedding guide: scenes, input, assets, saves, settings, audio, i18n |
| [Scene editor](docs/editor.md) | Tools, shortcuts, tiles, prefabs, saving scenes |
| [Testing](docs/testing.md) | The suite, single checks, sandbox env vars, visual gates, CI notes |
| [Packaging](docs/packaging.md) | Building a distributable `.love` + release checklist |

## Using it in your own game

Copy the folder into your game's project root (the require name is just the
folder name — `Love2DStudio` after a plain clone), then in your `main.lua`:

```lua
local S = require("Love2DStudio")

function love.load(args)
  local flags = S.boot.run({
    scenes = {
      menu  = require("scenes.menu"),
      game  = require("scenes.game"),
    },
    first = "menu",
    args  = args,
  })
  if flags.test then
    love.event.quit(S.tools.tests.runAll("tests") and 0 or 1)
  end
end

function love.update(dt)     S.boot.frame(dt) end
function love.draw()         S.boot.draw() end
function love.keypressed(k)  S.boot.keypressed(k) end
-- ...or forward the remaining callbacks the same way (see main.lua here).
```

Because modules resolve their own paths, everything also works standalone
(`love .` inside this folder). A minimal game skeleton lives in
[`template/`](template) — copy it next to the studio folder and go. Your game
keeps its own `conf.lua` at game root.

## Scene editor

`lovec . --editor` opens the editor (or press **E** from the demo; **F5**
plays the current scene file). It supports multi-select (shift-click, marquee,
ctrl+A), group move/rotate/scale, copy/paste, an undo history panel, tile
painting, prefab creation from a selection, zoom-to-mouse and snap cycling.
Scenes save as versioned Lua files under `scenes/`, which `--play` runs at
runtime — the same format the Gem Haul levels use.

## Module map

| Module | Role |
|---|---|
| `core.boot` | callback forwarding, CLI flags, crash log, unfocus throttle, debounced blur, hot-reload hatch |
| `core.scene` | scene registry + stack, modal draw, resize broadcast |
| `core.events` | pub/sub buses with unsubscribe handles |
| `core.time` | time scale, pause, real/game dt, optional fixed-step + interpolation alpha |
| `core.input` | action mapping (keys + gamepad + axes, deadzone), per-frame edges, injectable backend |
| `core.deps` | lazy DI registry: paths + `__index` require + eager list |
| `core.settings` | defaults-as-schema, validation rules, versioned store, future-guard, one-time heals |
| `core.assets` | lazy image/font/sound cache with nil-return fallback contract |
| `core.rng` | seeded streams, `fork(salt)`, `forIndex(seed,i)`, weighted pick, shuffle, fbm noise |
| `core.registry` | generic id→def registry (archetypes, presets, editor palette) |
| `core.timer` | `after`/`every` script timers on game time |
| `core.pool` | object pool with factory + reset |
| `core.grid` | spatial-hash broadphase (insert/move/remove/query) |
| `core.math2` | clamp/lerp/aabb/easings/etc. |
| `core.tablex` | deepCopy/merge/keys/contains |
| `core.ecs` / `core.entities` | component stores + archetype registry with typed schemas |
| `core.transitions` | fade/cross scene transitions |
| `core.pathfind` | A* + BFS flood with injectable passability |
| `core.triggers` | enter/leave/once trigger volumes + bus events |
| `core.i18n` | locale registry, `t(key)` fallback chain |
| `core.window_mode` | 3 display modes, graphics-reset broadcast, sandbox guard |
| `render/` | viewport, camera, canvas pipeline, lights, particles, postfx, procedural text, culling |
| `render.fx` | juice primitives + named presets (palette roles, muted mode) |
| `render.sprites` / `render.anim` | atlas-layout sprite playback + animator + state machine |
| `render.shaders` | per-entity shader library (hitflash/dissolve/water/outline) |
| `save/` | sidecar-per-system saves, safe serializer, versioned migrations, thumbnail thread |
| `save.scenedata` | versioned scene files (the editor's format) |
| `audio/` | buses, family resolver, variants, makeup gain, procedural synth |
| `ui/` | theme, widgets, tooltip, toasts, overlay stack, focus, tween |
| `content/` | spawn director, economy, milestones, loot, variation, offline progression |
| `physics/` | love.physics wrapper: categories, queued contacts, raycast, sensors |
| `editor/` | scene editor: multi-select/marquee, gizmos, palette, tiles, prefabs, undo history |
| `play.lua` | runtime that plays scene files (tiles included) |
| `sample/` | **Gem Haul** — the reference game (physics, triggers, loot, milestones, saves) |
| `template/` | minimal game skeleton to copy into a new project |
| `tools.tests` | test harness: cases, eq/near asserts, exit codes, automatic discovery |
| `tools.checks` | env-var single-check runner with instruction watchdog |
| `tools.capture` | deterministic-frame screenshots for visual regression |
| `tools.profiler` | rolling frame-time graph, fps, p95, counters |
| `tools.console` | in-game dev console (backtick, command registry) |
| `tools.audit` | `--audit`: boot every scene, screenshot, write report |
| `tools.design_test` | balance-invariant helpers (snapshots, orderings, bands, budgets) |
| `tools.manifest_check` | asset manifest ↔ disk drift (missing + orphans) |
| `tools.atlas_pack` | alpha-trim atlas composition + generated layout |
| `tools.loudness_gate` | -12 dBFS staging gate for SFX |
| `tools/package.bat` | allowlist .love packaging (forward-slash zip) |

Conventions: snake_case files, dotted requires, `local M = {} ... return M`,
every tunable lives in a config table, no magic numbers in module code.
The event bus is **dot-call** convention (`bus.emit(...)`).

## Testing

```bat
run-tests.bat                                  REM full suite (~10-20s), exit code = result
FRAMEWORK_CHECK=tests.rng_test run-tests.bat   REM one module (~2s)
```

Test files under `tests/` are discovered automatically — drop in
`tests/<name>_test.lua` and it runs. Visual gates use `--shot <scene>` (scenes:
`demo`, `editor`, `play`, `gh_menu`, `gh_game`, `gh_results`), and `--audit`
boots every scene, screenshots it, and writes a report. There is no hosted CI:
standard GitHub runners have no OpenGL-capable GPU and LÖVE needs a GL context
even for `--test` — see [docs/testing.md](docs/testing.md) for running it
locally and the self-hosted/software-GL options.

## Status

All planned systems are implemented and green in CI: core, render, save+audio,
UI+fx, data-driven scenes/entities, the full scene editor, physics, animation,
pathfinding, triggers, transitions, the Gem Haul reference game, the shader
library, i18n, window modes, version stamping, packaging, and CI. Every module
ships with tests; visual changes are gated on screenshots a human has looked
at. Deliberately not in scope (yet): networking, a minigame hub shell,
dual-window co-op.

## License

[MIT](LICENSE)
