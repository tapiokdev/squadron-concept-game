# Tower Survivors — Project Brief & Handoff Document

## Elevator pitch
A static-tower survivor game with cursor-aimed active skills and RTS-style summons. You are the tower. You do not move. You survive one run.

---

## Target
**A browser-playable proof-of-concept, published on itch.io.**
- Primary goal: validate whether the core loop — stationary tower, cursor-aimed skill, summon squad on a rally point — is actually fun to play.
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
- All player agency comes from skills and summon management, not positioning.

### Auto-attacks
- 2 weapons that fire automatically with no player input, Vampire Survivors style.
- Chosen and upgraded through the level-up screen.
- Upgrades change **behaviour**, not raw stats — e.g. "cannon now fires in a spread of 3" rather than "+10% damage".
- **Locked roles for the POC:**
  - **Bolt** — single-target, fires at the nearest enemy. The starting weapon.
  - **Pulse** — AoE burst around the tower. Answers swarms and clustered enemies. Offered as an upgrade.
  - Behaviour upgrades: Bolt → spread of 3; Pulse → larger radius / more frequent.
- The single-target vs AoE split is deliberate — it pairs with the enemy roster (AoE is the answer to swarms and Poppers).

### LMB active skill (cursor-aimed)
- Left-click fires a cursor-targeted, high-impact AoE skill (the "meteor").
- Cooldown ~5–6 seconds, so holding LMB does nothing useful and each cast is a decision.
- The player decides *when* and *where* — this is the core moment-to-moment skill expression.
- A visible cooldown indicator is required so the player always knows when the skill is ready.
- **Tuning intent:** one cast clears a *single* cluster of swarmers **or** dents *one* brute/elite — never enough to cover every lane at once. (See Enemy design.)

### Summons + rally points (the core differentiator)
- Right-click places a rally point marker anywhere on the map.
- All summons move together as a squad toward the current rally point. Repositioning the marker moves everyone — a strategic commitment, not fine-grained unit control.
- Summons spawn from the tower, walk to the rally point using `move_toward()` (no NavMesh needed for a simple arena), and auto-attack nearby enemies once there.
- If a summon dies it respawns at the tower after a delay and walks back to the current rally point independently.
- Respawn timers are long enough that the squad is usually intact, keeping mid-reposition edge cases rare.
- **The rally point is the primary strategic lever:** it covers *one* lane. Everything else falls to auto-attacks, the meteor, and tower HP.

### Summon stacking
- Picking the same summon type again in the upgrade screen adds another independent unit to the squad.
- Each additional copy has a longer respawn timer than the previous (e.g. first: 10s, second: 16s, third: 24s) — power scales but doesn't snowball linearly.
- A **shared unit cap** (6 total summons across all types) prevents runaway scaling and keeps browser performance manageable.
- Stacking the same type is a real trade-off: a full bruiser squad vs. a mixed composition.

### Summon types (LOCKED — 2 for the POC)
- **Bruiser (melee):** high HP, short range, strong single-target melee, slow-ish. Tanks and holds a lane. *Weak to:* fast rushers it can't chase, and multi-lane pressure (can only be in one place).
- **Archer (ranged):** low–moderate HP, long range, picks off approaching enemies, lower per-hit. *Weak to:* high-HP brutes (chips too slowly) and being overrun if enemies reach it.
- The punish matrix between these two is what makes composition (and rally placement) matter — see Enemy design.

### Upgrade screen
- Triggered on level-up, offers choose-one-of-three.
- **First offer is summon-only** (or the player gets a free starting summon before the run begins) so the rally-point mechanic is engaged immediately.
- Upgrade categories:
  - New summon types (repeatable — each pick adds one unit up to the cap)
  - New auto-attack weapon (Pulse)
  - Behaviour upgrades to existing auto-attacks
- **No raw stat passives** in the POC (no crit chance, attack speed, etc.). Summon-specific passives (armour, regen, damage types) are a post-POC addition if the game needs more depth.
- **Pacing is the real lever, not the clock:** the XP curve must deliver a meaningful build — both summon types, some stacking, and 1–2 auto-attack upgrades — by around the elite (~min 5). If level-ups come too slowly the core loop never assembles.

### Run structure (~8 minutes)
- Single ~8-minute survival run. Down from 15 — this is a POC; the goal is to validate the loop, not ship the full arc.
- Win state triggers when the timer expires.
- Wave scaling: enemy count and HP increase over time.
- Rough arc:
  - **0–2 min:** ramp. Free starting summon, fast early level-ups, single spawn arc.
  - **~min 3–4:** second spawn arc opens — first real multi-lane pressure.
  - **~min 5:** elite / mini-boss (Broodmother) breaks the wave rhythm.
  - **~min 6:** power-fantasy peak — near-full roster, upgraded auto-attacks, strong meteor.
  - **~6.5–8 min:** climax — third arc opens, crescendo to the win.
- **Run length is a tunable constant** (`run_duration`). 8 min is the starting point; bump to 10 after playtest if it feels rushed. Don't over-tune it before the first playtest.

### Enemy design (LOCKED)
The squad model risks becoming trivial if spawns are predictable and the meteor comfortably covers any outliers. Enemy variety stresses different squad compositions so the player's current build is always being evaluated against the current threat. Phase 1 locks the following:

- **Simultaneous multi-directional pressure:** single arc early → 2 arcs from ~min 3–4 → 3 arcs from ~min 6.5. With one rally point, the squad covers one arc; the rest fall to auto-attacks, meteor, and tower HP. This is the core tension.
- **Meteor as a decision:** the ~5–6s cooldown is long enough that when multiple arcs push, the player must choose which threat gets the meteor and which the squad handles. If the meteor covered everything, it would stop being a decision.
- **Strategic lever = rally placement,** not per-unit control.

#### Enemy roster
| Enemy | Behaviour | Punishes | Intended answer |
|---|---|---|---|
| **Swarmer** | Low HP, medium speed, walks at tower, high count | (baseline rhythm) | Squad + auto-attacks |
| **Brute** | High HP, slow, straight at tower | Pure-ranged comps — slow single-target chip lets it reach the tower | Commit the **Bruiser** squad to its lane |
| **Rusher** | Fast, low HP, spawns off-angle, bypasses the squad | All-in on one rally point — can't relocate fast enough | Tower auto-attacks + **meteor** snipe |
| **Broodmother** *(elite, ~min 5)* | High HP, periodically spawns Swarmers | Ignoring priority targets | Focus-fire + meteor; creates the multi-lane moment |
| **Popper** *(optional / stretch)* | Medium HP, on death spawns 2–3 mini-Swarmers | Single-target-only builds | Pulse AoE / meteor |

The **Popper** is optional for the POC — add it only if the first playtest shows AoE (Pulse, meteor) isn't being stress-tested enough by Swarmers and the Broodmother alone.

---

## Demo scope (hard limits)
| Category | POC target |
|---|---|
| Playable characters | 1 |
| Arena | 1 |
| Auto-attack weapons | 2 (Bolt + Pulse) |
| Summon types | 2 (Bruiser + Archer) |
| LMB skill variants | 1 (meteor) |
| Run length | ~8 minutes (tunable) |
| Shared unit cap | 6 summons |
| Concurrent enemies (perf budget) | ~150–200 max (browser) |

---

## What is deliberately excluded from the POC
- WASD directional weapons (post-POC / second character kit)
- QWER skills (post-POC if mouse-only feels too sparse after playtesting)
- Summon-specific passive stat upgrades (post-POC)
- Multiple arenas or characters
- Anything Steam-specific (store page, achievements, Steam SDK) — the POC ships to the browser only

---

## Key Godot implementation notes
- **Object pooling is critical — and non-negotiable on web.** Survivors-likes spawn and kill hundreds of enemies per run, and WASM is less forgiving than native. Set up pooling (reuse nodes instead of free/create) for enemies and projectiles first, before other systems. Retrofitting it later is painful.
- **Keep enemies lightweight.** Prefer `Area2D` + manual `move_toward()` and distance checks over a `CharacterBody2D` with physics per enemy. At 150–200 concurrent enemies, per-node physics is the first thing that will blow the browser frame budget.
- **Build the enemy system data-driven from day one.** Define enemies by data (HP, speed, size, a behaviour flag), make the pool generic (any type reconfigures on spawn), and give enemies a death hook (a signal or `_on_death`). Make the concurrency cap a **global live-count guard** — check total living enemies before *every* spawn, whether timer-, wave-, or death-triggered, not just a spawn-rate limit. Rationale: the **Broodmother (not optional) already needs "an enemy that spawns enemies,"** so build that plumbing once — the optional **Popper** then becomes a drop-in (same mechanism, triggered on death instead of a timer), and the global cap stops a cluster of death-spawns from bursting past the ~150–200 budget.
- **Performance budget (browser):** target ~150–200 concurrent enemies, not the 300–500 a native build could push. Confirm the frame rate holds at max enemies + max summons + projectiles *before* the art pass.
- **Cursor targeting:** `get_global_mouse_position()` is all you need for the meteor.
- **Summon movement:** `move_toward()` toward the rally point is sufficient. All summons share one rally point and move as a squad — design around this; don't add per-unit targeting.
- **Suppress the browser right-click menu.** RMB is the core rally-point input, so the browser context menu must be disabled on the game canvas or right-clicks will be hijacked. Lock this early since the whole summon system depends on it.

---

## Browser / itch.io export notes (for the export phase)
- Export target: Godot **Web (HTML5 / WASM)**.
- **Threads:** Godot web threading needs cross-origin isolation (SharedArrayBuffer). itch.io has a "SharedArrayBuffer support" toggle in the embed settings that sets the required headers. Single-threaded export is the safest default; enable threads only if the perf budget demands it and it's tested on itch.
- **Load size:** the browser downloads the WASM + PCK on every play. Keep assets small so the game starts fast — matters more for itch.io bounce rate than for a native build.
- **Input focus:** the canvas needs focus to receive input; a click-to-start screen handles this cleanly.
- **Audio:** browser audio can have higher latency and needs a user gesture to start — keep the audio setup simple.

---

## Competitive context
- The WC3 mod "Tower Survivors" is the spiritual reference, but don't lean on it — most players won't have the reference. Where the mod's tension came from competing players in one lobby, this replaces that with solo survival and summon management.
- The space is essentially empty; the only close Steam adaptation has minimal presence.
- The differentiator to communicate on any store/itch page and in a gif/trailer: **you are a stationary tower, and you control the battlefield through summons and targeted skills — not by moving.**

---

## Roadmap
Self-paced (no external deadline). Ordering still holds; dates dropped for the POC.

| Phase | Goal | Status |
|---|---|---|
| 1. Lock the concept | All design decisions finalised, including enemy types and what each punishes | ✅ Locked (this document) |
| 2. Tower and enemy foundation | Tower, pooled + lightweight enemies, auto-attacks, run timer | ✅ Done |
| 3. LMB active skill | Cursor-aimed cooldown meteor, playable core loop | Next |
| 4. Summon system | Rally points, stacking, unit cap, 2 summon types | Pending |
| 5. Upgrade loop | XP, level-up screen, all upgrade content, wave/multi-lane scaling | Pending |
| 6. Art, audio, and feel | Assets, hit flash, screen shake, SFX, music | Pending |
| 7. Playtest and fix | Outside playtests, crash fixes, browser optimisation | Pending |
| 8. Publish | itch.io page, gif/trailer, web export, publish | Pending |

---

## Phase 1 — locked decisions (summary)
- **Target:** browser-playable POC on itch.io; self-paced; validate fun before committing to a full game.
- **Run length:** ~8 minutes, tunable via `run_duration`; XP curve tuned to deliver a full build by ~min 5.
- **Summon types:** Bruiser (melee) + Archer (ranged).
- **Auto-attacks:** Bolt (single-target) + Pulse (AoE).
- **LMB skill:** meteor, ~5–6s cooldown, one problem solved per cast.
- **Enemy roster:** Swarmer, Brute, Rusher, Broodmother (elite ~min 5); Popper optional.
- **Multi-lane:** 1 → 2 (min 3–4) → 3 (min 6.5) spawn arcs.
- **Perf budget:** ~150–200 concurrent enemies; pooling + lightweight `Area2D` enemies mandatory.
- **Browser input:** suppress the right-click context menu (RMB = rally point).

---

## How to use this document
Paste this at the top of a new Claude conversation to continue the project with full context. Good starting prompts:
- *"Help me set up object pooling for lightweight enemies in Godot for web export"*
- *"Help me implement the RMB rally point system in Godot (and suppress the browser context menu)"*
- *"Review my summon movement code"*
- *"Help me design the upgrade screen UI in Godot"*
