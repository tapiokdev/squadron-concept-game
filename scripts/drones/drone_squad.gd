class_name DroneSquad
extends Node2D

## The squad manager and the core differentiator's plumbing:
## - RMB places the shared rally point; every drone moves toward it.
## - Shared unit cap (6 across all types) per the brief.
## - Stacking: adding another copy of a type gives it a longer respawn
##   (base 10s, then +60% of base per extra copy: 16s, 22s, ...).
## Dead drones respawn at the tower after their timer and walk back.

const Drone = preload("res://scripts/drones/drone.gd")
const Palette = preload("res://scripts/fx/palette.gd")

const MAX_UNITS := 6
const RESPAWN_GROWTH := 0.6
const SLOT_RADIUS := 22.0
## Attack range below this counts as melee for formation purposes.
const MELEE_RANGE_CUTOFF := 60.0
const REFORM_INTERVAL := 0.5
const MARKER_SPIN := 0.6
## Respawn docks orbit clear of every ring the tower reserves.
const DOCK_ORBIT := 42.0

## The formation only reacts to enemies this close to the rally point;
## farther threats (often off-screen) shouldn't make the squad shuffle.
@export var threat_scan_radius := 200.0

var rally_point := Vector2.ZERO
## Whether the player has ever given a rally order. Drives the opening
## hint, which has no business appearing for someone already doing it.
var has_rallied := false

var _tower: Tower
var _enemies: EnemyPool
var _units: Array[Drone] = []
var _respawning: Array[Dictionary] = []
var _reform_timer := 0.0
var _marker_spin := 0.0

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower
	# Below the mothership, deliberately opposite the first spawn arc, which
	# comes in from straight up. The squad used to start parked on the only
	# active lane, which meant the opening minutes asked the player for no
	# commands at all — the run now poses its central question immediately.
	rally_point = tower.position + Vector2(0, 110)
	queue_redraw()

func total_units() -> int:
	return _units.size()

func enemy_pool() -> EnemyPool:
	return _enemies

## Nearest active unit whose body is within `reach` of `pos` — used by
## enemies to decide whether a drone is blocking their path.
func blocking_unit(pos: Vector2, reach: float) -> Drone:
	var best: Drone = null
	var best_gap := INF
	for unit in _units:
		if not unit.is_active():
			continue
		var gap := pos.distance_to(unit.global_position) - unit.def.radius
		if gap <= reach and gap < best_gap:
			best_gap = gap
			best = unit
	return best

func count_of(def: DroneDef) -> int:
	var count := 0
	for unit in _units:
		if unit.def == def:
			count += 1
	return count

func try_add_drone(def: DroneDef) -> bool:
	if total_units() >= MAX_UNITS:
		return false
	var copies := count_of(def)
	var unit := Drone.new()
	unit.respawn_time = def.base_respawn * (1.0 + RESPAWN_GROWTH * copies)
	unit.died.connect(_on_drone_died)
	add_child(unit)
	unit.configure(self, def, _tower.position)
	_units.append(unit)
	_assign_slots()
	return true

## Threat-aware formation: melee units get the ring slots facing the
## nearest enemy, ranged units the back arc — so committing the squad
## to a lane means the Bastion tanks, not whoever's slot happened to
## face the threat. With no enemy nearby, "front" faces away from the
## tower (the direction danger comes from).
func _assign_slots() -> void:
	var n := _units.size()
	if n == 0:
		return
	var threat_angle := _tower.position.direction_to(rally_point).angle()
	var foe := _enemies.nearest_live(rally_point, threat_scan_radius)
	if foe != null:
		threat_angle = rally_point.direction_to(foe.global_position).angle()
	# Ring slot i sits at threat_angle + i*TAU/n; slots ordered by how
	# close they are to the threat direction (0, 1, n-1, 2, n-2, ...).
	var slot_order := range(n)
	slot_order.sort_custom(func(a: int, b: int) -> bool:
		return mini(a, n - a) < mini(b, n - b))
	var by_role := _units.duplicate()
	by_role.sort_custom(func(a: Drone, b: Drone) -> bool:
		return a.def.attack_range < b.def.attack_range)
	for k in n:
		var angle := threat_angle + TAU * float(slot_order[k]) / n
		by_role[k].slot_offset = Vector2.from_angle(angle) * SLOT_RADIUS

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		rally_point = get_global_mouse_position()
		has_rallied = true
		queue_redraw()

func _process(delta: float) -> void:
	_reform_timer -= delta
	if _reform_timer <= 0.0:
		_reform_timer = REFORM_INTERVAL
		_assign_slots()
	for entry in _respawning.duplicate():
		entry.time_left -= delta
		if entry.time_left <= 0.0:
			_respawning.erase(entry)
			var unit: Drone = entry.unit
			unit.configure(self, unit.def, _tower.position)
	# The marker animates and the dock arcs fill, so this node is never
	# static for long — one node, roughly a dozen primitives.
	_marker_spin += delta * MARKER_SPIN
	queue_redraw()

func _on_drone_died(unit: Drone) -> void:
	# The roster slot stays taken while the unit waits to respawn.
	_respawning.append({"unit": unit, "time_left": unit.respawn_time})

func _draw() -> void:
	_draw_rally_marker()
	_draw_respawn_docks()

## Orbiting brackets around a beating diamond. Green and unlike any hull
## in the game, so the order never reads as another unit.
func _draw_rally_marker() -> void:
	var p := rally_point
	var bracket := Palette.neon(Palette.COMMAND, 1.2)
	for i in 4:
		var mid := _marker_spin + TAU * float(i) / 4.0
		draw_arc(p, 18.0, mid - 0.30, mid + 0.30, 8, bracket, 2.0)
	draw_arc(p, 30.0, 0.0, TAU, 32, Palette.fade(Palette.COMMAND, 0.20), 1.5)
	var beat := 0.5 + 0.5 * sin(_marker_spin * 3.0)
	var s := 4.0 + 1.5 * beat
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0),
	]), Palette.hot(Palette.COMMAND, 1.4 + 0.6 * beat))

## A filling arc per dead unit, docked around the mothership. Stacking a
## type makes its respawn longer, so "when does my Bastion come back" is
## a real question the player has no other way to answer.
func _draw_respawn_docks() -> void:
	var pending := _respawning.size()
	if pending == 0:
		return
	for i in pending:
		var entry := _respawning[i]
		var unit: Drone = entry.unit
		var angle := TAU * float(i) / float(pending) - PI * 0.5
		var at: Vector2 = _tower.position + Vector2.from_angle(angle) * (_tower.radius + DOCK_ORBIT)
		var left: float = entry.time_left
		var progress := 1.0 - clampf(left / maxf(unit.respawn_time, 0.001), 0.0, 1.0)
		draw_arc(at, 7.0, 0.0, TAU, 16, Palette.fade(unit.def.color, 0.25), 1.5)
		draw_arc(at, 7.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 16,
			Palette.neon(unit.def.color, 1.15), 2.0)
