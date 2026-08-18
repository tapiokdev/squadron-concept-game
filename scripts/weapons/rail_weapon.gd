class_name RailWeapon
extends Node

## Rail: the starting auto-attack. Fires a projectile at the nearest live
## enemy on a fixed cooldown, no player input. The behaviour upgrade from
## the brief ("spread of 3") is just spread_count = 3 later.

@export var damage := 12.0
@export var cooldown := 0.7
@export var projectile_speed := 500.0
@export var attack_range := 420.0
@export var spread_count := 1
@export var spread_step_deg := 12.0
## Extra enemies each shot can pass through (behaviour upgrade).
@export var pierce := 0

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
	var target := _nearest_visible()
	if target == null:
		return
	_cd = cooldown
	var base_dir := (target.global_position - _tower.position).normalized()
	# Muzzle flash on the hull edge, so the mothership visibly does the
	# shooting instead of shots appearing out of its middle.
	var muzzle := _tower.position + base_dir * _tower.radius
	FxLayer.flash(muzzle, Palette.RAIL, 11.0, 0.1)
	FxLayer.burst(muzzle, Palette.RAIL, 3, 110.0, 0.16, base_dir.angle(), 0.9)
	# Quietest thing in the mix by a wide margin: it repeats all run, so it
	# is meant to sit under everything rather than be listened to. The pitch
	# jitter is what keeps it from reading as a machine gun.
	Sfx.play(&"rail", randf_range(0.94, 1.1), -19.0)
	for i in spread_count:
		var offset := deg_to_rad(spread_step_deg) * (float(i) - (spread_count - 1) * 0.5)
		_projectiles.try_spawn(
			_tower.position, base_dir.rotated(offset),
			projectile_speed, damage, attack_range + 80.0, pierce)

## Nearest enemy in range that is also on screen — shooting chaff the
## player can't see reads as the game playing itself.
func _nearest_visible() -> Enemy:
	var view := Rect2(Vector2.ZERO, _tower.get_viewport_rect().size).grow(8.0)
	var best: Enemy = null
	var best_dist_sq := attack_range * attack_range
	for enemy in _enemies.live:
		if not view.has_point(enemy.global_position):
			continue
		var dist_sq := _tower.position.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = enemy
	return best
