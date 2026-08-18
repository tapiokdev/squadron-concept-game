class_name Drone
extends Node2D

## One drone unit. Lightweight Node2D — drones and enemies find each
## other through list queries, no physics. Movement is squad-driven:
## walk toward the squad's rally point (plus a per-unit slot offset so
## the squad forms a loose ring instead of a stack). No chasing — a
## a drone fights what comes into its own reach; rally placement is the
## player's lever.
##
## Art follows the enemies' rules so friend and foe read the same way:
## cool blue hull, geometry from Shapes, facing by transform rather than
## redraw, hit flash by `modulate`. Condition shows in the hull tint,
## which is rotation-proof — an HP arc would spin with the ship.

signal died(drone: Drone)

const STOP_DISTANCE := 3.0
const SHOT_FLASH_TIME := 0.12
const HIT_FLASH := Color(2.6, 2.6, 2.6)
const FLASH_FADE := 10.0
## Below this attack range a shot is a melee swipe, not a tracer.
const MELEE_SHOT_RANGE := 60.0
## The swipe runs longer than the tracer. A tracer is a line drawn across
## open space and reads instantly; a swipe at the hull's edge is easy to
## miss entirely between one-second swings, which left the Bastion looking
## like it was doing nothing at all.
const MELEE_SWIPE_TIME := 0.22
## How far the hull jabs at what it is hitting, and how long that settles.
## Drawn, never moved: movement, blocking reach and enemy targeting all read
## global_position, so a positional lunge would twitch the hitbox.
const LUNGE_PX := 7.0
const LUNGE_TIME := 0.18

var def: DroneDef
var hp: float = 0.0
var slot_offset := Vector2.ZERO
var respawn_time: float = 10.0

var _squad: DroneSquad
var _active := false
var _attack_cooldown: float = 0.0
var _shot_target := Vector2.ZERO
var _shot_left: float = 0.0
var _lunge: float = 0.0
var _hull := PackedVector2Array()
var _hull_loop := PackedVector2Array()
var _heading := 0.0

func _ready() -> void:
	set_process(_active)

func configure(squad: DroneSquad, new_def: DroneDef, spawn_pos: Vector2) -> void:
	_squad = squad
	def = new_def
	hp = def.max_hp
	global_position = spawn_pos
	_attack_cooldown = 0.0
	# Units are pooled, so clear the last life's swing or a respawn flashes
	# a stale swipe on its first frame.
	_shot_left = 0.0
	_lunge = 0.0
	_active = true
	visible = true
	modulate = Color.WHITE
	_build_hull()
	set_process(true)
	# Warp-in, matching how a carrier's swarm arrives — a unit that simply blinks
	# into existence at the tower reads as a glitch.
	FxLayer.ring(spawn_pos, def.color, def.radius * 3.0, def.radius * 0.6, 0.3, 2.0)
	Sfx.play(&"deploy", 1.0, -11.0)
	queue_redraw()

func _build_hull() -> void:
	var r := def.radius
	if def.frame == DroneDef.Frame.LANCER:
		# Slim four-point kite: light, pointy, obviously standoff.
		_hull = Shapes.star(r * 1.5, r * 0.5, 4)
	else:
		# Broad hexagon: something that looks like it can hold a line.
		_hull = Shapes.ngon(r * 1.15, 6)
	_hull_loop = Shapes.closed(_hull)

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	var goal := _squad.rally_point + slot_offset
	if global_position.distance_to(goal) > STOP_DISTANCE:
		_heading = global_position.direction_to(goal).angle()
		global_position = global_position.move_toward(goal, def.speed * delta)
	if modulate.r > 1.0:
		modulate = modulate.lerp(Color.WHITE, minf(FLASH_FADE * delta, 1.0))
		if modulate.r < 1.04:
			modulate = Color.WHITE
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_cooldown == 0.0:
		var target := _squad.enemy_pool().nearest_live(global_position, def.attack_range + def.radius)
		if target != null:
			_fire(target)
	if _shot_left > 0.0:
		_shot_left = maxf(_shot_left - delta, 0.0)
		queue_redraw()
	if _lunge > 0.0:
		_lunge = maxf(_lunge - delta / LUNGE_TIME, 0.0)
		queue_redraw()
	rotation = _heading

func _fire(target: Enemy) -> void:
	target.take_damage(def.attack_damage)
	_attack_cooldown = def.attack_interval
	_shot_target = target.global_position
	# Turn into the shot, so a unit under attack visibly faces the fight.
	_heading = global_position.direction_to(_shot_target).angle()
	if _is_melee():
		_shot_left = MELEE_SWIPE_TIME
		_lunge = 1.0
		# hot() rather than def.color, because the Bastion's blue is very
		# nearly the Rail's and the screen is full of Rail sparks. Separating
		# by brightness is exactly what the palette reserves hot() for.
		FxLayer.flash(_shot_target, Palette.hot(def.color, 1.6), def.radius * 1.1, 0.12)
		FxLayer.burst(_shot_target, Palette.hot(def.color, 1.3), 7, 120.0, 0.24)
	else:
		_shot_left = SHOT_FLASH_TIME
		FxLayer.burst(_shot_target, def.color, 3, 80.0, 0.2)
	queue_redraw()

func _is_melee() -> bool:
	return def.attack_range <= MELEE_SHOT_RANGE

func take_damage(amount: float) -> void:
	if not _active:
		return
	hp -= amount
	modulate = HIT_FLASH
	queue_redraw()
	if hp <= 0.0:
		FxLayer.burst(global_position, def.color, 14, def.radius * 12.0, 0.5)
		FxLayer.ring(global_position, def.color, def.radius * 0.5, def.radius * 3.0, 0.32, 2.5)
		deactivate()
		died.emit(self)

func _draw() -> void:
	if def == null:
		return
	# Local space is already rotated to _heading and _fire aims that at the
	# target, so the jab is simply +X. A draw transform rather than a move,
	# so nothing outside this function can see it.
	if _lunge > 0.0:
		draw_set_transform(Vector2(LUNGE_PX * _lunge, 0.0), 0.0, Vector2.ONE)
	var health := clampf(hp / def.max_hp, 0.0, 1.0)
	var edge := def.color.lerp(Palette.DANGER, (1.0 - health) * 0.8)
	draw_colored_polygon(_hull, Palette.HULL)
	draw_polyline(_hull_loop, Palette.neon(edge, 1.25), 1.8)
	draw_circle(Vector2.ZERO, def.radius * 0.3, Palette.neon(edge, 1.7))
	if _shot_left > 0.0:
		_draw_shot()

## Local space is rotated to `_heading`, and `_fire` points the heading at
## the target, so the swipe and the tracer both line up along +X.
func _draw_shot() -> void:
	var melee := _is_melee()
	var strength := _shot_left / (MELEE_SWIPE_TIME if melee else SHOT_FLASH_TIME)
	var color := Palette.hot(def.color, 1.2 + 1.4 * strength)
	color.a = strength
	if melee:
		# The leading edge travels while the swipe fades, so it reads as a
		# blade wiping through rather than a shape blinking on and off. Drawn
		# clear of the hull, since the thing it is hitting is right there.
		var lead := lerpf(-1.0, 1.0, 1.0 - strength)
		draw_arc(Vector2.ZERO, def.radius * 2.4, -1.0, lead, 12, color, 4.0, true)
	else:
		draw_line(Vector2.ZERO, to_local(_shot_target), color, 1.6)
