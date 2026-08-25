# Squadron Concept Game

A browser-playable bullet-heaven proof of concept, built in Godot 4.7.

**You are the mothership. You do not move.** There is no WASD. All of your agency
comes from two clicks — where you send your drone squad, and when you call down a
barrage — while your automatic weapons handle everything they can reach on their
own. Survive eight minutes, then clear what is left on the field.

The point of the POC is to find out whether that loop is actually fun: a stationary
defender who controls the battlefield through positioning *other* units rather than
through their own.

## Controls

| Input | Action |
|---|---|
| **Right-click** | Place the rally point — the whole drone squad moves there together |
| **Left-click** | Call a barrage at the cursor (~5s cooldown) |

The rally point covers **one** lane. Everything else falls to your auto-attacks, the
barrage, and hull integrity — choosing which threat to cover is the game.

## No art or audio assets

Every shape is drawn from primitives at runtime (`scripts/fx/shapes.gd`,
`scripts/fx/palette.gd`) and every sound effect is synthesised from oscillators and
filtered noise when the game loads (`scripts/fx/sfx_bank.gd`). There are no sprites,
no sample packs and no fonts beyond the engine default.

That was a constraint chosen because the project has no artist, and it turned into
the art direction: neon vector geometry with real HDR bloom, where a disciplined
palette reads as deliberate in a way generated art would not.

The one exception is the background music, which is a third-party track — see
[CREDITS.md](CREDITS.md).

## Running it

Open the project folder in **Godot 4.7** and press play. No build step, no
dependencies to fetch.

## Exporting to the web

An export preset is committed, so *Project → Export → Web* works out of the box.
Two settings in it are load-bearing and are easy to "optimise" into a broken build:

- **Export all resources in the project** — the alternative silently drops scripts
  that are only reachable by their global `class_name`
- **Single-threaded** — avoids needing cross-origin isolation on the host

Both, and the rest of the export gotchas, are written up in the project brief.

## Documentation

- **[CREDITS.md](CREDITS.md)** — the music track and its licence
- **Project brief** (`# Tower Survivors — …md`) — the full design document: locked
  decisions, the enemy roster and what each type punishes, balance reasoning, art
  and sound direction, and a long list of export traps that each cost real time.
  It is a working document rather than an introduction, and it is where to look
  before changing anything non-obvious.

## Licence

Code is MIT — see [LICENSE](LICENSE). **This does not cover the music**, which is
third-party and licensed separately; [CREDITS.md](CREDITS.md) has the terms. The
vendored Godot AI editor plugin under `addons/` is MIT and carries its own notice
in `godot-ai-LICENSE.txt`.

> The name is not settled. The repo and brief say *Tower Survivors* after the WC3
> mod that inspired it, the project file says *Squadron Concept Game*, and the game
> itself opens on *SURVIVE THE INVASION*.
