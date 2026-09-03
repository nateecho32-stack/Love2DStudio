# Running the studio

Everything below assumes you are in the repo root and LÖVE is installed (see
[setup](setup.md)). On Windows use `run.bat` / `lovec .`; elsewhere `love .`.

## Boot flags

Flags are parsed from `love.load(args)` by `core.boot`:

```bat
lovec .                 REM demo scene (default)
lovec . --sample        REM Gem Haul, the reference game (menu -> game -> results)
lovec . --editor        REM the scene editor
lovec . --play scenes/sandbox.lua   REM play an editor scene file
lovec . --test          REM run the full test suite and quit (exit code = result)
lovec . --shot editor   REM deterministic screenshot of a scene, then quit
lovec . --audit         REM boot every scene, screenshot each, write a report
```

| Flag | Effect |
|---|---|
| `--test` | Runs all `tests/*.lua` via `tools.tests.runAll` and quits; exit code is the result. Same as `run-tests.bat`. |
| `--shot <scene>` | Steps the named scene with fixed `dt` for 30 frames, writes `shot_<scene>.png` to the save dir, quits. Scenes: `demo`, `editor`, `play`, `gh_menu`, `gh_game`, `gh_results`. |
| `--audit` | Boots every registered scene for 60 frames each, screenshots it into `audits/run_<timestamp>/` (save dir) and writes a PASS/FAIL `report.md`. |
| `--editor` | Opens the scene editor ([docs](editor.md)). |
| `--play <file>` | Plays a saved scene file; defaults to `scenes/sandbox.lua`. |
| `--sample` | Launches the Gem Haul reference game. |
| `--skipintro` | Parsed and handed to scenes as `flags.skipintro`; scenes decide what to skip. |

The env var `FRAMEWORK_CHECK=<module>` switches to the single-check runner
instead of a scene (see [testing](testing.md)).

## Runtime hotkeys

| Key | Action |
|---|---|
| `` ` `` (backtick) | Toggle the dev console |
| **F3** | Toggle the profiler overlay (frame-time graph, fps, p95, counters) |
| **F11** | Cycle window mode (windowed → borderless fullscreen → exclusive fullscreen); scenes rebuild canvases on resize |
| **Ctrl+R** | Hot-reload hatch: restarts the process in place |
| **E** (in the demo) | Open the scene editor |
| **Esc** | Scene-dependent convention: pop back a scene; quit at the root |

## Dev console commands

Toggle with backtick; the console consumes input while open. The standalone
runtime registers:

| Command | Effect |
|---|---|
| `help` | List registered commands |
| `fps` | Current fps |
| `scene` | Scene stack: top name + depth |
| `entities` | Live entity count in the top scene (when it has an ecs) |
| `play <file>` | Open a scene file in play mode |
| `sample` | Launch Gem Haul |
| `reload` | Restart the runtime |
| `version` | Studio version (`version.lua` is the single source) |

Games register their own commands with `console:register(name, help, fn)`.

## The per-frame pipeline

`main.lua` forwards LÖVE callbacks to `S.boot`, which runs the standard frame:

```
capture step (deterministic dt during --shot) → unfocus throttle (sleep at
20 fps while unfocused) → blur debounce (app.blurred/app.focused bus events
after 0.35 s) → input.update() → time.update(dt, scene.update)
```

`S.boot.draw()` / `S.scene.draw()` draw the whole scene stack bottom-up, so
pause overlays render over the live scene. Games can opt into `pauseOnBlur`
and can disable the unfocus throttle via `S.boot.run` opts — see
[your own game](your-own-game.md).

## Crashes

`boot.installCrashLog` chains LÖVE's errorhandler: every crash also writes
`crash_<timestamp>.txt` (message, traceback, recent log tail) into the save
directory before the default red-screen handler runs.
