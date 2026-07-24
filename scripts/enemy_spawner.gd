class_name EnemySpawner
extends Node

## Timed wave spawner. Spawn arcs unlock over the run (1 lane early,
## 2 from ~min 3.5, 3 from ~min 6.5) — with one rally point the squad
## covers one arc and the rest fall to auto-attacks, meteor, and tower
## HP; that is the core tension. Every spawn goes through
## EnemyPool.try_spawn(), which enforces the global live-count cap; a
## null return simply drops that spawn.

const SWARMER := preload("res://data/enemies/swarmer.tres")
const BRUTE := preload("res://data/enemies/brute.tres")
const RUSHER := preload("res://data/enemies/rusher.tres")
const BROODMOTHER := preload("res://data/enemies/broodmother.tres")

@export var active := false
@export var arc_centers_deg: Array[float] = [-90.0, 135.0, 0.0]
@export var arc_unlock_sec: Array[float] = [0.0, 210.0, 390.0]
@export var arc_span_deg := 70.0
@export var spawn_margin := 60.0
## Spawn-rate curve: spawns/sec at t=0 plus extra per elapsed minute.
@export var base_rate := 1.0
@export var rate_per_min := 0.45
## Enemy HP scaling: +fraction of base HP per elapsed minute.
@export var hp_scale_per_min := 0.15
@export var brute_after_sec := 60.0
@export var rusher_after_sec := 90.0
## Fraction of spawns that roll into each special type once unlocked.
@export var brute_share := 0.05
@export var rusher_share := 0.08
## The elite moment from the brief (~min 5).
@export var elite_at_sec := 300.0

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
	_accum += delta * (base_rate + rate_per_min * elapsed / 60.0)
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one()
	if not _elite_spawned and elapsed >= elite_at_sec:
		_elite_spawned = true
		var angle := deg_to_rad(arc_centers_deg[0])
		var dist := _tower.get_viewport_rect().size.length() * 0.5 + spawn_margin
		_pool.try_spawn(BROODMOTHER, _tower.position + Vector2.from_angle(angle) * dist, _tower)

func _unlocked_arcs() -> int:
	var count := 0
	for unlock in arc_unlock_sec:
		if elapsed >= unlock:
			count += 1
	return count

func _spawn_one() -> void:
	var def: EnemyDef = SWARMER
	var arc: float = arc_centers_deg[randi() % _unlocked_arcs()]
	var angle := deg_to_rad(arc + randf_range(-0.5, 0.5) * arc_span_deg)
	var roll := randf()
	if elapsed >= brute_after_sec and roll < brute_share:
		def = BRUTE
	elif elapsed >= rusher_after_sec and roll >= brute_share and roll < brute_share + rusher_share:
		def = RUSHER
		# Rushers come in off-angle to punish tunnel vision on the main arc.
		angle = randf() * TAU
	var dist := _tower.get_viewport_rect().size.length() * 0.5 + spawn_margin
	var hp_scale := 1.0 + hp_scale_per_min * elapsed / 60.0
	_pool.try_spawn(def, _tower.position + Vector2.from_angle(angle) * dist, _tower, hp_scale)
