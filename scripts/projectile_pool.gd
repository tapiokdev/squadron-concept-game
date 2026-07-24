class_name ProjectilePool
extends Node2D

## Pool for Projectile nodes, mirroring EnemyPool. max_live is a safety
## valve for the browser frame budget, not a design knob.

@export var max_live: int = 200
@export var prewarm: int = 32

var live_count: int = 0

var _inactive: Array[Projectile] = []

func _ready() -> void:
	for i in prewarm:
		_inactive.append(_create())

func try_spawn(spawn_pos: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, pierce: int = 0) -> Projectile:
	if live_count >= max_live:
		return null
	var projectile: Projectile = _inactive.pop_back() if not _inactive.is_empty() else _create()
	projectile.configure(spawn_pos, direction, speed, damage, max_range, pierce)
	live_count += 1
	return projectile

func _create() -> Projectile:
	var projectile := Projectile.new()
	projectile.despawned.connect(_on_projectile_despawned)
	add_child(projectile)
	return projectile

func _on_projectile_despawned(projectile: Projectile) -> void:
	live_count -= 1
	_inactive.append(projectile)
