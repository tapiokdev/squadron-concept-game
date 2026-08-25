# Squadron Concept Game

Playable at https://ferroflare.itch.io/squadron-concept-game

A browser-playable bullet-heaven proof of concept, built in Godot 4.7.
Your task is to protect a static mothership from waves of enemies. The mothership stays at the center of the screen where enemies try to reach and destroy it.

Direct a squad of drones and launch barrages with mouse buttons. Level-up to improve the drone squad and to unlock new weapons and upgrades for the mothership.

## Controls

| Input | Action |
|---|---|
| **Right-click** | Place the rally point — the whole drone squad moves there together |
| **Left-click** | Call a barrage at the cursor (~5s cooldown) |

## No art or audio assets

Every shape is drawn from primitives at runtime (`scripts/fx/shapes.gd`,
`scripts/fx/palette.gd`) and every sound effect is synthesised from oscillators and
filtered noise when the game loads (`scripts/fx/sfx_bank.gd`). There are no sprites,
no sample packs and no fonts beyond the engine default.

The background music is by Cyberwave-Orchestra and sourced from [Pixaby](https://pixabay.com/music/beats-slow-sci-fi-synthwave-underscore-music-loop-300694/) as credited in [CREDITS.md](CREDITS.md).

## Running it locally

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
  It is a working document that has been updated as the game has been iterated on.

## Licence

Code is MIT — see [LICENSE](LICENSE). **This does not cover the music**, which is
third-party and licensed separately; [CREDITS.md](CREDITS.md) has the terms. The
vendored Godot AI editor plugin under `addons/` is MIT and carries its own notice
in `godot-ai-LICENSE.txt`.
