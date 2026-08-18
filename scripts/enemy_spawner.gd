class_name EnemySpawner
extends Node

## Timed wave spawner. Spawn arcs unlock over the run (1 lane early,
## 2 from ~min 3.5, 3 from ~min 6.5) — with one rally point the squad
## covers one arc and the rest fall to auto-attacks, barrage, and tower
## HP; that is the core tension. Every spawn goes through
## EnemyPool.try_spawn(), which enforces the global live-count cap; a
## null return simply drops that spawn.

const SWARMER := preload("res://data/enemies/swarmer.tres")
const BULWARK := preload("res://data/enemies/bulwark.tres")
const INTERCEPTOR := preload("res://data/enemies/interceptor.tres")
const CARRIER := preload("res://data/enemies/carrier.tres")
const DREADNOUGHT := preload("res://data/enemies/dreadnought.tres")

@export var active := false
@export var arc_centers_deg: Array[float] = [-90.0, 135.0, 0.0]
@export var arc_unlock_sec: Array[float] = [0.0, 210.0, 390.0]
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
## The elite moment from the brief (~min 5). It doubles as the line where
## the roster escalates, so there is one number for "after the boss" rather
## than two that can drift apart: everything before it is the curve the
## playtests signed off on, everything after it is the heavy phase.
@export var elite_at_sec := 300.0
## Post-elite roster. Dreadnoughts exist only after the Carrier, and the
## Bulwark share steps up at the same moment — the last three minutes used
## to be the same three enemies with slowly growing HP bars.
@export var dreadnought_share := 0.06
@export var bulwark_share_late := 0.10

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
## that has not unlocked yet is skipped *without* reserving its slice, so its
## share falls through to the bands below instead of quietly becoming
## Swarmers the way the old nested `elif` chain did. Anything past the last
## band is a Swarmer, which is why Swarmer has no row of its own.
##
## A table rather than more branches because "a few tougher versions" is the
## expected direction of travel here — the next heavy should be a row.
func _bands() -> Array[Dictionary]:
	var late := elapsed >= elite_at_sec
	return [
		{"def": DREADNOUGHT, "after": elite_at_sec, "share": dreadnought_share,
				"any_angle": false},
		{"def": BULWARK, "after": bulwark_after_sec,
				"share": bulwark_share_late if late else bulwark_share,
				"any_angle": false},
		# Interceptors come in off-angle to punish tunnel vision on the main arc.
		{"def": INTERCEPTOR, "after": interceptor_after_sec,
				"share": interceptor_share, "any_angle": true},
	]

func _spawn_one() -> void:
	var def: EnemyDef = SWARMER
	var any_angle := false
	var roll := randf()
	var covered := 0.0
	for band in _bands():
		if elapsed < float(band.after):
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
