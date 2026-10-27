# GBA for Sonix Plus

Game Boy Advance games on the HiBy R1 and R3 Pro II, as an
[app](https://github.com/Simplyph0/sonix-plus/blob/main/APPS.md) for
[Sonix Plus](https://github.com/Simplyph0/sonix-plus): the
[gpSP](https://github.com/libretro/gpsp) libretro core, which has a dynamic recompiler for
MIPS, linked into the [SDK](https://github.com/Simplyph0/sonix-app-sdk)'s frontend as one
static program.

The game fills the top of the screen and an on-screen pad is below it: a D-pad, A and B, L and R,
SELECT and START, and SAVE, LOAD and EXIT keys. SAVE and LOAD keep one save state per game. EXIT
has to be held for a moment. Battery saves are written to `Saves/GBA/<game>.srm` on the card.

## Installing

1. Copy the `GBA` folder to `Apps/` on the card.
2. Put games (`.gba`, `.agb`) in `Games/GBA/` on the card.
3. Open **More > Emulators > GBA**.

The folder holds two programs: `gba`, which uses the recompiler, and `gba-interp`, which does not.
The recompiler is a lot faster. The app starts through `run.sh`, which runs `gba` and, if that crashes,
starts `gba-interp` with the same game. To use the interpreter only, change `exec = run.sh` to
`exec = gba-interp` in `manifest.ini`. What the app prints is in `last-run.log` in its folder.

**I have not been able to run the recompiler on a player yet.** The interpreter has been tried
with a test ROM on a computer; the MIPS build with the recompiler has only been built.

## Building

You need the MIPS toolchain that `make target` builds in the Sonix Plus repository, and `git`.

```bash
make fetch
make package CROSS=/path/to/sonix-plus/sonix-player/rockbox-toolchain/bin/mipsel-rockbox-linux-gnu-
```

`dist/GBA/` is the folder to copy to the card. gpSP at the revision pinned in the Makefile does not
compile for MIPS as it stands (a function is called with two arguments and defined with three), so
the Makefile drops the unused third parameter with a `sed` in the checkout. That is the only change
made to the core. `make host` builds an interpreter-only program for your computer, and
`python3 tools/mkrom.py test.gba` writes a small ROM of my own to try it with.

## Licences

The files in this repository are MIT. gpSP is under the GNU GPL version 2, and so is the program
built from it, which includes the SDK's MIT-licensed frontend.
