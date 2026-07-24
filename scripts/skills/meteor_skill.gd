class_name MeteorSkill
extends Node2D

## LMB active skill: cursor-aimed AoE meteor on a long cooldown, the
## core moment-to-moment decision. Tuning intent from the brief: one
## cast clears a single swarmer cluster OR dents one brute/elite.

@export var damage := 60.0
@export var radius := 110.0
@export var cooldown := 5.5
## Short telegraph between click and impact so the hit reads on screen.
@export var impact_delay := 0.35

const EXPLOSION_TIME := 0.3

var _enemies: EnemyPool
var _tower: Tower
var _cd := 0.0
var _pending_pos := Vector2.ZERO
var _impact_in := -1.0
var _explosion_pos := Vector2.ZERO
var _explosion_left := 0.0

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower

func is_ready() -> bool:
	return _cd <= 0.0 and _impact_in < 0.0

func cooldown_fraction() -> float:
	return 1.0 - _cd / cooldown

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_cast(get_global_mouse_position())

func try_cast(pos: Vector2) -> bool:
	if not is_ready():
		return false
	if _tower == null or not _tower.alive:
		return false
	_cd = cooldown
	_pending_pos = pos
	_impact_in = impact_delay
	queue_redraw()
	return true

func _process(delta: float) -> void:
	var dirty := false
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)
	if _impact_in >= 0.0:
		_impact_in -= delta
		if _impact_in < 0.0:
			_impact()
		dirty = true
	if _explosion_left > 0.0:
		_explosion_left = maxf(_explosion_left - delta, 0.0)
		dirty = true
	if dirty:
		queue_redraw()

func _impact() -> void:
	# Iterate a copy: take_damage can kill and mutate the live list.
	for enemy in _enemies.live.duplicate():
		if _pending_pos.distance_to(enemy.global_position) <= radius + enemy.def.radius:
			enemy.take_damage(damage)
	_explosion_pos = _pending_pos
	_explosion_left = EXPLOSION_TIME

func _draw() -> void:
	if _impact_in >= 0.0:
		draw_arc(_pending_pos, radius, 0.0, TAU, 48, Color(1.0, 0.5, 0.2, 0.8), 2.0)
		draw_circle(_pending_pos, radius, Color(1.0, 0.5, 0.2, 0.12))
	if _explosion_left > 0.0:
		var alpha := _explosion_left / EXPLOSION_TIME
		draw_circle(_explosion_pos, radius, Color(1.0, 0.6, 0.15, alpha * 0.6))
		draw_circle(_explosion_pos, radius * 0.55, Color(1.0, 0.9, 0.5, alpha * 0.8))
