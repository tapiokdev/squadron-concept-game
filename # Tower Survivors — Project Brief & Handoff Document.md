# Tower Survivors — Project Brief & Handoff Document

## Elevator pitch
A static-tower survivor game with cursor-aimed active skills and RTS-style drones. You are the tower. You do not move. You survive one run.

---

## Target
**A browser-playable proof-of-concept, published on itch.io.**
- Primary goal: validate whether the core loop — stationary tower, cursor-aimed skill, drone squad on a rally point — is actually fun to play.
- This is a POC / first-game demo, not a commercial launch. It exists to see how the systems work and feel.
- **No fixed external deadline** — development is self-paced.
- If the concept proves fun, building it into a fuller game (and choosing a commercial platform such as Steam) is a decision to make *after* the POC. Explicitly out of scope for now.

---

## Developer context
- Solo developer, beginner level.
- Engine: **Godot** (2D).
- Target platform: **Web (HTML5 / WASM)**, played in-browser on itch.io.
- Goal: a polished, fun proof-of-concept. Scope is intentionally small — one arena, one character, one ~8-minute run.

---

## Core design

### The tower
- The player is a stationary tower. No WASD movement.
- The tower has HP. If it dies, the run ends.
- All player agency comes from skills and drone management, not positioning.

### Auto-attacks
- 2 weapons that fire automatically with no player input, Vampire Survivors style.
- Chosen and upgraded through the level-up screen.
- Upgrades change **behaviour**, not raw stats — e.g. "cannon now fires in a spread of 3" rather than "+10% damage". (One deliberate exception, past exhaustion — see Upgrade screen.)
- **Locked roles for the POC:**
  - **Rail** — single-target, fires at the nearest enemy. The starting weapon.
  - **Pulse** — AoE burst around the tower. Answers swarms and clustered enemies. Offered as an upgrade.
  - Behaviour upgrades: Rail → spread of 3, then piercing; Pulse → larger radius / more frequent.
- The single-target vs AoE split is deliberate — it pairs with the enemy roster (AoE is the answer to swarms and Poppers).

### LMB active skill (cursor-aimed)
- Left-click fires a cursor-targeted, high-impact AoE strike — the **Barrage**.
- Cooldown ~5–6 seconds, so holding LMB does nothing useful and each cast is a decision.
- The player decides *when* and *where* — this is the core moment-to-moment skill expression.
- A visible cooldown indicator is required so the player always knows when the skill is ready. It is a recharge ring around the mothership with a glowing head travelling its leading edge, plus a flash on the moment it becomes ready — a static fill was easy to lose against the rings either side of it.
- **Tuning intent:** one cast clears a *single* cluster of swarmers **or** dents *one* bulwark/elite — never enough to cover every lane at once. (See Enemy design.)

### Drones + rally points (the core differentiator)
- Right-click places a rally point marker anywhere on the map.
- All drones move together as a squad toward the current rally point. Repositioning the marker moves everyone — a strategic commitment, not fine-grained unit control.
- Drones spawn from the tower, walk to the rally point using `move_toward()` (no NavMesh needed for a simple arena), and auto-attack nearby enemies once there.
- If a drone dies it respawns at the tower after a delay and walks back to the current rally point independently.
- Respawn timers are long enough that the squad is usually intact, keeping mid-reposition edge cases rare.
- **The rally point is the primary strategic lever:** it covers *one* lane. Everything else falls to auto-attacks, the barrage, and tower HP.

### Drone stacking
- Picking the same drone type again in the upgrade screen adds another independent unit to the squad.
- Each additional copy has a longer respawn timer than the previous (base 10s, then +60% of base per extra copy: 16s, 22s, …) — power scales but doesn't snowball linearly.
- A **shared unit cap** (6 total drones across all types) prevents runaway scaling and keeps browser performance manageable.
- Stacking the same type is a real trade-off: a full bastion squad vs. a mixed composition.

### Drone types (LOCKED — 2 for the POC)
- **Bastion (melee):** 160 HP, 20 damage, 38px reach. Tanks and holds a lane. *Weak to:* fast interceptors it can't chase, and multi-lane pressure (can only be in one place).
- **Lancer (standoff):** 35 HP, 8.9 DPS, 165px reach. Picks off approaching enemies. *Weak to:* high-HP bulwarks (chips too slowly) and being overrun if enemies reach it.
- **Neither chases.** A drone fights what walks into its own reach; rally placement is the only targeting the player has. This is why the Bastion out-stats the Lancer on paper and can still feel worse — its problem is engagement rate, not damage, and the answer is enemies slow enough to walk into it (see Dreadnought) rather than bigger numbers.
- The punish matrix between these two is what makes composition (and rally placement) matter — see Enemy design.

### Upgrade screen
- Triggered on level-up, offers choose-one-of-three.
- **First offer is drone-only** (or the player gets a free starting drone before the run begins) so the rally-point mechanic is engaged immediately.
- Upgrade categories:
  - New drone types (repeatable — each pick adds one unit up to the cap)
  - New auto-attack weapon (Pulse)
  - Behaviour upgrades to existing auto-attacks
- **No raw stat passives** in the POC (no crit chance, attack speed, etc.). Drone-specific passives (armour, regen, damage types) are a post-POC addition if the game needs more depth.
- **One deliberate exception, and only past exhaustion.** There are 11 meaningful picks (5 drone + 6 tower) and the XP curve spends them all by ~4:49 — eleven seconds before the elite, with three minutes of climbing enemy HP still to come. The run reaches ~level 18, so six level-ups used to be handed back empty and silently discarded while the player's power sat flat. Repeatable +damage picks for Rail, Pulse and Barrage now enter the pool **only when nothing behavioural is left**, so picks 1–11 are unchanged and the rule still governs everything interesting. Past that point the choice was never boring-vs-interesting, it was boring-vs-nothing.
- **Pacing is the real lever, not the clock:** the XP curve must deliver a meaningful build — both drone types, some stacking, and 1–2 auto-attack upgrades — by around the elite (~min 5). If level-ups come too slowly the core loop never assembles.

### Run structure (~8 minutes)
- Single ~8-minute survival run. Down from 15 — this is a POC; the goal is to validate the loop, not ship the full arc.
- **The timer stops reinforcements, not the fight.** At 8:00 spawning stops and the clock stops, but the run continues until the field is cleared — the tower stays killable throughout, so reaching the timer is not the win condition, surviving what is already in the air is. A 60s cap ends it regardless so a build cannot hang on one straggler.
- Wave scaling: enemy count and HP increase over time.
- Rough arc:
  - **0:00** — free starting drone, but the squad starts *below* the mothership while the only lane is above it, so a rally order is the run's first real question.
  - **0:45** — second spawn arc opens. Early enough that position matters before the Rail stops out-pacing the spawn rate (~1:00), so ignoring it costs chip damage rather than the run.
  - **~min 5** — elite / mini-boss (Carrier) breaks the wave rhythm; the Bulwark share steps up with it.
  - **5:45** — third arc opens, on the assumption the Carrier is down by then.
  - **6:00** — heavy phase: Dreadnoughts begin, capped at one alive.
  - **8:00** — spawning stops; hold until the field is clear.
- **Run length is a tunable constant** (`run_duration`). 8 min is the starting point; bump to 10 after playtest if it feels rushed. Don't over-tune it before the first playtest.

### Enemy design (LOCKED)
The squad model risks becoming trivial if spawns are predictable and the barrage comfortably covers any outliers. Enemy variety stresses different squad compositions so the player's current build is always being evaluated against the current threat. Phase 1 locks the following:

- **Simultaneous multi-directional pressure:** single arc → 2 arcs from 0:45 → 3 arcs from 5:45. With one rally point, the squad covers one arc; the rest fall to auto-attacks, barrage, and tower HP. This is the core tension.
- **Lane count is not a volume dial.** A spawn picks one *unlocked* arc, so opening a lane earlier splits the same flow rather than adding to it — what it costs the player is coverage. Reach for the rate constants, never the arc unlocks, when changing how much is on screen.
- **Barrage as a decision:** the ~5–6s cooldown is long enough that when multiple arcs push, the player must choose which threat gets the barrage and which the squad handles. If the barrage covered everything, it would stop being a decision.
- **Strategic lever = rally placement,** not per-unit control.

#### Enemy roster
| Enemy | Behaviour | Punishes | Intended answer |
|---|---|---|---|
| **Swarmer** | Low HP, medium speed, walks at tower, high count | (baseline rhythm) | Squad + auto-attacks |
| **Bulwark** | High HP, slow, straight at tower | Pure-ranged comps — slow single-target chip lets it reach the tower | Commit the **Bastion** squad to its lane |
| **Interceptor** | Fast, low HP, spawns off-angle, bypasses the squad | All-in on one rally point — can't relocate fast enough | Tower auto-attacks + **barrage** snipe |
| **Carrier** *(elite, ~min 5)* | High HP, periodically spawns Swarmers | Ignoring priority targets | Focus-fire + barrage; creates the multi-lane moment |
| **Dreadnought** *(from min 6, max 1 alive)* | 420 HP, very slow, straight at tower | Squads with no front line — it walks in and has to be held | **Bastions** block it while everything else DPSes it down |
| **Popper** *(optional / stretch)* | Medium HP, on death spawns 2–3 mini-Swarmers | Single-target-only builds | Pulse AoE / barrage |

The **Popper** is optional for the POC and remains unbuilt — the Dreadnought took the "late game needs another shape" slot instead, because the gap playtests found was a missing front-line job for the Bastion rather than missing AoE pressure.

#### Live caps as a relief valve
Two enemies carry a concurrency cap: **Dreadnought** at 1, **Bulwark** at 6. The spawn roll is an ordered band table, and a band that is capped (or not yet unlocked) is skipped **without reserving its slice** — so a blocked Dreadnought becomes a Bulwark and a blocked Bulwark becomes a Swarmer, rather than a missing spawn.

That property is what makes the caps worth having: total pressure stays flat, but the *composition* lightens exactly when heavies are surviving long enough to pile up, which is when the player is already losing. It is rubber-banding that is invisible to a competent player. Adding another heavy should be a row in that table, not another branch.

---

## Demo scope (hard limits)
| Category | POC target |
|---|---|
| Playable characters | 1 |
| Arena | 1 |
| Auto-attack weapons | 2 (Rail + Pulse) |
| Drone types | 2 (Bastion + Lancer) |
| LMB skill variants | 1 (barrage) |
| Run length | ~8 minutes (tunable) |
| Shared unit cap | 6 drones |
| Concurrent enemies (perf budget) | ~150–200 max (browser) |

---

## What is deliberately excluded from the POC
- WASD directional weapons (post-POC / second character kit)
- QWER skills (post-POC if mouse-only feels too sparse after playtesting)
- Drone-specific passive stat upgrades (post-POC)
- Multiple arenas or characters
- Anything Steam-specific (store page, achievements, Steam SDK) — the POC ships to the browser only

---

## Key Godot implementation notes
- **Object pooling is critical — and non-negotiable on web.** Survivors-likes spawn and kill hundreds of enemies per run, and WASM is less forgiving than native. Set up pooling (reuse nodes instead of free/create) for enemies and projectiles first, before other systems. Retrofitting it later is painful.
- **Keep enemies lightweight.** Prefer `Area2D` + manual `move_toward()` and distance checks over a `CharacterBody2D` with physics per enemy. At 150–200 concurrent enemies, per-node physics is the first thing that will blow the browser frame budget.
- **Build the enemy system data-driven from day one.** Define enemies by data (HP, speed, size, a behaviour flag), make the pool generic (any type reconfigures on spawn), and give enemies a death hook (a signal or `_on_death`). Make the concurrency cap a **global live-count guard** — check total living enemies before *every* spawn, whether timer-, wave-, or death-triggered, not just a spawn-rate limit. Rationale: the **Carrier (not optional) already needs "an enemy that spawns enemies,"** so build that plumbing once — the optional **Popper** then becomes a drop-in (same mechanism, triggered on death instead of a timer), and the global cap stops a cluster of death-spawns from bursting past the ~150–200 budget.
- **Performance budget (browser):** target ~150–200 concurrent enemies, not the 300–500 a native build could push. Confirm the frame rate holds at max enemies + max drones + projectiles *before* the art pass.
- **Cursor targeting:** `get_global_mouse_position()` is all you need for the barrage.
- **Drone movement:** `move_toward()` toward the rally point is sufficient. All drones share one rally point and move as a squad — design around this; don't add per-unit targeting.
- **Suppress the browser right-click menu.** RMB is the core rally-point input, so the browser context menu must be disabled on the game canvas or right-clicks will be hijacked. Lock this early since the whole drone system depends on it.

---

## Browser / itch.io export notes (for the export phase)
- Export target: Godot **Web (HTML5 / WASM)**.
- **Threads:** Godot web threading needs cross-origin isolation (SharedArrayBuffer). itch.io has a "SharedArrayBuffer support" toggle in the embed settings that sets the required headers. Single-threaded export is the safest default; enable threads only if the perf budget demands it and it's tested on itch.
- **Load size:** the browser downloads the WASM + PCK on every play. Keep assets small so the game starts fast — matters more for itch.io bounce rate than for a native build.
- **Input focus:** the canvas needs focus to receive input; a click-to-start screen handles this cleanly. ✅ **Built** — `scripts/start_screen.gd`, which also covers the audio gesture below. Its effect on focus and audio cannot be verified outside a real web export, so it is the first thing to check on the first build.
- **Audio:** browser audio needs a user gesture to start. Without the click-to-start gate the first run opens silent, which reads as "the game has no sound" rather than as a browser policy.
- **Export mode matters more than it looks.** `project.godot` registers the Godot AI MCP plugin's `_mcp_game_helper` as an unconditional autoload, and Godot's default "Export all resources in the project" packs all 125 addon scripts — ~1.58 MB raw / ~427 KB gzipped of pure dev tooling. Only 5 files are actually reachable (~23 KB gzipped). **Set export mode to "Export selected scenes (and dependencies)".** Do *not* gitignore or delete `addons/` to solve it: the autoload plus the enabled `plugin.cfg` mean a fresh clone would fail to load. Runtime cost of the helper is negligible either way — its `_process` early-returns once `EngineDebugger.is_active()` is false.
- **Export templates are a ~1 GB one-time download** (Editor → Manage Export Templates), and they gate everything: no preset, no build, no outside playtests.

---

## Competitive context
- The WC3 mod "Tower Survivors" is the spiritual reference, but don't lean on it — most players won't have the reference. Where the mod's tension came from competing players in one lobby, this replaces that with solo survival and drone management.
- The space is essentially empty; the only close Steam adaptation has minimal presence.
- The differentiator to communicate on any store/itch page and in a gif/trailer: **you are a stationary tower, and you control the battlefield through drones and targeted skills — not by moving.**

---

## Roadmap
Self-paced (no external deadline). Ordering still holds; dates dropped for the POC.

| Phase | Goal | Status |
|---|---|---|
| 1. Lock the concept | All design decisions finalised, including enemy types and what each punishes | ✅ Locked (this document) |
| 2. Tower and enemy foundation | Tower, pooled + lightweight enemies, auto-attacks, run timer | ✅ Done |
| 3. LMB active skill | Cursor-aimed cooldown barrage, playable core loop | ✅ Done |
| 4. Drone system | Rally points, stacking, unit cap, 2 drone types | ✅ Done |
| 5. Upgrade loop | XP, level-up screen, all upgrade content, wave/multi-lane scaling | ✅ Done |
| 6. Art, audio, and feel | Assets, hit flash, screen shake, SFX, music | ✅ Done except music |
| 7. Playtest and fix | Outside playtests, crash fixes, browser optimisation | 🔶 Own playtests done and acted on; shell built (click-to-start, restart). **Outside playtests are blocked on a web build.** |
| 8. Publish | itch.io page, gif/trailer, web export, publish | Pending — export templates not yet installed, no `export_presets.cfg` |

**The roadmap ordering is misleading here.** Phase 7's *outside playtests* cannot happen until Phase 8's *web export* exists, because there is nothing to hand anyone. One chain gates the rest:

```
export templates (~1 GB, Editor → Manage Export Templates)
  └→ export preset ("Export selected scenes (and dependencies)")
       └→ first web build
            ├→ verifies RMB context-menu suppression  ← never tested, and the
            │                                            whole drone mechanic
            │                                            depends on it
            └→ verifies browser audio + canvas focus
                 └→ outside playtests become possible
```

---

## Phase 1 — locked decisions (summary)
- **Target:** browser-playable POC on itch.io; self-paced; validate fun before committing to a full game.
- **Run length:** ~8 minutes, tunable via `run_duration`; XP curve tuned to deliver a full build by ~min 5.
- **Drone types:** Bastion (melee) + Lancer (standoff). Neither chases; rally placement is the only targeting.
- **Auto-attacks:** Rail (single-target) + Pulse (AoE).
- **LMB skill:** Barrage, ~5–6s cooldown, one problem solved per cast.
- **Enemy roster:** Swarmer, Bulwark, Interceptor, Carrier (elite ~min 5), Dreadnought (from min 6, max 1 alive); Popper optional and unbuilt.
- **Multi-lane:** 1 → 2 (0:45) → 3 (5:45) spawn arcs.
- **Ending:** the timer stops spawning; the field must then be cleared, and the tower stays killable while it is.
- **Perf budget:** ~150–200 concurrent enemies; pooling + lightweight `Area2D` enemies mandatory.
- **Browser input:** suppress the right-click context menu (RMB = rally point).

---

## Art direction (locked in Phase 6)
Neon sci-fi vector, no sprites or audio assets anywhere — everything is drawn
from primitives and every sound is synthesised at load. Chosen because the POC
has no artist, and geometry plus a disciplined palette reads as deliberate where
generated art would not.

- **Fiction:** the tower is a stationary **mothership**; enemies are a hostile fleet.
- **Colour rule:** cool blues are yours, warm and magenta is hostile, green is
  your own orders (the rally point). `Palette` owns every colour in the game.
- **Glow:** real HDR bloom — `hdr_2d` plus a WorldEnvironment with Canvas
  background. `Palette.neon()` for anything whose colour carries meaning (it
  preserves hue), `Palette.hot()` where blowing out to white is the point.
- **Type is shape first, colour second.** In a 130-ship swarm the silhouette is
  what the player actually reads.
- **Web budget discipline:** all sparks batch into one draw call from `FxLayer`;
  facing is a transform write and hit flash is `modulate`, so neither costs a
  redraw. Verified 133 concurrent enemies at 144 fps.
- **Nothing outside the hit boundary may look like a barrier.** The tower's
  condition ring once sat at `radius * 1.85` as rotating gapped arcs, and
  playtest read it as an invulnerability screen — reasonably, since attackers
  visibly crossed it before landing a hit. `take_damage` has no mitigation of
  any kind. Condition is now one continuous ring at `radius + 4`.
- **Sound follows the same rule as colour: identity up top, weight down low.**
  The bank is entirely synthesised in `SfxBank`, and its failure mode is that
  everything drifts into the same low, noisy register and stops being
  distinguishable. Two fixes recur — put a sound's signature where nothing else
  lives (the Rail's 1.9kHz zip, the level-up's 1.4kHz tick) rather than making
  it louder, and remember a 68Hz fundamental is inaudible on the laptop
  speakers this actually ships to.
- **Still open:** music.

---

## How to use this document
Paste this at the top of a new Claude conversation to continue the project with full context.

**Where things stand:** Phases 1–6 are built and the balance has been signed off on a cleared run. The game is playable in the editor and has never been exported. Music is the one unbuilt Phase 6 item.

Good starting prompts, roughly in the order they matter:
- *"Set up the web export preset and get a first build running"* — the gate on everything else
- *"Suppress the browser right-click context menu"* — never tested, and RMB is the core input
- *"Add music"* — the last Phase 6 item, deferred deliberately
- *"Review the enemy spawn band table in scripts/enemy_spawner.gd"*

**Conventions worth knowing before changing anything:**
- Difficulty was tuned **deliberately easy** across several playtests. Do not re-harden constants without a fresh one — for a POC, frustration blocks the "is it fun?" question the build exists to answer.
- There are no art or audio assets and there should be none: every shape comes from `Shapes`/`Palette` and every sound from `SfxBank`.
- Prefer giving the player a rising curve over flattening the enemy curve. The late-game fix that worked was repeatable damage picks, not nerfing enemies.
