# AGENTS.md — agent working rules for Love2d Studio

Do not hardcode check lists in this file; read them from the registry:
- Test surfaces: `tools/tests.lua` (`runAll` discovers `tests/*.lua` automatically)
- Single check: `FRAMEWORK_CHECK=tests.<name> run-tests.bat`
- Visual gate: `--shot <scene>` produces a PNG in the save dir — LOOK at it

## Rules (learned from the 2d Trippy Hell audit)

- Never modify anything outside `Love2d Studio/` (or the game folder being worked on).
- Never let a check run unbounded: use `FRAMEWORK_TIMEOUT_OPS` and `FRAMEWORK_SANDBOX=1`
  (windowed 800x450, vsync 0 — a hung fullscreen check locks the desktop).
- "A green test is not proof of a player-facing feature." Render changes need a
  `--shot` artifact that a human (or vision) has actually looked at.
- Extend PLAN.md; do not create new plan files. Keep evidence per item ≤3 lines.
- Every new test file is discovered automatically — no list to maintain.
- Data over prose: any list that must stay in sync with code belongs in a
  registry table plus a ratchet check, never in a doc alone.
- Reads of tuning configs must go through `design_test` snapshots when a system
  could plausibly mutate balance.
