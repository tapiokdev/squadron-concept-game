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
## Behaviour upgrade: the impact echoes once (50% damage, 70% radius).
@export var aftershock := false

const EXPLOSION_TIME := 0.3
const AFTERSHOCK_DELAY := 0.5

var _enemies: EnemyPool
var _tower: Tower
var _cd := 0.0
var _pending_pos := Vector2.ZERO
var _impact_in := -1.0
var _impact_radius := 0.0
var _aftershock_next := false
var _explosion_pos := Vector2.ZERO
var _explosion_radius := 0.0
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
	_impact_radius = radius
	_aftershock_next = false
	queue_redraw()
	return true

func _process(delta: float) -> void:
	var dirty := false
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)
		dirty = true
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
	var mult := 0.5 if _aftershock_next else 1.0
	# Iterate a copy: take_damage can kill and mutate the live list.
	for enemy in _enemies.live.duplicate():
		if _pending_pos.distance_to(enemy.global_position) <= _impact_radius + enemy.def.radius:
			enemy.take_damage(damage * mult)
	_explosion_pos = _pending_pos
	_explosion_radius = _impact_radius
	_explosion_left = EXPLOSION_TIME
	if aftershock and not _aftershock_next:
		_aftershock_next = true
		_impact_radius = radius * 0.7
		_impact_in = AFTERSHOCK_DELAY

func _draw() -> void:
	_draw_cooldown_ring()
	if _impact_in >= 0.0:
		draw_arc(_pending_pos, _impact_radius, 0.0, TAU, 48, Color(1.0, 0.5, 0.2, 0.8), 2.0)
		draw_circle(_pending_pos, _impact_radius, Color(1.0, 0.5, 0.2, 0.12))
	if _explosion_left > 0.0:
		var alpha := _explosion_left / EXPLOSION_TIME
		draw_circle(_explosion_pos, _explosion_radius, Color(1.0, 0.6, 0.15, alpha * 0.6))
		draw_circle(_explosion_pos, _explosion_radius * 0.55, Color(1.0, 0.9, 0.5, alpha * 0.8))

## The brief requires an always-visible cooldown indicator: a recharge
## ring around the tower that fills clockwise and lights up when ready.
func _draw_cooldown_ring() -> void:
	if _tower == null:
		return
	var ring_radius := _tower.radius + 8.0
	if is_ready():
		draw_arc(_tower.position, ring_radius, 0.0, TAU, 40, Color(1.0, 0.6, 0.2, 0.9), 3.0)
		return
	draw_arc(_tower.position, ring_radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.15), 3.0)
	var fraction := cooldown_fraction()
	if fraction > 0.0:
		draw_arc(_tower.position, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 40,
			Color(1.0, 0.6, 0.2, 0.5), 3.0)
