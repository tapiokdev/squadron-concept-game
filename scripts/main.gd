extends Node2D

## TEMPORARY Phase 2 scaffold: spawns a ring of enemies that walk to the
## tower to smoke-test the pool and contact damage. Replaced by the real
## wave spawner in the next Phase 2 step.

const SWARMER := preload("res://data/enemies/swarmer.tres")
const BRUTE := preload("res://data/enemies/brute.tres")
const RUSHER := preload("res://data/enemies/rusher.tres")

@onready var enemy_pool: EnemyPool = $EnemyPool
@onready var tower: Tower = $Tower

func _ready() -> void:
	tower.position = get_viewport_rect().size * 0.5
	tower.hp_changed.connect(func(hp: float, max_hp: float) -> void:
		print("[smoke-test] tower hp: %.0f/%.0f" % [hp, max_hp]))
	tower.died.connect(func() -> void:
		print("[smoke-test] tower destroyed — run over"))
	for i in 24:
		var def: EnemyDef = SWARMER
		if i % 8 == 3:
			def = BRUTE
		elif i % 8 == 6:
			def = RUSHER
		var angle := TAU * float(i) / 24.0
		enemy_pool.try_spawn(def, tower.position + Vector2.from_angle(angle) * 400.0, tower)
	print("[smoke-test] live enemies: %d" % enemy_pool.live_count)
