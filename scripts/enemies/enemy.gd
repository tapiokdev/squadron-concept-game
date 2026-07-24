class_name Enemy
extends Area2D

## Lightweight pooled enemy: Area2D + move_toward(), no physics body.
## Built entirely in code (no scene file) so the pool can cheaply
## instantiate and reconfigure instances from any EnemyDef.

signal died(enemy: Enemy)

const ENEMY_COLLISION_LAYER := 2

var def: EnemyDef
var hp: float = 0.0
var target_pos := Vector2.ZERO

var _shape: CircleShape2D
var _active := false

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

func configure(new_def: EnemyDef, spawn_pos: Vector2, new_target_pos: Vector2) -> void:
	def = new_def
	hp = def.max_hp
	global_position = spawn_pos
	target_pos = new_target_pos
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
	position = position.move_toward(target_pos, def.speed * delta)

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
