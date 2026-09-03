# FINDINGS — audit of 13 projects (2026-09)

Source material for Love2d Studio. All paths below were read-only; nothing outside
`Love2d Studio/` was modified. "Trippy" = `2d Trippy Hell` (1,625 Lua files, the most
mature project); `trippy_fluid_baseline` is an earlier snapshot of the same game.

## Layer 1 — infrastructure (duplicated everywhere)

- Scene/state stack hand-rolled 3×: Void Place `engine/scene.lua` (cleanest: registry +
  stack, modal draw bottom-up), Burning `src/state/state_manager.lua` (subset), Trippy
  `game/state/state_machine.lua` (974 lines).
- Virtual resolution + letterbox + screen-to-world mouse built 3×: Burning
  `src/render/renderer.lua` (integer scaling), Vimur `src/ui/viewport.lua` (cleanest
  logical 1280×720), Void Place `render/camera.lua`.
- Canvas pipeline (scene canvas × multiply light canvas → postfx → HUD) built 2× nearly
  identically: Burning `renderer.lua`, Void Place `render/init.lua`. Trippy
  `game/systems/effects/postfx.lua` adds beginCapture/endCapture; `render/tile_cache.lua`
  is a budgeted resumable chunk-canvas LRU (6 ms/frame, explicit `canvas:release()`).
- Input action mapping 2× (Burning a strict subset of Void Place `engine/input.lua`).
- RNG wrappers, loggers, timers, pools, math/table utils: reimplemented in every project
  with diverging APIs.
- Weighted-pick helper re-implemented in 6 projects (Burning, Vimur, Endless Grind,
  Dead Meridian, PVZ, Void Place).
- **Zero third-party Lua libraries in any project** — no middleclass/hump/anim8/flux.
  The framework stays dependency-free by the same choice.
- **No project has a real UI widget kit** — the #1 gap. Hand-drawn bars/buttons/hit-tests
  produced god-files: Burning `src/state/game.lua` (621 lines), Vimur `src/ui/shop_ui.lua`
  (508), Trippy `game/state/mp_bridge.lua` (6,430).
- Saves without version fields in Void Place/Vimur/Burning; three different formats and
  three different migration strategies. Trippy `save/` (orchestrator + safe serializer +
  `migration.lua` with auditable schema history + settings store) is the proven answer.
- Repeated lazy-init workarounds (fonts ×3 in Vimur) because love.graphics is not ready
  at require time — a boot lifecycle (`assets.onReady`) solves it once.
- conf.lua hygiene: Vimur ships **no `t.identity`** (saves land in an undefined dir —
  breaks in fused exports). Void Place/Burning confs are near-identical 1280×720
  resizable + vsync.

## Layer 2 — platform polish (mostly Trippy)

- Settings: `game/systems/core/settings.lua` — defaults-as-schema + `RULES` table of
  dotted paths (`min/max/integer/values/maxLen/nonempty`), NaN/±inf rejected,
  `merge(loaded)` returns (accepted, healed). `save/settings_store.lua`: versioned
  `settings.dat`, **future-version guard** (`unsupported_future_version`), one-time
  heals (v2 restores master=0 after the pre-audio era, then re-saves so deliberate mute
  is respected), bind migrations that fire only when the stored key still equals the old
  default (custom rebinds survive).
- Window: `game/systems/core/window_mode.lua` — 3 display modes with last-fullscreen
  memory; **`notifyGraphicsReset()`** because `love.window.setMode` recreates the device
  and invalidates every canvas. `main.lua`: ~20 Hz unfocus throttle (DWM recompose fix);
  pause-on-blur with **0.35 s debounce** so Win+Shift+S/Game Bar focus blips don't pause
  the game; Alt+` hot-reload hatch; custom errorhandler chaining `crash_log.lua`; stock
  `love.run` with only the quit branch changed ("love.arg's parser is version-fragile").
- Sandbox discipline: env-var-gated windowed 800×450 vsync-0 mode — "a hung smoke check
  in exclusive fullscreen is how the PC locks up."
- Accessibility: per-effect intensity scalars (`gameplay.screenShake` 0–2 with
  "photosensitivity escape" early-return in `camera.lua:92`; `video.trippyIntensity`
  driving fx intensity to 0 = all flashing off) + a standing hint teaching composition.
  Gaps found: no colorblind palettes, no reduce-motion master preset, no text scaling.
- Save UX: sidecar-per-system `.dat` (partial failure names the exact file), single-shot
  thread thumbnail worker ("can never hang shutdown"), autosave preset ladder
  (0/30/60/120/300/600/900/1800 — a raw ±30s nudger was unusable, see
  `HANDOFF_autosave_interval.md`), lost-content disclosure ("N items from an older
  version no longer exist"), 4-way mismatch taxonomy (protocol/build/content/worldgen).
- Boot-order polish: `gpu_warmup.lua` (re-warms keyed on screen size after resize),
  `soft_load.lua` (staged menu warmup incl. seeded pregeneration), `content_buffer.lua`
  (layered per-frame work governor, auto sheds background→vital).
- Versioning/presence: `version.lua` stamped into the window title;
  `build_channel.lua` resolution chain (args → env → Steam beta name → build-stamped
  file); `net/presence.lua` (signature-deduped Discord + Steam rich presence);
  `net/steam.lua` optional luasteam wrapper via package.cpath extension, graceful
  `nil, "api_missing"` fallbacks everywhere.

## Layer 3 — gameplay/content patterns

- **Single config module with rationale comments** in 3 engines: Void Place
  `game/config.lua` ("Nothing else should hold a magic constant"), Endless Grind
  `game/config.js`, Dead Meridian `DZ = Object.freeze({...})`.
- **Depth-pressure spawn director**: Burning `src/systems/spawning.lua` (linger timer
  compresses cadence with floor, cap grows with depth, safe-pocket suppression, 85/15
  type weights) and Dead Meridian `updateInfectedPopulation` (desired population bands
  per POI kind, 34 m no-pop-in radius, zone-weighted types). Same module, different knobs.
- **Derived unlocks**: Void Place `game/progress.lua` stores only `best` — unlocks are
  computed, thresholds diff per run for announcements. Vimur `checkMilestone` linear
  ladder whose level mutates shop rarity weights. Endless Grind achievements as
  `test(state)` lambdas swept after events. Convergence: *store raw stats, derive unlocks.*
- **Economy curves**: Endless Grind geometric XP `60·1.18^(lvl-1)` and upgrade costs
  `base·growth^owned`; Vimur per-rarity market base ± variance, buy 0.9×, seed resale 0.5×,
  sell = complexity score × genome multiplier.
- **Loot**: Dead Meridian weighted tables per zone class + "most spots are empty;
  scarcity is the point" (68% skip) + durability 0.35–0.95 rolls; Burning loot caches
  tier `1+floor(depth/4)`.
- **Variation engines**: Vimur `src/genome/` (weighted mutation pool with curated
  "super" wildcards, dominance-weighted breeding, scored rarity rubric, procedural
  naming); `Python Project/import pygame.py` (dict DNA + bounded nudges + energy-split
  reproduction + upkeep as the selection pressure).
- **Seeded chunk streams**: Burning `seed*1000003+index` per-chunk generators; Dead
  Meridian `makeRng(poi.seed ^ 0xabcdef)`. Same hash-mix trick everywhere.
- **FX conventions converged**: Void Place `render/effects` — shake = decaying camera
  punches at 30 Hz accumulated via `max()`, named presets (hit/heavyHit/death/levelUp)
  composing flash+ring+burst+damageNum, `timeScale(factor,duration)` hitstop; PVZ near-miss
  construction (12% of losses rebuilt as tease + descending saw arpeggio + shake),
  reward-scaled confetti/coin counts with caps, streak multiplier; Burning scalar shake.
  All read palette roles (`hot/cold/dim`) rather than literal colors in Void Place.
- **Design-invariant tests** (Void Place `tools/tests.lua` — the reference): posture
  trade-direction orderings ("if that trade ever inverts, there is a dominant posture and
  the mechanic is dead"), cosmetic-only palette test (every tuning number bit-identical
  under all 8 palettes), threshold monotonicity, unlock derivation semantics, intro
  completion budget 8–16 s, 120-frame NaN smoke, 20 s drift-in-bounds sim. "Each of these
  has already caught a real regression."
- **Offline sim**: Endless Grind `advanceSim` re-runs the real loop with an `OFFLINE`
  flag silencing presentation, action-capped, scaled <100% efficiency.

## Layer 4 — assets, art/audio pipeline, process

- **The killer contract** (Trippy `render/sprites/`): hand-authored pure-data intent
  manifest (headless-requirable, semantic keys, atlas `group` by co-visibility) →
  `tools/pack_atlas.ps1` generates packed pages (alpha-bounds trim + per-frame offsets —
  trim jitter is universal to AI art) → runtime `atlas.lua` LRU (8 resident 2048² pages)
  with **nil-return lookup** and the four-line procedural fallback seam: every renderer
  does `local s = sprites.get(key); if s then return sprites.draw(...) end -- procedural
  body, untouched`. Games ship before art exists; reverting bad AI art = delete one PNG.
  Void Place (0 binaries) and Burning (0 binaries; 27 orphaned mp3s in `Audio/` that no
  code references — the anti-pattern a manifest drift checker catches) prove full
  procedural shipping: silhouette-drawer registries, one shared radial-gradient particle
  texture, per-sample SoundData synth registry `{gen=fn, vol=}`.
- **Audio conventions** (Trippy `game/systems/core/audio.lua`): families
  `assets/sfx/<family>/<name>`, variant randomization `_2.._4`, `<folder>/_default`
  fallback, per-clip `CLIP_GAIN` makeup table (needed because AI-generated loudness
  varied −20.7 to −4.2 dBFS — the loudness gate is a documented open issue, fix.md #1).
  Dead Meridian WebAudio: shared brown-noise buffer → filtered ambient buses
  (wind 360 Hz bandpass / room 145 Hz lowpass / rain 1450 Hz highpass) + `tone()` synth.
- **AI-content workflow**: staged audition dirs (`11LabsAudio/passNN/` with README
  tables, "Nothing here is in assets/sfx yet"), install scripts that refuse to overwrite
  shipped clips, generation ledger with prompt+seed (`assets/sprites/MANIFEST.md`,
  1,963 lines), fetch-with-dimension-verification (URLs expire ~8 h; size-is-advisory).
- **Process discipline that kept ~20 concurrent agent sessions from destroying each
  other**: AGENTS.md pointing at data never hardcoded lists ("any list copied here
  drifts within a week") + doc-ratchet test enforcing TESTRUNS.md ↔ test_sets.json sync;
  four-stage test gate with **no bypass path** (census → budgets → machine lease →
  supervised execution; a contract test asserts every entry point self-gates); perf as
  two gates sharing one `perf_gate.py` (baseline semantics NEW/informational/target/
  budget; calibration marks contended runs INCONCLUSIVE, never REGRESSED); coverage
  ratchet (may improve, never regress); PLAN.md working rules (≤3-line evidence, fixed
  section roles, file-ownership collision map, "never git stash"); HANDOFF docs with
  State/file:line changes/verification-with-expected-numbers; fix.md as open-issues-only
  log (fixed entries are deleted); generic 70-line env-var check runner
  (`.codex_smoke/lua_quality_runner/main.lua`) that executes any check under a
  `debug.sethook` watchdog.
- **Prior framework attempt**: `LOVE 2D (Rendering Engine)` is a 696-line particle
  library with an excellent README + demo, not an engine; its "condensation" worktree
  produced a methodology but zero extracted code — lesson: extract by hand from proven
  seams. The library's format (one folder, `require`, presets, demo, dual load paths)
  is the adoption model for this framework.
- **20 Games** (C# port): the tiny-game-collection architecture — one shell, data-driven
  `MinigameMeta[20]` registry (menu generated from it), thin `Minigame` base class,
  shared SoundManager/StorageManager/PlayerManager/GameConsole, and an audit harness
  (`run_full_audit.ps1` boots every game, dwells, screenshots, writes PASS/WARN/FAIL
  matrix) — the model for `--audit` mode and a future game-collection hub.
- **Endless Grind**: `game/data.js` header states the convention — "Registries are the
  extension points; append to these tables, no logic changes." Save `migrate()` fills
  fields added later; explicit type migration example (slot string → item object).
