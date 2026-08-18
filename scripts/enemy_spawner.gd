class_name EnemySpawner
extends Node

## Timed wave spawner. Spawn arcs unlock over the run (1 lane, 2 from
## 0:45, 3 from 5:45) — with one rally point the squad covers one arc and
## the rest fall to auto-attacks, barrage, and tower HP; that is the core
## tension. Every spawn goes through EnemyPool.try_spawn(), which enforces
## the global live-count cap; a null return simply drops that spawn.
##
## Lane count is not a difficulty dial in the volume sense: a spawn picks
## one unlocked arc, so opening a lane earlier splits the same flow rather
## than adding to it. What it costs the player is coverage — playtests had
## the opening asking for no commands at all, because the squad starts
## parked on the only lane there is.

const SWARMER := preload("res://data/enemies/swarmer.tres")
const BULWARK := preload("res://data/enemies/bulwark.tres")
const INTERCEPTOR := preload("res://data/enemies/interceptor.tres")
const CARRIER := preload("res://data/enemies/carrier.tres")
const DREADNOUGHT := preload("res://data/enemies/dreadnought.tres")

@export var active := false
@export var arc_centers_deg: Array[float] = [-90.0, 135.0, 0.0]
## Lane 2 lands just after the first level-up, while the Rail can still
## roughly cover both arcs on its own — so the first command the player is
## asked for costs chip damage if ignored, not the run. Lane 3 opens after
## the Carrier, on the assumption the boss is down by then.
@export var arc_unlock_sec: Array[float] = [0.0, 45.0, 345.0]
@export var arc_span_deg := 70.0
@export var spawn_margin := 60.0
## Spawn-rate curve: spawns/sec at t=0 plus extra per elapsed minute,
## capped at max_rate — player power plateaus once upgrades run out
## (~min 5), so the pressure curve has to plateau too.
@export var base_rate := 1.0
@export var rate_per_min := 0.45
@export var max_rate := 3.0
## Enemy HP scaling: +fraction of base HP per elapsed minute.
@export var hp_scale_per_min := 0.10
@export var bulwark_after_sec := 60.0
@export var interceptor_after_sec := 90.0
## Fraction of spawns that roll into each special type once unlocked.
@export var bulwark_share := 0.05
@export var interceptor_share := 0.08
## Bulwarks are where the late game's total HP actually lives. Because a
## capped band falls through to Swarmer rather than being dropped, this is a
## relief valve rather than a nerf: it binds only once Bulwarks are already
## surviving long enough to pile up, which is exactly when the player is
## losing. At the post-elite share it sits near 1.5-4.5 alive in a run going
## well, so 6 is invisible until it isn't.
@export var bulwark_max_live := 6
## The elite moment from the brief (~min 5). It also steps the Bulwark
## share up, so the boss arrives with some added texture — but nothing
## more. Firing the Carrier and opening the whole heavy roster on the same
## instant is what buried the playtest: a 900 HP boss trailing its own
## brood, with a Dreadnought landing every 5.6s on top of it.
@export var elite_at_sec := 300.0
@export var bulwark_share_late := 0.10
## The heavy phase, deliberately its own moment a minute after the boss
## rather than keyed to elite_at_sec. Capped at one alive: a Dreadnought is
## meant to be a wall the squad has to answer, and two at once is not twice
## the problem, it is a different game.
@export var dreadnought_after_sec := 360.0
@export var dreadnought_share := 0.06
@export var dreadnought_max_live := 1

var elapsed := 0.0

var _elite_spawned := false

var _pool: EnemyPool
var _tower: Tower
var _accum := 0.0

func setup(pool: EnemyPool, tower: Tower) -> void:
	_pool = pool
	_tower = tower
	active = true

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	_accum += delta * minf(base_rate + rate_per_min * elapsed / 60.0, max_rate)
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one()
	if not _elite_spawned and elapsed >= elite_at_sec:
		_elite_spawned = true
		var dir := Vector2.from_angle(deg_to_rad(arc_centers_deg[0]))
		_pool.try_spawn(CARRIER, _tower.position + dir * _spawn_distance(dir), _tower)

func _unlocked_arcs() -> int:
	var count := 0
	for unlock in arc_unlock_sec:
		if elapsed >= unlock:
			count += 1
	return count

## Spawn bands in priority order, each claiming a slice of one roll. A band
## that has not unlocked yet — or that is already at its live cap — is
## skipped *without* reserving its slice, so its share falls through to the
## bands below instead of quietly becoming Swarmers the way the old nested
## `elif` chain did. Anything past the last band is a Swarmer, which is why
## Swarmer has no row of its own.
##
## That fall-through is what keeps a cap from thinning the run: a blocked
## Dreadnought becomes a Bulwark, not a missing spawn, so total pressure is
## flat whether or not one is already on the field.
##
## A table rather than more branches because "a few tougher versions" is the
## expected direction of travel here — the next heavy should be a row.
## `max_live` of 0 means uncapped.
func _bands() -> Array[Dictionary]:
	var late := elapsed >= elite_at_sec
	return [
		{"def": DREADNOUGHT, "after": dreadnought_after_sec,
				"share": dreadnought_share, "any_angle": false,
				"max_live": dreadnought_max_live},
		{"def": BULWARK, "after": bulwark_after_sec,
				"share": bulwark_share_late if late else bulwark_share,
				"any_angle": false, "max_live": bulwark_max_live},
		# Interceptors come in off-angle to punish tunnel vision on the main arc.
		{"def": INTERCEPTOR, "after": interceptor_after_sec,
				"share": interceptor_share, "any_angle": true, "max_live": 0},
	]

func _spawn_one() -> void:
	var def: EnemyDef = SWARMER
	var any_angle := false
	var roll := randf()
	var covered := 0.0
	for band in _bands():
		if elapsed < float(band.after):
			continue
		var cap: int = band.max_live
		if cap > 0 and _pool.count_live_of(band.def) >= cap:
			continue
		if roll < covered + float(band.share):
			def = band.def
			any_angle = band.any_angle
			break
		covered += float(band.share)
	var arc: float = arc_centers_deg[randi() % _unlocked_arcs()]
	var angle := randf() * TAU if any_angle \
			else deg_to_rad(arc + randf_range(-0.5, 0.5) * arc_span_deg)
	var dir := Vector2.from_angle(angle)
	var hp_scale := 1.0 + hp_scale_per_min * elapsed / 60.0
	_pool.try_spawn(def, _tower.position + dir * _spawn_distance(dir), _tower, hp_scale)

## Distance from the tower to the screen edge along `dir`, plus margin —
## so every lane's enemies appear at their screen edge instead of some
## spawning far off-screen (the window isn't square).
func _spawn_distance(dir: Vector2) -> float:
	var vp := _tower.get_viewport_rect().size
	var pos := _tower.position
	var tx := INF
	var ty := INF
	if dir.x > 0.0:
		tx = (vp.x - pos.x) / dir.x
	elif dir.x < 0.0:
		tx = -pos.x / dir.x
	if dir.y > 0.0:
		ty = (vp.y - pos.y) / dir.y
	elif dir.y < 0.0:
		ty = -pos.y / dir.y
	return minf(tx, ty) + spawn_margin
