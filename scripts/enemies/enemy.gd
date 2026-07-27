class_name Enemy
extends Area2D

## Lightweight pooled enemy: Area2D + move_toward(), no physics body.
## Built entirely in code (no scene file) so the pool can cheaply
## instantiate and reconfigure instances from any EnemyDef.

signal died(enemy: Enemy)

const ENEMY_COLLISION_LAYER := 2

## Hit flash is a `modulate` multiply rather than a redraw, so 150 of
## these can be taking fire at once for free.
const HIT_FLASH := Color(2.8, 2.8, 2.8)
const FLASH_FADE := 11.0
## Carriers ignore their heading and turn slowly on the spot instead.
const CARRIER_SPIN := 0.45

## Hull points are the same for every instance of a type, and pooled
## enemies reconfigure constantly, so the geometry is built once per
## EnemyDef and shared.
static var _hull_cache: Dictionary = {}

var def: EnemyDef
var hp: float = 0.0
var target: Tower

var _shape: CircleShape2D
var _active := false
var _attack_cooldown: float = 0.0
var _pool: EnemyPool
var _hp_scale: float = 1.0
var _spawn_cooldown: float = 0.0
var _hull := PackedVector2Array()
var _hull_loop := PackedVector2Array()
var _core_at := Vector2.ZERO
var _core_radius := 0.0
var _spin := 0.0

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

func configure(pool: EnemyPool, new_def: EnemyDef, spawn_pos: Vector2, new_target: Tower, hp_scale: float = 1.0) -> void:
	_pool = pool
	def = new_def
	hp = def.max_hp * hp_scale
	_hp_scale = hp_scale
	global_position = spawn_pos
	target = new_target
	_attack_cooldown = 0.0
	_spawn_cooldown = def.spawn_interval
	_shape.radius = def.radius
	_active = true
	visible = true
	modulate = Color.WHITE
	_spin = randf() * TAU
	rotation = spawn_pos.direction_to(target.global_position).angle()
	_load_hull()
	set_process(true)
	set_deferred("monitorable", true)
	# Edge spawns arrive off-screen, so only pay for the warp-in where it
	# will be seen — which is exactly the broodmother's brood.
	if get_viewport_rect().has_point(spawn_pos):
		FxLayer.ring(spawn_pos, def.color, def.radius * 2.6, def.radius * 0.6, 0.28, 2.0)
	queue_redraw()

func _load_hull() -> void:
	var cached: Dictionary = _hull_cache.get(def, {})
	if cached.is_empty():
		cached = _build_hull(def)
		_hull_cache[def] = cached
	_hull = cached.hull
	_hull_loop = cached.loop
	_core_at = cached.core_at
	_core_radius = cached.core_radius

static func _build_hull(from_def: EnemyDef) -> Dictionary:
	var r := from_def.radius
	var points := PackedVector2Array()
	# Engine glow sits at the tail of anything with a nose, and at the
	# middle of the shapes that have no front.
	var core_at := Vector2.ZERO
	var core_radius := r * 0.3
	match from_def.silhouette:
		EnemyDef.Silhouette.DART:
			points = Shapes.dart(r * 1.5, r * 0.85)
			core_at = Vector2(-r * 0.6, 0.0)
			core_radius = r * 0.26
		EnemyDef.Silhouette.CHEVRON:
			points = Shapes.chevron(r * 2.0, r * 1.05)
			core_at = Vector2(-r * 0.35, 0.0)
			core_radius = r * 0.24
		EnemyDef.Silhouette.HEX:
			points = Shapes.ngon(r, 6)
			core_radius = r * 0.34
		EnemyDef.Silhouette.CARRIER:
			points = Shapes.star(r * 1.2, r * 0.62, 5)
			core_radius = r * 0.4
	return {
		"hull": points, "loop": Shapes.closed(points),
		"core_at": core_at, "core_radius": core_radius,
	}

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
	set_deferred("monitorable", false)

func _process(delta: float) -> void:
	_face(delta)
	if modulate.r > 1.0:
		modulate = modulate.lerp(Color.WHITE, minf(FLASH_FADE * delta, 1.0))
		if modulate.r < 1.04:
			modulate = Color.WHITE
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var reach := def.radius + target.radius
	if global_position.distance_to(target.global_position) <= reach:
		if _attack_cooldown == 0.0 and target.alive:
			target.take_damage(def.contact_damage)
			_attack_cooldown = def.attack_interval
	else:
		# A summon standing in the way gets fought instead of walked through.
		var blocker: Summon = null
		if _pool.squad != null:
			blocker = _pool.squad.blocking_unit(global_position, def.radius + 4.0)
		if blocker != null:
			if _attack_cooldown == 0.0:
				blocker.take_damage(def.contact_damage)
				_attack_cooldown = def.attack_interval
		else:
			global_position = global_position.move_toward(target.global_position, def.speed * delta)
	if def.behavior == EnemyDef.Behavior.SPAWNER and def.spawned_def != null:
		_spawn_cooldown -= delta
		if _spawn_cooldown <= 0.0:
			_spawn_cooldown = def.spawn_interval
			for i in def.spawn_count:
				var offset := Vector2.from_angle(randf() * TAU) * (def.radius + 14.0)
				_pool.try_spawn(def.spawned_def, global_position + offset, target, _hp_scale)

## Rotation is a transform write, not a redraw, so turning every enemy
## every frame is nearly free — the transform is already dirty from the
## move. Carriers spin in place; everything else points where it's going.
func _face(delta: float) -> void:
	if def.behavior == EnemyDef.Behavior.SPAWNER:
		_spin += delta * CARRIER_SPIN
		rotation = _spin
	else:
		rotation = global_position.direction_to(target.global_position).angle()

func take_damage(amount: float) -> void:
	if not _active:
		return
	hp -= amount
	modulate = HIT_FLASH
	if hp <= 0.0:
		die()

func die() -> void:
	if not _active:
		return
	deactivate()
	# Debris scaled by body size, so a brute comes apart harder than a
	# swarmer and a wiped-out swarm still reads as one big event.
	var shards := clampi(roundi(def.radius * 0.8), 5, 18)
	FxLayer.burst(global_position, def.color, shards, def.radius * 9.0, 0.42)
	# One pop sample covers the whole roster: bigger hull, lower pitch.
	Sfx.play(&"kill", clampf(9.0 / maxf(def.radius, 1.0), 0.45, 1.7), -12.0)
	if def.radius >= 14.0:
		FxLayer.ring(global_position, def.color, def.radius * 0.6, def.radius * 2.8, 0.3, 3.0)
	died.emit(self)

## Drawn once per spawn — the hull never changes, and both the facing and
## the hit flash are transform/modulate writes that need no redraw.
func _draw() -> void:
	if def == null:
		return
	draw_colored_polygon(_hull, Palette.HULL)
	draw_polyline(_hull_loop, Palette.neon(def.color, 1.2), 1.8)
	draw_circle(_core_at, _core_radius, Palette.neon(def.color, 1.7))
