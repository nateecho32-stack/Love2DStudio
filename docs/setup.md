# Setup

Love2d Studio is a zero-dependency framework: the only thing you need is
[LÖVE](https://love2d.org) itself. No luarocks, no C libraries, no build step.

## Requirements

| Requirement | Notes |
|---|---|
| [LÖVE 11.5](https://love2d.org) | The only dependency. `lovec` (console build) or `love` reachable as above. |
| Git | To clone the repo. Any OS LÖVE supports works; the bundled `.bat` scripts are Windows conveniences. |

## 1. Install LÖVE

- **Windows** — run the installer from [love2d.org](https://love2d.org). It
  installs to `C:\Program Files\LOVE\`, which is the first place `run.bat` and
  `run-tests.bat` look. Alternatively add `lovec.exe` or `love.exe` to your
  `PATH` (`where lovec` must resolve).
- **macOS** — unzip the download into `/Applications`. For CLI access add an
  alias, e.g. in `~/.zshrc`:
  `alias love="/Applications/love.app/Contents/MacOS/love"`.
- **Linux** — install via your package manager or the official tarball so that
  `love` is on your `PATH`.

Tip: prefer `lovec` on Windows for automated runs — it keeps a console window
open so `print` output and test results are visible.

## 2. Clone the repo

```bat
git clone https://github.com/nateecho32-stack/Love2DStudio.git
cd Love2DStudio
```

The folder name after cloning does not matter — the framework resolves its own
require paths (standalone `require "init"`, embedded by folder name
`require "Love2d Studio"`, or any dotted prefix).

## 3. First run

```bat
run.bat          REM opens the demo scene (UI kit, particles, postfx, settings overlay)
run-tests.bat    REM runs the whole test suite, exits 0 on pass
```

On macOS/Linux run `love .` from the repo root instead (append flags the same
way, e.g. `love . --sample`).

A passing suite prints `N passed, 0 failed` as its last line and exits `0`.
The count grows as tests are added — test files are discovered automatically.

## Where runtime files land

LÖVE writes everything through `love.filesystem`, i.e. to the **save
directory** for the `t.identity` in [conf.lua](../conf.lua) (`love2d-studio`
when run standalone), **not** the repo folder:

| OS | Save directory |
|---|---|
| Windows | `%APPDATA%\LOVE\love2d-studio\` |
| macOS | `~/Library/Application Support/LOVE/love2d-studio/` |
| Linux | `~/.local/share/love/love2d-studio/` |

Things that land there:

- `shot_<scene>.png` — screenshots from `--shot <scene>` (see [usage](usage.md))
- `audits/run_<timestamp>/` — per-scene PNGs + `report.md` from `--audit`
- `crash_<timestamp>.txt` — crash logs (message, traceback, recent log tail)
- editor scenes saved with the editor's `Save` button (`scenes/…`)
- settings + save files when you embed the framework in a game

Copy files out of the save directory when they should live in the repo (the
"promote step").

## Troubleshooting

- **`LOVE not found`** when running the `.bat` scripts — install LÖVE to the
  default location or add `lovec`/`love` to `PATH`.
- **A window never appears / instant crash** — run `lovec .` from the repo root
  in a terminal and read the error; persistent crashes are also written to
  `crash_*.txt` in the save directory.
- **Tests hang or flash a fullscreen window** — always run automated checks
  with `FRAMEWORK_SANDBOX=1` (forces windowed 800x450, vsync off). See
  [testing](testing.md).
- **LÖVE says the archive is unreadable** when opening a packaged `.love` —
  the zip used backslash entries; always package with [tools/package.bat](packaging.md).
