class_name Enemy
extends Area2D

## Lightweight pooled enemy: Area2D + move_toward(), no physics body.
## Built entirely in code (no scene file) so the pool can cheaply
## instantiate and reconfigure instances from any EnemyDef.

signal died(enemy: Enemy)

const ENEMY_COLLISION_LAYER := 2

var def: EnemyDef
var hp: float = 0.0
var target: Tower

var _shape: CircleShape2D
var _active := false
var _attack_cooldown: float = 0.0

func _init() -> void:
	collision_layer = ENEMY_COLLISION_LAYER
	collision_mask = 0
	monitoring = false
	_shape = CircleShape2D.new()
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	deactivate()

func _ready() -> void:
	# Entering the tree re-enables _process on nodes that override it,
	# clobbering the set_process(false) from _init — re-assert it here.
	set_process(_active)

func configure(new_def: EnemyDef, spawn_pos: Vector2, new_target: Tower, hp_scale: float = 1.0) -> void:
	def = new_def
	hp = def.max_hp * hp_scale
	global_position = spawn_pos
	target = new_target
	_attack_cooldown = 0.0
	_shape.radius = def.radius
	_active = true
	visible = true
	set_process(true)
	set_deferred("monitorable", true)
	queue_redraw()

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
	set_deferred("monitorable", false)

func _process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var reach := def.radius + target.radius
	if global_position.distance_to(target.global_position) > reach:
		global_position = global_position.move_toward(target.global_position, def.speed * delta)
	elif _attack_cooldown == 0.0 and target.alive:
		target.take_damage(def.contact_damage)
		_attack_cooldown = def.attack_interval

func take_damage(amount: float) -> void:
	if not _active:
		return
	hp -= amount
	if hp <= 0.0:
		die()

func die() -> void:
	if not _active:
		return
	deactivate()
	died.emit(self)

func _draw() -> void:
	# Placeholder visual until the art pass: a flat circle from the def.
	if def:
		draw_circle(Vector2.ZERO, def.radius, def.color)
