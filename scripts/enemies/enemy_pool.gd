class_name EnemyPool
extends Node2D

## Generic enemy pool. Preallocates Enemy nodes and reconfigures them from
## an EnemyDef on spawn — any type, same pool.
##
## max_live is the global live-count guard from the project brief: every
## spawn path (wave timer, Carrier, death-spawns) must go through
## try_spawn(), which refuses once the cap is reached. Callers must handle
## a null return by skipping the spawn.

@export var max_live: int = 150
@export var prewarm: int = 48

## Emitted on every enemy death with its XP reward; main tallies levels.
signal enemy_killed(xp: int)

## Set by main; lets enemies see drones that block their path.
var squad: DroneSquad

var live_count: int = 0
var live: Array[Enemy] = []

var _inactive: Array[Enemy] = []

func _ready() -> void:
	for i in prewarm:
		_inactive.append(_create())

func try_spawn(def: EnemyDef, spawn_pos: Vector2, target: Tower, hp_scale: float = 1.0) -> Enemy:
	if live_count >= max_live:
		return null
	var enemy: Enemy = _inactive.pop_back() if not _inactive.is_empty() else _create()
	enemy.configure(self, def, spawn_pos, target, hp_scale)
	live_count += 1
	live.append(enemy)
	return enemy

func nearest_live(pos: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_dist_sq := max_dist * max_dist
	for enemy in live:
		var dist_sq := pos.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy
	return best

func _create() -> Enemy:
	var enemy := Enemy.new()
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	return enemy

func _on_enemy_died(enemy: Enemy) -> void:
	live_count -= 1
	live.erase(enemy)
	_inactive.append(enemy)
	enemy_killed.emit(enemy.def.xp_value)
