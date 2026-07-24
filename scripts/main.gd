extends Node2D

## TEMPORARY Phase 2 scaffold: spawns a ring of enemies that walk to the
## screen centre to smoke-test the pool. Replaced by the real tower +
## wave spawner in the next Phase 2 step.

const SWARMER := preload("res://data/enemies/swarmer.tres")
const BRUTE := preload("res://data/enemies/brute.tres")
const RUSHER := preload("res://data/enemies/rusher.tres")

@onready var enemy_pool: EnemyPool = $EnemyPool

func _ready() -> void:
	var center := get_viewport_rect().size * 0.5
	for i in 24:
		var def: EnemyDef = SWARMER
		if i % 8 == 3:
			def = BRUTE
		elif i % 8 == 6:
			def = RUSHER
		var angle := TAU * float(i) / 24.0
		enemy_pool.try_spawn(def, center + Vector2.from_angle(angle) * 400.0, center)
	print("[smoke-test] live enemies: %d" % enemy_pool.live_count)
