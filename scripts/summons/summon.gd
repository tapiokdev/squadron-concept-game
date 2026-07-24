class_name Summon
extends Node2D

## One summon unit. Lightweight Node2D — summons and enemies find each
## other through list queries, no physics. Movement is squad-driven:
## walk toward the squad's rally point (plus a per-unit slot offset so
## the squad forms a loose ring instead of a stack). No chasing — a
## summon fights what comes into its own reach; rally placement is the
## player's lever. Combat lands in the next chunk.

signal died(summon: Summon)

const STOP_DISTANCE := 3.0

var def: SummonDef
var hp: float = 0.0
var slot_offset := Vector2.ZERO
var respawn_time: float = 10.0

var _squad: SummonSquad
var _active := false

func _ready() -> void:
	set_process(_active)

func configure(squad: SummonSquad, new_def: SummonDef, spawn_pos: Vector2) -> void:
	_squad = squad
	def = new_def
	hp = def.max_hp
	global_position = spawn_pos
	_active = true
	visible = true
	set_process(true)
	queue_redraw()

func deactivate() -> void:
	_active = false
	visible = false
	set_process(false)

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	var goal := _squad.rally_point + slot_offset
	if global_position.distance_to(goal) > STOP_DISTANCE:
		global_position = global_position.move_toward(goal, def.speed * delta)

func take_damage(amount: float) -> void:
	if not _active:
		return
	hp -= amount
	if hp <= 0.0:
		deactivate()
		died.emit(self)

func _draw() -> void:
	# Placeholder visual: filled circle with a white ring so summons
	# read as friendly against the warm-coloured enemies.
	if def:
		draw_circle(Vector2.ZERO, def.radius, def.color)
		draw_arc(Vector2.ZERO, def.radius, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
