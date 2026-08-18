class_name Tower
extends Node2D

## The player: a stationary mothership. No movement — all agency comes
## from skills and drones. If it dies, the run ends.
##
## Art note: `radius` is the combat radius, and enemies stop at their own
## radius plus this one.
##
## Condition is carried by the hull integrity ring alone. There used to be
## a second, coarser readout — a rotating band of gapped arcs out at
## radius * 1.85 — and it lied twice: rotating gaps are the visual language
## of an energy screen you could slip between, and an attacker closes to
## radius plus its own before it can land a hit, so it visibly crossed that
## "screen" first. `take_damage` has no mitigation of any kind; every hit
## lands. Pulling the band inside the hit boundary fixed the lie but capped
## it at 16px, which left it smaller and vaguer than the ring already
## sitting outside it, so it earned nothing and is gone.
##
## Radial bands are shared with other systems and deliberately spaced so
## they stay separable at actual size: radius+4 is the hull integrity ring,
## radius+11 is the barrage recharge ring drawn by BarrageSkill.

signal hp_changed(hp: float, max_hp: float)
signal died

@export var max_hp: float = 140.0
@export var radius: float = 22.0

const HULL_SIDES := 6
const HIT_FLASH_TIME := 0.22

var hp: float = 0.0
var alive := true

var _hull := PackedVector2Array()
var _hull_loop := PackedVector2Array()
var _core := PackedVector2Array()
var _core_loop := PackedVector2Array()
var _pulse := 0.0
var _hit_flash := 0.0

func _ready() -> void:
	hp = max_hp
	# The silhouette never changes shape, only colour and spin, so the
	# point rings are built once.
	_hull = Shapes.ngon(radius, HULL_SIDES)
	_hull_loop = Shapes.closed(_hull)
	_core = Shapes.ngon(radius * 0.5, HULL_SIDES)
	_core_loop = Shapes.closed(_core)

func _process(delta: float) -> void:
	var health := _health()
	# The reactor beats faster the closer the hull is to failing — an
	# alarm the player reads without looking at the number.
	_pulse += delta * lerpf(2.0, 7.5, 1.0 - health)
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta, 0.0)
	queue_redraw()

func _health() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0

func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(hp + amount, max_hp)
	FxLayer.ring(global_position, Palette.HEAL, radius * 0.4, radius * 2.6, 0.5, 3.0)
	FxLayer.burst(global_position, Palette.HEAL, 14, 130.0, 0.7)
	Sfx.play(&"deploy", 0.8, -8.0)
	hp_changed.emit(hp, max_hp)

func take_damage(amount: float) -> void:
	if not alive:
		return
	hp = maxf(hp - amount, 0.0)
	_hit_flash = HIT_FLASH_TIME
	# Capped so a swarm landing together still shakes hard without
	# turning the screen into a blender.
	GameCamera.shake(minf(0.22 + amount * 0.012, 0.75))
	FxLayer.ring(global_position, Palette.DANGER, radius * 0.8, radius * 2.0, 0.25, 2.5)
	Sfx.play(&"hull", randf_range(0.92, 1.08), -6.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		alive = false
		_explode()
		died.emit()

func _explode() -> void:
	FxLayer.flash(global_position, Palette.TOWER_CORE, radius * 2.6, 0.5)
	FxLayer.ring(global_position, Palette.TOWER, radius, radius * 10.0, 0.9, 6.0)
	FxLayer.burst(global_position, Palette.TOWER, 44, 430.0, 1.1)
	GameCamera.shake(1.0)
	# The strike sample pitched right down doubles as the hull going up.
	Sfx.play(&"barrage", 0.55, -1.0)

func _draw() -> void:
	if not alive:
		_draw_wreck()
		return
	var health := _health()
	# Hull lighting slides toward the danger colour as the ship is chewed
	# up, so damage is legible from the silhouette alone.
	var edge := Palette.TOWER.lerp(Palette.DANGER, (1.0 - health) * 0.85)
	draw_colored_polygon(_hull, Palette.HULL)
	draw_polyline(_hull_loop, Palette.hot(edge, 1.9), 2.0)
	for i in HULL_SIDES:
		draw_line(_core[i], _hull[i], Palette.hot(edge, 1.1), 1.5)
	draw_colored_polygon(_core, Palette.HULL)
	draw_polyline(_core_loop, Palette.hot(Palette.TOWER_CORE, 1.5), 1.5)
	var beat := 0.5 + 0.5 * sin(_pulse)
	draw_circle(Vector2.ZERO, radius * (0.17 + 0.06 * beat),
		Palette.hot(Palette.TOWER_CORE, 2.0 + beat))
	if _hit_flash > 0.0:
		var flash := _hit_flash / HIT_FLASH_TIME
		draw_polyline(_hull_loop, Palette.hot(Palette.DANGER, 1.0 + 3.0 * flash), 3.0)
	_draw_hull_ring(health)

## The ship's whole condition readout: an unfilled track with an arc that
## drains clockwise from the top and slides toward the danger colour as the
## hull goes. Sole survivor of the two indicators the tower used to carry.
func _draw_hull_ring(health: float) -> void:
	var ring_radius := radius + 4.0
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, Palette.fade(Palette.TOWER, 0.14), 2.5)
	if health <= 0.0:
		return
	var color := Palette.TOWER.lerp(Palette.DANGER, clampf((1.0 - health) * 1.4, 0.0, 1.0))
	draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * health, 40,
		Palette.hot(color, 1.5), 2.5)

func _draw_wreck() -> void:
	draw_colored_polygon(_hull, Color(0.05, 0.04, 0.05, 0.95))
	draw_polyline(_hull_loop, Palette.fade(Palette.DANGER, 0.5), 2.0)
	draw_polyline(_core_loop, Palette.fade(Palette.DANGER, 0.3), 1.5)
