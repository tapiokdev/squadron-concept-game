class_name Tower
extends Node2D

## The player: a stationary tower. No movement — all agency comes from
## skills and summons. If it dies, the run ends.

signal hp_changed(hp: float, max_hp: float)
signal died

@export var max_hp: float = 100.0
@export var radius: float = 22.0

var hp: float = 0.0
var alive := true

func _ready() -> void:
	hp = max_hp

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		alive = false
		died.emit()

func _draw() -> void:
	# Placeholder visual until the art pass.
	draw_circle(Vector2.ZERO, radius, Color(0.75, 0.78, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(0.35, 0.55, 0.9))
