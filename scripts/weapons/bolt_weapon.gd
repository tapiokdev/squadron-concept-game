class_name BoltWeapon
extends Node

## Bolt: the starting auto-attack. Fires a projectile at the nearest live
## enemy on a fixed cooldown, no player input. The behaviour upgrade from
## the brief ("spread of 3") is just spread_count = 3 later.

@export var damage := 12.0
@export var cooldown := 0.7
@export var projectile_speed := 500.0
@export var attack_range := 420.0
@export var spread_count := 1
@export var spread_step_deg := 12.0

var _enemies: EnemyPool
var _projectiles: ProjectilePool
var _tower: Tower
var _cd := 0.0

func setup(enemies: EnemyPool, projectiles: ProjectilePool, tower: Tower) -> void:
	_enemies = enemies
	_projectiles = projectiles
	_tower = tower

func _process(delta: float) -> void:
	if _tower == null or not _tower.alive:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _cd > 0.0:
		return
	var target := _enemies.nearest_live(_tower.position, attack_range)
	if target == null:
		return
	_cd = cooldown
	var base_dir := (target.global_position - _tower.position).normalized()
	for i in spread_count:
		var offset := deg_to_rad(spread_step_deg) * (float(i) - (spread_count - 1) * 0.5)
		_projectiles.try_spawn(
			_tower.position, base_dir.rotated(offset),
			projectile_speed, damage, attack_range + 80.0)
