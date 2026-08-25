class_name Enemy
extends Area2D

## Lightweight pooled enemy: Area2D + move_toward(), no physics body.
## Built entirely in code (no scene file) so the pool can cheaply
## instantiate and reconfigure instances from any EnemyDef.

const Drone = preload("res://scripts/drones/drone.gd")
const Palette = preload("res://scripts/fx/palette.gd")
const Shapes = preload("res://scripts/fx/shapes.gd")

signal died(enemy: Enemy)

const ENEMY_COLLISION_LAYER := 2

## Hit flash is a `modulate` multiply rather than a redraw, so 150 of
## these can be taking fire at once for free.
const HIT_FLASH := Color(2.8, 2.8, 2.8)
const FLASH_FADE := 11.0
## Carriers ignore their heading and turn slowly on the spot instead.
const CARRIER_SPIN := 0.45
## Facing changes smaller than this are not written. 0.001 rad moves the
## rim of the widest hull by 0.02px, so nothing is given up.
const FACING_EPSILON := 0.001

## How far the hull jabs at whatever it just hit, as a share of its own
## radius, and how long that settles — so a Dreadnought shoves where a
## Swarmer twitches. Clamped at both ends: the small hulls need a floor to
## register at all, and nothing should out-swing the Bastion's 7px lunge,
## which belongs to a unit swinging deliberately rather than a crowd.
##
## The jab moves the Hull child, never `global_position` — that drives this
## enemy's own `move_toward`, the drones' and weapons' `nearest_live`
## targeting, and `blocking_unit`, so displacing it would twitch the hitbox,
## flicker which enemy the Rail picks, and corrupt the movement integration.
const LUNGE_REACH := 0.30
const LUNGE_MIN_PX := 3.0
const LUNGE_MAX_PX := 7.0
const LUNGE_TIME := 0.14

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
var _lunge := 0.0
var _lunge_offset := Vector2.ZERO
var _hull_node: Hull

func _init() -> void:
	collision_layer = ENEMY_COLLISION_LAYER
	collision_mask = 0
	monitoring = false
	_shape = CircleShape2D.new()
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	var hull := Hull.new()
	hull.enemy = self
	add_child(hull)
	_hull_node = hull
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
	# Pooled, so clear the last life's jab or a respawn shows it mid-swing.
	_lunge = 0.0
	_hull_node.position = Vector2.ZERO
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
	# will be seen — which is exactly a carrier's swarm.
	if get_viewport_rect().has_point(spawn_pos):
		FxLayer.ring(spawn_pos, def.color, def.radius * 2.6, def.radius * 0.6, 0.28, 2.0)
	_hull_node.queue_redraw()

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
	if _lunge > 0.0:
		_lunge = maxf(_lunge - delta / LUNGE_TIME, 0.0)
		_hull_node.position = _lunge_offset * _lunge
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var reach := def.radius + target.radius
	if global_position.distance_to(target.global_position) <= reach:
		if _attack_cooldown == 0.0 and target.alive:
			target.take_damage(def.contact_damage)
			_attack_cooldown = def.attack_interval
			_jab(target.global_position)
	else:
		# A drone standing in the way gets fought instead of walked through.
		var blocker: Drone = null
		if _pool.squad != null:
			blocker = _pool.squad.blocking_unit(global_position, def.radius + 4.0)
		if blocker != null:
			if _attack_cooldown == 0.0:
				blocker.take_damage(def.contact_damage)
				_attack_cooldown = def.attack_interval
				_jab(blocker.global_position)
		else:
			global_position = global_position.move_toward(target.global_position, def.speed * delta)
	if def.behavior == EnemyDef.Behavior.SPAWNER and def.spawned_def != null:
		_spawn_cooldown -= delta
		if _spawn_cooldown <= 0.0:
			_spawn_cooldown = def.spawn_interval
			for i in def.spawn_count:
				var offset := Vector2.from_angle(randf() * TAU) * (def.radius + 14.0)
				_pool.try_spawn(def.spawned_def, global_position + offset, target, _hp_scale)

## Carriers spin in place; everything else points where it's going.
##
## Rotation is a transform write rather than a redraw, but the cheapest one
## is the one not made: `move_toward` walks straight at the target, so a
## walker's direction to it never changes over the whole approach, and one
## in contact has stopped moving at all. Nearly every frame would rewrite
## the angle it already had — and each write dirties this node's transform
## plus every child's global transform, the collision shape and the Hull.
##
## `angle_difference` rather than a subtraction: an enemy due east of the
## tower faces ±PI, where the sign flips on float noise and a plain compare
## reads 2π and writes every frame — the case the guard most needs to get
## right.
func _face(delta: float) -> void:
	if def.behavior == EnemyDef.Behavior.SPAWNER:
		_spin += delta * CARRIER_SPIN
		rotation = _spin
		return
	var facing := global_position.direction_to(target.global_position).angle()
	if absf(angle_difference(rotation, facing)) > FACING_EPSILON:
		rotation = facing

## A short shove toward whatever was just hit — the only signal an attack
## gives off from the attacking end. Everything else about being hit is
## drawn on the receiver (tower flash, ring, shake), which says the player
## is taking damage but not from where; with twenty hostiles on the rim
## that is the difference between reading the fight and guessing at it.
##
## Aimed at the victim rather than along local +X, because neither of the
## two callers can rely on +X: a Carrier spins on the spot, and an enemy
## fighting a blocking drone is still rotated at the tower behind it.
func _jab(at: Vector2) -> void:
	var dir := to_local(at)
	if dir == Vector2.ZERO:
		return
	_lunge = 1.0
	_lunge_offset = dir.normalized() \
			* clampf(def.radius * LUNGE_REACH, LUNGE_MIN_PX, LUNGE_MAX_PX)
	_hull_node.position = _lunge_offset

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
	# Debris scaled by body size, so a bulwark comes apart harder than a
	# swarmer and a wiped-out swarm still reads as one big event.
	var shards := clampi(roundi(def.radius * 0.8), 5, 18)
	FxLayer.burst(global_position, def.color, shards, def.radius * 9.0, 0.42)
	# One pop sample covers the whole roster: bigger hull, lower pitch.
	Sfx.play(&"kill", clampf(9.0 / maxf(def.radius, 1.0), 0.45, 1.7), -12.0)
	if def.radius >= 14.0:
		FxLayer.ring(global_position, def.color, def.radius * 0.6, def.radius * 2.8, 0.3, 3.0)
	died.emit(self)

## The hull draws on its own node purely so the attack jab can be a
## transform write. Drawn once per spawn, as before — the hull never
## changes, and facing and hit flash are transform/modulate writes.
##
## Keeping the jab in draw space instead meant re-recording the polygon
## every frame one was settling, which measured +1.35ms per frame (+46% of
## process time) with 52 hostiles on the rim: `draw_colored_polygon` and
## `draw_polyline` rebuild their geometry on every call, so "drawn once per
## spawn" was carrying far more weight than it looked like. Moving the node
## instead of the pen costs one Node2D per pooled enemy and nothing per
## frame.
##
## Parented to the Enemy, so facing rotation and the hit-flash `modulate`
## come down for free and `_lunge_offset` — already in Enemy-local space —
## drops straight into `position`.
class Hull extends Node2D:
	const Palette = preload("res://scripts/fx/palette.gd")

	var enemy: Enemy

	func _draw() -> void:
		if enemy == null or enemy.def == null:
			return
		draw_colored_polygon(enemy._hull, Palette.HULL)
		draw_polyline(enemy._hull_loop, Palette.neon(enemy.def.color, 1.2), 1.8)
		draw_circle(enemy._core_at, enemy._core_radius,
				Palette.neon(enemy.def.color, 1.7))
