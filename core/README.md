# core/ — content-agnostic runtime modules

Dependency map (arrows = "may be injected/referenced by"; modules never require
each other directly — `init.lua` composes them, which keeps every module
standalone-testable):

```
boot.lua ──uses──> scene, time, input, assets, bus(events), log, tools/capture
init.lua ──requires/wires──> everything below
scene.lua    standalone        time.lua    standalone
input.lua    standalone        rng.lua     standalone (falls back to pure Lua)
assets.lua   optional log      settings.lua standalone
events.lua   standalone        deps.lua    standalone
log.lua      standalone        registry.lua standalone
timer/pool/grid/math2/tablex   standalone
```

## Modules

- **boot** — flags (`--test --shot --audit --skipintro`), crash-log chain,
  unfocus throttle, debounced blur pause, ctrl+R hot-reload hatch, per-frame
  pipeline (`boot.frame`). Games forward LÖVE callbacks here (see root main.lua).
- **scene** — `register/push/pop/replace/top/topName/update/draw/resize/clear`;
  modal draw draws the whole stack bottom-up.
- **events** — `events.new()` buses: `on` returns a handle, `off(handle)`,
  `emit(name, ...)`, `clear()`.
- **time** — scale/pause; optional fixed-step via `setFixed(dt)`; `update(dt, stepFn)`
  drives `stepFn` per fixed step; `alpha` for render interpolation.
- **input** — `define{action={keys,buttons,axis,dir}}`, `update()` each frame,
  `down/pressed/released/value`, `actionFromKey`. Backend injectable via
  `setBackend` (tests use fakes; default wraps love.keyboard/love.joystick).
- **rng** — `new(seed)`: int/float/chance/pick/weighted/weightedMap/shuffle/
  `fork(salt)`; `forIndex(seed, index)` for chunk-style determinism; `noise`/`fbm`.
- **assets** — lazy cache; **missing assets return nil** (procedural-fallback
  contract); `onReady(fn)` defers until `ready()` after boot.
- **settings** — `settings.new{file, version, defaults, rules, heals}`:
  defaults are the schema; rules validate/clip (min/max/integer/values/maxLen/
  nonempty, NaN rejected); `load` guards future versions, drops unknown keys,
  applies one-time heals; `save/serialize` flat dotted keys.
- **deps** — `deps.new(paths, eager, requireFn)`: lazy module registry.
- **registry** — `registry.new()`: id→def store, registration order preserved,
  unknown id → nil.
- **timer / pool / grid / math2 / tablex / log** — small utilities.
