# Testing

Every module ships with tests, and the harness discovers them — there is no
list to maintain. Two disciplines from the projects this framework was
extracted from:

1. **Bounded checks.** Automated runs never take exclusive fullscreen or
   vsync (`FRAMEWORK_SANDBOX=1` forces windowed 800x450), and a single check
   can carry an instruction watchdog so a hang dies instead of locking the
   desktop.
2. **A green test is not proof of a player-facing feature.** Render changes
   are gated on `--shot` screenshots a human actually looks at.

## Running the suite

```bat
run-tests.bat                       REM full suite (~10–20 s), exit code = result
lovec . --test                      REM same thing, cross-platform
```

The last line is `N passed, 0 failed`; the process exits `0` only on a fully
green run. Test files under `tests/` are required and run in sorted order
(`zz_play_probe_test.lua` sorts last on purpose).

For automated runs, set the sandbox variable (the repo's own docs and scripts
assume it):

```bat
set FRAMEWORK_SANDBOX=1
run-tests.bat
```

## One module at a time

The debugging tool of first resort is the single-check runner:

```bat
FRAMEWORK_CHECK=tests.rng_test run-tests.bat      REM ~2 s instead of the suite
```

- `FRAMEWORK_CHECK=<module>` requires that one module and runs it. Both
  styles work: check modules exposing `run() -> failures`, and ordinary test
  files (requiring them registers their cases, which then run).
- `FRAMEWORK_TIMEOUT_OPS=<n>` arms a `debug.sethook` instruction budget —
  the check raises "check exceeded instruction budget" instead of hanging.
  Example: `FRAMEWORK_TIMEOUT_OPS=50000000` for a generous budget.

On Windows cmd: `set FRAMEWORK_CHECK=tests.rng_test && run-tests.bat`.

## Writing tests

A test file registers cases in the shared harness (`tools.tests`). Start from
this idiom — the path prefix is what makes the file work both standalone and
embedded:

```lua
local root = (...):match("^(.-)tests%.") or ""
local function R(p) return require(root ~= "" and root .. "." .. p or p) end
local T = R("tools.tests")
local rng = R("core.rng")

T.case("rng: same seed gives the same sequence", function()
  local a, b = rng.new(42), rng.new(42)
  T.eq(a:int(1, 1000), b:int(1, 1000))
  T.near(a:float(0, 1), b:float(0, 1))
end)
```

Assertions: `T.eq(a, b, msg)` deep-equal, `T.near(a, b, eps, msg)`,
`T.isTrue(v)`, `T.isNil(v)`, `T.fails(fn, msg)` (expects a raise, returns the
error). Any error fails the case. Save the file as `tests/<name>_test.lua` —
it is discovered automatically on the next run. Files can also live in your
game's own `tests/` folder; `runAll(dir)` takes the directory name.

For gameplay/balance logic there is also `tools.design_test` (snapshot
ordering, invariants, bands, budgets) — reads of tuning configs go through it
so a change that mutates balance fails loudly.

## Visual gates

Tests alone cannot prove a render change looks right, so:

- `lovec . --shot <scene>` deterministically steps the scene and writes
  `shot_<scene>.png` to the save dir — look at it (scenes: `demo`, `editor`,
  `play`, `gh_menu`, `gh_game`, `gh_results`).
- `lovec . --audit` boots every scene for 60 frames each, screenshots it, and
  writes `audits/run_<timestamp>/report.md` (PASS/FAIL per scene, with the
  PNGs alongside) to the save dir.

Both are deterministic (fixed `dt`), so identical inputs give identical
pixels — usable for before/after comparison.

## Continuous integration

The repo deliberately ships **without** a hosted CI workflow: standard
GitHub-hosted runners have no OpenGL-capable GPU, and LÖVE needs a GL context
even for `--test` (a headless attempt fails at window creation). Run the
suite locally per the sections above, or `--audit` it.

If you self-host a runner with a GPU (or want to try software rendering on a
Linux runner — `xvfb-run` plus Mesa's `LIBGL_ALWAYS_SOFTWARE=1` softpipe),
the shape is: install LÖVE 11.5, run `lovec . --test`, assert exit code 0,
upload the `--shot`/`--audit` PNGs as artifacts.
