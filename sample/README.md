# sample/ — Gem Haul, the reference game

The living example that consumes the whole engine: **physics** (player body,
sensor gems/spikes, a seeking chaser, queued-contact resolution), **entities +
archetypes** (schema-driven, editor-authorable level file), **trigger volumes**
(the exit gate), **scene transitions** (menu → game → results fades), **fx
presets** (coin/hit juice), **synth audio** (collect blips, hurt thumps, win
sweep), **saves** (sidecar stats + best score), **milestones** (lifetime-gem
unlock toasts), **UI kit** (buttons with keyboard/gamepad focus nav).

Run: `lovec . --sample` (or console `sample`). Edit the level in the editor
with the same archetypes and Save to `scenes/gemhaul.lua` — the game prefers
that file and falls back to `DEFAULT_LAYOUT` in init.lua.

## Files

- `init.lua` — glue: saves, stats, milestone ladder, scene registration.
  **Copy this folder to start a real game.**
- `archetypes.lua` — content contract shared with the editor.
- `menu.lua` / `game.lua` / `results.lua` — the three scenes.
- `tests/sample_test.lua` — scripted WIN (hold right: collect 3 gems, reach
  exit) and LOSE (stand still: chaser drains hearts) — the integration gate.

## Design rules demonstrated

- Tunables as data (GEM_VALUE tiers, gemsRequired in the archetype schema).
- The chaser spawns BEHIND the runner; hazard knockback applies on every
  contact begin (a persistent overlap only fires begin once).
- Invuln suspends steering so knockback can separate bodies.
- Stats are raw counters; unlocks are derived (milestones.lua).
