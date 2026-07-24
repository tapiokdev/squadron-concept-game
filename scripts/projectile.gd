class_name Projectile
extends Area2D

## Pooled straight-line projectile. Area2D with monitoring on, watching the
## enemy collision layer; despawns on first hit or at max range.

signal despawned(projectile: Projectile)

var damage: float = 0.0
var velocity := Vector2.ZERO

var _life_left: float = 0.0
var _hits_left: int = 1
var _active := false

func _init() -> void:
	collision_layer = 0
	collision_mask = Enemy.ENEMY_COLLISION_LAYER
	monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	area_entered.connect(_on_area_entered)
	deactivate()

func _ready() -> void:
	# Entering the tree re-enables _process; re-assert the pooled state.
	set_process(_active)

func configure(spawn_pos: Vector2, direction: Vector2, speed: float, new_damage: float, new_max_range: float, pierce: int = 0) -> void:
	global_position = spawn_pos
	velocity = direction.normalized() * speed
	damage = new_damage
	_life_left = new_max_range / speed
	_hits_left = 1 + pierce
	_active = true
	visible = true
	set_process(true)
	set_deferred("monitoring", true)

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
	set_deferred("monitoring", false)

func _process(delta: float) -> void:
	position += velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_despawn()

func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area is Enemy:
		area.take_damage(damage)
		_hits_left -= 1
		if _hits_left <= 0:
			_despawn()

func _despawn() -> void:
	if not _active:
		return
	deactivate()
	despawned.emit(self)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.85, 0.95, 1.0))
