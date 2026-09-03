# Template — start a new game in five minutes

1. Create your game folder and copy the whole `Love2d Studio/` folder into it.
2. Copy everything in THIS folder (`main.lua`, `conf.lua`, `config.lua`,
   `scenes/`) into the game folder root, next to `Love2d Studio/`.
3. `run.bat` launches; `run-tests.bat` runs the studio suite + your game's.

The template's `main.lua` is the whole integration: boot, scenes, console,
profiler, and save wiring in ~60 lines. Tunables live in `config.lua`
("every number in config" — the one convention every audited project kept).

A minimal game is two files: a scene module and a registry line — see
`scenes/menu.lua`.
