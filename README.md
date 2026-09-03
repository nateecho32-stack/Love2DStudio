# Love2d Studio

A zero-dependency LÖVE2D framework + toolset, distilled from an audit of 13 of our own
projects (see [FINDINGS.md](FINDINGS.md)). Goal: stop rewriting the same engine plumbing
per game, and grow toward a Unity-style editor with drag-and-drop scene building
(see [PLAN.md](PLAN.md)).

- Target: LÖVE 11.5, Lua 5.1/LuaJIT idioms, **no third-party libraries**
- Every module is small, dependency-free, and adapted from battle-tested code in
  Void Place, 2d Trippy Hell, Burning, Vimur, and others (provenance noted per file)

## Quick start

```bat
run.bat          REM launches the demo scene (grid + ball)
run-tests.bat    REM runs the full test suite, exits 0 on pass
```

Both need `lovec.exe` (installed at `C:\Program Files\LOVE\` here) or `love` on PATH.
Useful flags: `--test` (test suite), `--shot demo` (screenshot a scene and quit),
`--skipintro` convention is reserved for games.

## Using it in a game

Copy the folder into the game project root, then in the game's `main.lua`:

```lua
local S = require("Love2d Studio")   -- the folder name is the module prefix

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
(`love "Love2d Studio"`). The `conf.lua` at this folder's root is the standalone/demo
config; your game keeps its own at game root.

## Module map

| Module | Role | Adapted from |
|---|---|---|
| `core.boot` | callback forwarding, CLI flags, crash log, unfocus throttle, debounced blur, hot-reload hatch | Trippy `main.lua`/`window_mode.lua` |
| `core.scene` | scene registry + stack, modal draw, resize broadcast | Void Place `engine/scene.lua` |
| `core.events` | pub/sub buses with unsubscribe handles | Void Place `engine/events.lua` |
| `core.time` | time scale, pause, real/game dt, optional fixed-step + interpolation alpha | Void Place `engine/time.lua` |
| `core.input` | action mapping (keys + gamepad + axes, deadzone), per-frame edges, injectable backend | Void Place `engine/input.lua` |
| `core.deps` | lazy DI registry: paths + `__index` require + eager list | Trippy `game/state/deps.lua` |
| `core.settings` | defaults-as-schema, validation rules, versioned store, future-guard, one-time heals | Trippy `settings.lua` + `settings_store.lua` |
| `core.assets` | lazy image/font/sound cache, **nil-return fallback contract** | Void Place `engine/assets.lua` + Trippy atlas seam |
| `core.rng` | seeded streams, `fork(salt)`, `forIndex(seed,i)`, weighted pick, shuffle, fbm noise | Void Place + Burning + Dead Meridian |
| `core.registry` | generic id→def registry (archetypes, presets, editor palette) | Void Place archetype pattern |
| `core.timer` | `after`/`every` script timers on game time | Vimur `utils/timer.lua` |
| `core.pool` | object pool with factory + reset | Void Place `engine/pool.lua` |
| `core.grid` | spatial-hash broadphase (insert/move/remove/query) | Void Place `engine/grid.lua` |
| `core.math2` | clamp/lerp/aabb/easings/etc. | Void Place `engine/math2.lua` |
| `core.tablex` | deepCopy/merge/keys/contains | Vimur `utils/table_utils.lua` |
| `tools.tests` | test harness: cases, eq/near asserts, exit codes | Void Place `tools/tests.lua` |
| `tools.checks` | generic env-var single-check runner with watchdog | Trippy `lua_quality_runner` |
| `tools.capture` | deterministic-frame screenshots for visual regression | Void Place `tools/capture.lua` |
| `tools.profiler` | rolling frame-time graph, fps, p95, counters | Void Place + Trippy perf tools |
| `tools.console` | in-game dev console (backtick, command registry) | 20 Games GameConsole |
| `tools.audit` | `--audit`: boot every scene, screenshot, write report | 20 Games audit harness |
| `tools.design_test` | balance-invariant helpers (snapshots, orderings, bands, budgets) | Void Place design tests |
| `tools.manifest_check` | asset manifest <-> disk drift (missing + orphans) | Trippy manifest discipline |
| `tools.atlas_pack` | alpha-trim atlas composition + generated layout | Trippy pack_atlas |
| `tools.loudness_gate` | -12 dBFS staging gate for AI-generated SFX | Trippy fix.md #1 |
| `save/` | sidecar-per-system saves, safe serializer, versioned migrations, thumbnail thread | Trippy save/ + Dead Meridian |
| `audio/` | buses, family resolver, variants, makeup gain, procedural synth | Burning + Trippy audio |
| `ui/` | theme, widgets, tooltip, toasts, overlay stack, focus, tween | Trippy ui/ + Vimur + 20 Games |
| `render.fx` | juice primitives + named presets (palette roles, muted mode) | Void Place + PVZ |
| `core.ecs` / `core.entities` | component stores + archetype registry with typed schemas | Void Place entities |
| `save.scenedata` | versioned scene files (the editor's format) | — |
| `editor/` | scene editor: multi-select/marquee, gizmos, palette, tiles, prefabs, undo history | Trippy dev suite ideas |
| `play.lua` | runtime that plays scene files (tiles included) | — |
| `content/` | spawn director, economy, milestones, loot, variation, offline | Burning/Vimur/Endless Grind |
| `physics/` | love.physics wrapper: categories, queued contacts, raycast | Burning src/systems/physics |
| `render.sprites` / `render.anim` | atlas-layout sprite playback + animator + state machine | Trippy sprites + Void Place |
| `render.shaders` | per-entity shader library (hitflash/dissolve/water/...) | Trippy pcall convention |
| `core.transitions` | fade/cross scene transitions | — |
| `core.pathfind` | A* + BFS flood with injectable passability | Trippy reachability |
| `core.triggers` | enter/leave/once trigger volumes + bus events | — |
| `core.i18n` | locale registry, t(key) fallback chain | Trippy i18n |
| `core.window_mode` | 3 display modes, graphics-reset broadcast, sandbox guard | Trippy window_mode |
| `sample/` | **Gem Haul** — the reference game (physics, triggers, loot, milestones, saves) | everything, dogfooded |
| `tools/package.bat` | allowlist .love packaging (forward-slash zip) | Trippy build model |

Conventions: snake_case files, dotted requires, `local M = {} ... return M`,
every tunable lives in a config table, no magic numbers in module code.
The event bus is **dot-call** convention (`bus.emit(...)`).

## Status

All passes complete (1–5 + the engine completion campaign A–E): core, render,
save+audio, ui+fx, data-driven scenes/entities, the full scene editor
(multi-select, tile painting, prefabs, undo history), physics, animation,
pathfinding, triggers, transitions, the Gem Haul reference game, shader
library, i18n, window modes, version stamping, packaging, and CI.
265/265 tests green; visual gates via `--shot`; scripted win/lose gameplay
verification. Deferred by design: networking, minigame hub, dual-window co-op.
