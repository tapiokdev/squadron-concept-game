class_name SummonSquad
extends Node2D

## The squad manager and the core differentiator's plumbing:
## - RMB places the shared rally point; every summon moves toward it.
## - Shared unit cap (6 across all types) per the brief.
## - Stacking: adding another copy of a type gives it a longer respawn
##   (base 10s, then +60% of base per extra copy: 16s, 22s, ...).
## Dead summons respawn at the tower after their timer and walk back.

const MAX_UNITS := 6
const RESPAWN_GROWTH := 0.6

var rally_point := Vector2.ZERO

var _tower: Tower
var _enemies: EnemyPool
var _units: Array[Summon] = []
var _respawning: Array[Dictionary] = []

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower
	rally_point = tower.position + Vector2(0, -110)
	queue_redraw()

func total_units() -> int:
	return _units.size()

func enemy_pool() -> EnemyPool:
	return _enemies

## Nearest active unit whose body is within `reach` of `pos` — used by
## enemies to decide whether a summon is blocking their path.
func blocking_unit(pos: Vector2, reach: float) -> Summon:
	var best: Summon = null
	var best_gap := INF
	for unit in _units:
		if not unit.is_active():
			continue
		var gap := pos.distance_to(unit.global_position) - unit.def.radius
		if gap <= reach and gap < best_gap:
			best_gap = gap
			best = unit
	return best

func count_of(def: SummonDef) -> int:
	var count := 0
	for unit in _units:
		if unit.def == def:
			count += 1
	return count

func try_add_summon(def: SummonDef) -> bool:
	if total_units() >= MAX_UNITS:
		return false
	var copies := count_of(def)
	var unit := Summon.new()
	unit.respawn_time = def.base_respawn * (1.0 + RESPAWN_GROWTH * copies)
	unit.died.connect(_on_summon_died)
	add_child(unit)
	unit.configure(self, def, _tower.position)
	_units.append(unit)
	_assign_slots()
	return true

func _assign_slots() -> void:
	for i in _units.size():
		_units[i].slot_offset = Vector2.from_angle(TAU * float(i) / MAX_UNITS) * 22.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		rally_point = get_global_mouse_position()
		queue_redraw()

func _process(delta: float) -> void:
	for entry in _respawning.duplicate():
		entry.time_left -= delta
		if entry.time_left <= 0.0:
			_respawning.erase(entry)
			var unit: Summon = entry.unit
			unit.configure(self, unit.def, _tower.position)

func _on_summon_died(unit: Summon) -> void:
	# The roster slot stays taken while the unit waits to respawn.
	_respawning.append({"unit": unit, "time_left": unit.respawn_time})

func _draw() -> void:
	# Rally marker: diamond + ground ring.
	var p := rally_point
	var s := 8.0
	var points := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0),
	])
	draw_colored_polygon(points, Color(0.4, 0.9, 0.6, 0.9))
	draw_arc(p, 30.0, 0.0, TAU, 32, Color(0.4, 0.9, 0.6, 0.35), 2.0)
