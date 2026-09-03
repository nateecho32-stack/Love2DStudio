# tools/ — dev tooling

Runtime tools are exported on `S` (e.g. `S.profiler`); tests/checks/capture
also live under `S.tools`.

## Test & CI surfaces

- **tests.lua** (`S.tools.tests`) — harness: `case(name, fn)`, asserts
  `eq/near/isTrue/isNil/fails`, `run(filter)` / `runAll("tests", filter)`;
  `runAll` auto-discovers `tests/*.lua`. Exit code via main.lua `--test`.
- **checks.lua** — single-check runner: `FRAMEWORK_CHECK=tests.rng_test
  run-tests.bat`; `FRAMEWORK_TIMEOUT_OPS` arms a `debug.sethook` watchdog.
- **capture.lua** (`S.tools.capture`) — `--shot <scene>`: fixed-dt frames,
  PNG to the save dir, quit. Visual regression gate.
- **audit.lua** (`S.audit`) — `--audit`: boots every registered scene, dwells,
  screenshots each, writes `audits/<ts>/report.md`.

## In-game dev tools

- **profiler.lua** (`S.profiler`) — F3 overlay: rolling frame-time graph,
  fps, p95, named counters; `beginFrame/endFrame/counter/draw`.
- **console.lua** (`S.console`) — backtick console with command registry
  (`help/fps/reload/entities/scene/play`), scrollback, input consumption
  while open.

## Quality & pipeline gates

- **design_test.lua** (`S.design_test`) — balance invariants: config
  snapshots, trade-ordering asserts, seeded monte-carlo bands, pacing budgets.
- **manifest_check.lua** (`S.manifest_check`) — asset manifest ↔ disk drift:
  missing files AND orphan files (the unreferenced-mp3 failure mode).
- **atlas_pack.lua** (`S.atlas_pack`) — alpha-trim atlas composition +
  generated layout source (runtime composition; playback via render/sprites).
- **loudness_gate.lua** (`S.loudness_gate`) — −12 dBFS peak gate over
  SoundData for AI-generated SFX staging.

System links: all standalone; capture is driven by boot + main; console and
profiler are wired in main.lua; audit runs from main.lua `--audit`.
