# TESTRUNS — test catalog and gates

## Read before running anything

1. **Sandbox**: automated runs use `FRAMEWORK_SANDBOX=1` (windowed, vsync 0).
2. **Budgets**: use `FRAMEWORK_TIMEOUT_OPS=<instructions>` for untrusted checks.
3. **No bypass path**: `run-tests.bat --test` and every `FRAMEWORK_CHECK` entry
   go through the same harness; there is deliberately no way to run a LOVE
   check outside it.

## Surfaces

| Surface | Command | Cost |
|---|---|---|
| Full suite (all modules + smoke + scripted gameplay) | `run-tests.bat` | ~10-20s |
| One module | `FRAMEWORK_CHECK=tests.rng_test run-tests.bat` | ~2s |
| Watchdogged module (hang hunting) | add `FRAMEWORK_TIMEOUT_OPS=<n>` | ~2s |
| Visual shot | `lovec . --shot demo\|editor\|play\|gh_menu\|gh_game` | ~3s |
| Settings-overlay shot | `STUDIO_SETTINGS_SHOT=1 ... --shot demo` | ~3s |
| Full audit (boots scenes, screenshots, report.md) | `lovec . --audit` | ~5s |
| Reference game | `lovec . --sample` | manual |
| Packaging | `tools\package.bat out.love` | ~2s |

Real-filesystem writes (editor Save, sidecars, thumbnails, audit artifacts)
are covered by `tests/fsx_test.lua` — LÖVE silently fails nested writes
without pre-created parents; `core/fsx.lua` is the guard every writer uses.

## Coverage ratchet

Coverage may improve, never regress: a new core/render/save/ui/content module
arrives with a `tests/<module>_test.lua`, or the suite fails.

## Adding a test

Create `tests/<name>_test.lua` using the standard header — discovery is
automatic (no list to maintain, the doc-ratchet rule from Trippy's
`test_sets.json`).
