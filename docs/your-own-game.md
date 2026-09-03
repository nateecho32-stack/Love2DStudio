# Using Love2d Studio in your own game

The framework is designed to be **copied, not installed**: your game folder
contains the studio folder and requires it by folder name. The
[`template/`](../template) folder is the starting point — the whole
integration is ~60 lines.

## 1. Folder layout

```
my-game/
├── Love2d Studio/        ← the whole framework, copied as-is
│   ├── init.lua          ← public API: require("Love2d Studio")
│   └── …
├── main.lua              ← your entry (from template/)
├── conf.lua              ← your LÖVE config (from template/)
├── config.lua            ← every tuning number (from template/)
├── scenes/
│   ├── menu.lua
│   └── game.lua
└── assets/               ← your art/sfx (optional — everything has fallbacks)
```

1. Create `my-game/` and copy the entire `Love2d Studio/` folder into it.
2. Copy everything from `template/` (`main.lua`, `conf.lua`, `config.lua`,
   `scenes/`) to `my-game/`'s root, **next to** `Love2d Studio/`.
3. `lovec .` (or `love .`) from `my-game/` boots your game.

The require name is just the folder name: `require("Love2d Studio")`. If you
rename the folder to `mygame`, the require becomes `require("mygame")`.

## 2. conf.lua — set your identity

The template's `conf.lua` lives at **game root** (a conf inside a subfolder is
inert to LÖVE). The critical line is `t.identity` — it names the save
directory all settings/saves/screenshots write to:

```lua
t.identity = "my-game"   -- CHANGE THIS or saves collide with other projects
t.window.width, t.window.height = 1280, 720
t.window.resizable = true

-- automated runs must never take exclusive fullscreen or vsync
if os.getenv("FRAMEWORK_SANDBOX") then
  t.window.width, t.window.height, t.window.vsync = 800, 450, 0
end
```

## 3. config.lua — every number in one place

The one project convention worth keeping: no magic numbers in module code.
Each entry carries its rationale:

```lua
return {
  saveDir = "saves/slot1",
  saveVersion = 1,
  player = {
    speed = 240,     -- px/s: crosses the screen in ~5s at 1280 wide
    jumpPower = 520, -- tuned so a full jump clears 3 tiles of 32px
  },
}
```

## 4. main.lua — the whole wiring

From `template/main.lua`, annotated:

```lua
local S = require("Love2d Studio")
local config = require("config")
local menu = require("scenes.menu")
local game = require("scenes.game")

function love.load(args)
  S.log.setLevel("info")
  local flags = S.boot.parse(args)

  -- `lovec . --test` runs every tests/*.lua and quits with exit code 0/1
  if flags.test then
    love.event.quit(S.tools.tests.runAll("tests") and 0 or 1)
    return
  end

  S.scene.register("menu", menu)
  S.scene.register("game", game)

  -- saves: sidecar-per-system with versioned migrations
  S.game.save = S.save.new{ dir = config.saveDir, version = config.saveVersion }

  -- audio: sound families under the game's assets/sfx
  S.game.audio = S.audio.new{ dirs = { "assets/sfx" } }

  -- the scene editor (see "The scene editor" below)
  local editor = S.editor.new{ S = S, scenePath = config.scenePath }
  S.scene.register("editor", editor)

  if flags.editor then
    S.scene.push("editor")
  else
    S.scene.push("menu")
  end
  S.assets.ready()
end

-- forward the rest of the callbacks; boot owns the frame pipeline
function love.update(dt) S.boot.frame(dt) end
function love.draw() S.scene.draw() end
function love.keypressed(k, s, r) S.boot.keypressed(k, s, r) end
function love.mousepressed(x, y, b) S.boot.mousepressed(x, y, b) end
function love.mousereleased(x, y, b) S.boot.mousereleased(x, y, b) end
function love.mousemoved(x, y, dx, dy) S.boot.mousemoved(x, y, dx, dy) end
function love.wheelmoved(x, y) S.boot.wheelmoved(x, y) end
function love.resize(w, h) S.boot.resize(w, h) end
function love.focus(f) S.boot.focus(f) end
```

Notes:

- `S.game` is an empty table the framework gives you — stash your instances
  there (`S.game.save`, `S.game.audio`) so scenes can reach them.
- `S.boot.parse(args)` gives you `flags.test/--editor/--play/--shot/…` for free.
- Alternatively use `S.boot.run{ scenes = {...}, first = "menu", args = args }`,
  which registers scenes, pushes the first one, arms crash logging and the
  blur/focus handling in one call (see the root `main.lua` for that shape).
- Boot opts you can pass to `S.boot.run`: `throttleUnfocused` (default on),
  `pauseOnBlur` + `blurDelay` (default off / 0.35 s), `hotReload` (Ctrl+R
  restart; default on).

### The scene editor

The template wires the editor with an **empty archetype palette**; to author
your own entities, pass your schemas (any `{id = def}` table, like the
standalone runtime's `archetypes.lua` or `sample/archetypes.lua`):

```lua
local editor = S.editor.new{ S = S, scenePath = config.scenePath, archetypes = myArchetypes }
S.scene.register("editor", editor)
```

`lovec . --editor` opens it; F5 inside plays the current scene file (which
also registers the play scene: `S.scene.register("play", S.require("play"))`).
See [editor.md](editor.md).

## 5. Scenes

A scene is a plain table of callbacks. All are optional:

| Callback | Called |
|---|---|
| `enter(args)` | on `push`/`replace` (receives the args table) |
| `update(dt)` | every frame with **game** dt (respects time scale/pause) |
| `draw()` | every frame; the whole stack draws bottom-up |
| `keypressed(key, scancode, isrepeat)` | top scene only |
| `mousepressed/mousereleased/mousemoved/wheelmoved` | top scene only |
| `textinput(text)` | top scene only (routed through boot) |
| `resize(w, h)` | **every** scene in the stack (rebuild canvases here) |
| `pause()` / `resume()` | when covered / uncovered by a pushed scene |
| `exit()` | on pop/replace |

Minimal menu scene (`template/scenes/menu.lua`):

```lua
local S = require("Love2d Studio")

local scene = {}

function scene.enter() end
function scene.update(dt) end

function scene.draw()
  love.graphics.clear(0.08, 0.09, 0.11)
  love.graphics.print("MY GAME", 24, 24)
  love.graphics.print("press Enter to play, Esc to quit", 24, 48)
end

function scene.keypressed(key)
  if key == "return" or key == "space" then S.scene.replace("game") end
  if key == "escape" then love.event.quit() end
end

return scene
```

Stack API: `S.scene.register(name, mod)`, `push(name, args)`, `pop()`,
`replace(name, args)`, `clear()`, plus `top()`, `topName()`, `depth()`.
For fade/cross transitions see `S.transitions`.

## 6. Input actions

Map actions once, then query values/edges — keyboard and gamepad behind one
API, with a per-frame edge detector driven by `S.boot.frame`:

```lua
S.input.define({
  left  = { keys = { "left", "a" }, buttons = { "dpleft" } },
  right = { keys = { "right", "d" }, buttons = { "dpright" } },
  jump  = { keys = { "space", "z" }, buttons = { "a" } },
})

-- then per frame:
if S.input.down("right") then ... end       -- held (analog value > 0.5)
if S.input.pressed("jump") then ... end     -- went down this frame
if S.input.released("jump") then ... end    -- went up this frame
S.input.value("left")                       -- 0..1 (axis with deadzone)
```

Axes: `axis = "leftx"` with `dir = -1` to flip. The backend is injectable
(`S.input.setBackend`) — tests use fakes instead of a real window.

## 7. Assets — the nil contract

`S.assets` is a lazy cache: **a missing asset returns `nil`** instead of
crashing, so callers fall back to procedural drawing (deleting a bad file
reverts to the fallback). Anything queued before boot runs after
`S.assets.ready()`:

```lua
local img = S.assets.image("assets/player.png")  -- nil if absent
local fnt = S.assets.font(nil, 14)               -- nil path = default font
local sfx = S.assets.sound("assets/sfx/pickup", "static")
```

## 8. Saves

`S.save` stores one sidecar file per system (`<dir>/<system>.dat`), so a
partial write failure names the exact file that failed. Data goes through a
safe serializer and versioned migrations:

```lua
local save = S.save.new{ dir = "saves/slot1", version = 2, migrations = {...} }

save:write("progress", { gems = 12, level = 3 })
local data = save:read("progress")   -- data | nil, err; save.notes discloses heals
save:exists("progress"); save:delete("progress"); save:systems()
```

Increment `version` and add a migration when the schema grows — old files
migrate on read, future versions are refused (no silent corruption).

## 9. Settings

Defaults are the schema; validation rules clip bad values; the store persists
as flat dotted keys and refuses files from newer versions:

```lua
local settings = S.settings.new{
  file = "my_settings.dat",
  version = 1,
  defaults = { video = { postfx = "on", shake = 1.0 }, audio = { music = 0.8 } },
  rules = { ["audio.music"] = { min = 0, max = 1 } },
}
settings:load()
settings:set("audio.music", 0.5)   -- validated; returns nil, reason if rejected
local v = settings:get("audio.music")
settings:save()
```

## 10. Audio

`S.audio.new{ dirs = { "assets/sfx" } }` resolves sound **families with
variants** from disk; with no files present it falls back to the procedural
synth (the studio itself ships zero asset files). Buses + makeup gain are
built in; `audio/synth.lua` synthesizes tones/SFX procedurally.

## 11. i18n

```lua
local i18n = S.i18n.new{ default = "en" }
i18n:registerLocale("en", { strings = { ["menu.play"] = "Play" } })
i18n:registerLocale("de", { strings = { ["menu.play"] = "Spielen" } })
i18n:setLocale("de")
i18n:t("menu.play")                    -- "Spielen"
i18n:t("menu.gems", 3)                 -- string.format-style args
i18n:t("missing.key")                  -- falls back en → the key itself
```

## Where to go next

- **Scene editor** for level authoring — [editor.md](editor.md)
- **Tests** so your game stays green — [testing.md](testing.md)
- **Packaging** a distributable `.love` — [packaging.md](packaging.md)
- The full module map lives in the [README](../README.md#module-map); the
  reference game under `sample/` (Gem Haul) is the best end-to-end example of
  every system above wired together.
