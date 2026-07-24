class_name EnemyPool
extends Node2D

## Generic enemy pool. Preallocates Enemy nodes and reconfigures them from
## an EnemyDef on spawn — any type, same pool.
##
## max_live is the global live-count guard from the project brief: every
## spawn path (wave timer, Broodmother, death-spawns) must go through
## try_spawn(), which refuses once the cap is reached. Callers must handle
## a null return by skipping the spawn.

@export var max_live: int = 150
@export var prewarm: int = 48

var live_count: int = 0

var _inactive: Array[Enemy] = []

func _ready() -> void:
	for i in prewarm:
		_inactive.append(_create())

func try_spawn(def: EnemyDef, spawn_pos: Vector2, target: Tower) -> Enemy:
	if live_count >= max_live:
		return null
	var enemy: Enemy = _inactive.pop_back() if not _inactive.is_empty() else _create()
	enemy.configure(def, spawn_pos, target)
	live_count += 1
	return enemy

func _create() -> Enemy:
	var enemy := Enemy.new()
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	return enemy

func _on_enemy_died(enemy: Enemy) -> void:
	live_count -= 1
	_inactive.append(enemy)
