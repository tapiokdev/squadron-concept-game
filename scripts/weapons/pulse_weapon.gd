class_name PulseWeapon
extends Node2D

## Pulse: AoE burst around the tower, the answer to swarms. Not part of
## the starting kit — the Phase 5 upgrade screen offers it, so it ships
## disabled. Behaviour upgrades later just raise radius / lower cooldown.

@export var enabled := false
@export var damage := 7.0
@export var cooldown := 2.2
@export var radius := 150.0

const FLASH_TIME := 0.25

var _enemies: EnemyPool
var _tower: Tower
var _cd := 0.0
var _flash := 0.0

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()
	if not enabled or _tower == null or not _tower.alive:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _cd > 0.0:
		return
	var hit_any := false
	# Iterate a copy: take_damage can kill and mutate the live list.
	for enemy in _enemies.live.duplicate():
		if _tower.position.distance_to(enemy.global_position) <= radius + enemy.def.radius:
			enemy.take_damage(damage)
			hit_any = true
	if hit_any:
		_cd = cooldown
		_flash = FLASH_TIME
		queue_redraw()

func _draw() -> void:
	if _flash <= 0.0:
		return
	var alpha := _flash / FLASH_TIME
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, alpha), 3.0)
	draw_circle(Vector2.ZERO, radius, Color(0.5, 0.8, 1.0, alpha * 0.15))
