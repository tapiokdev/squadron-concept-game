class_name FxLayer
extends Node2D

## Every transient combat effect in the game, drawn from one node.
##
## That single-node shape is the whole point. A death burst per enemy
## would mean a node — and a draw call, and a `_process` — per corpse,
## and the web budget is ~150 concurrent enemies with swarms dying in
## clumps. Instead all sparks live in flat parallel arrays and go out as
## one `draw_multiline_colors` call regardless of how many are alive.
##
## Capacity is fixed and overflow is dropped rather than grown: under a
## heavy swarm, losing a few sparks beats stalling the frame.
##
## Reached statically (`FxLayer.burst(...)`) because the callers are
## pooled enemies and weapons that would otherwise all need wiring for
## something purely cosmetic. The static entry points no-op when no
## layer is in the tree, so nothing has to null-check.

const GlowTexture = preload("res://scripts/fx/glow_texture.gd")
const Palette = preload("res://scripts/fx/palette.gd")

const MAX_SPARKS := 700
const MAX_RINGS := 24
const MAX_FLASHES := 24
## Sparks slow as they travel so bursts read as debris, not tracer fire.
const SPARK_DRAG := 2.8
const SPARK_WIDTH := 2.2
## Streak length per unit of velocity — motion blur without a shader.
const SPARK_STRETCH := 0.045

static var instance: FxLayer

# Sparks: struct-of-arrays, compacted by swapping the dead one with the
# last live one (particle order is not meaningful).
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _life_max := PackedFloat32Array()
var _tint := PackedColorArray()
var _count := 0

# Rings and flashes are few enough that dictionaries stay readable.
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []

# Reused between frames so the batched draw allocates nothing.
var _line_points := PackedVector2Array()
var _line_colors := PackedColorArray()
var _was_busy := false
var _glow_tex: GradientTexture2D

# --- Static API ----------------------------------------------------------

## Debris cone. `dir`/`spread` default to a full circle; pass a direction
## and a narrow spread for directional spray (impacts, thruster wash).
static func burst(pos: Vector2, color: Color, count: int = 8, speed: float = 150.0,
		life: float = 0.45, dir: float = 0.0, spread: float = TAU) -> void:
	if instance != null:
		instance._emit_burst(pos, color, count, speed, life, dir, spread)

## Expanding shockwave outline.
static func ring(pos: Vector2, color: Color, from_radius: float, to_radius: float,
		life: float = 0.35, width: float = 3.0) -> void:
	if instance != null:
		instance._emit_ring(pos, color, from_radius, to_radius, life, width)

## Bright disc that fades on the spot — the core of any impact.
static func flash(pos: Vector2, color: Color, radius: float, life: float = 0.18) -> void:
	if instance != null:
		instance._emit_flash(pos, color, radius, life)

# --- Lifecycle -----------------------------------------------------------

func _ready() -> void:
	instance = self
	# Above units, below the HUD (which is on its own CanvasLayer).
	z_index = 40
	# Tight core, wide halo — an explosion, not a disc of paint.
	_glow_tex = GlowTexture.radial(128, 0.3, 0.42)
	_pos.resize(MAX_SPARKS)
	_vel.resize(MAX_SPARKS)
	_life.resize(MAX_SPARKS)
	_life_max.resize(MAX_SPARKS)
	_tint.resize(MAX_SPARKS)

func _exit_tree() -> void:
	if instance == self:
		instance = null

# --- Emitters ------------------------------------------------------------

func _emit_burst(pos: Vector2, color: Color, count: int, speed: float,
		life: float, dir: float, spread: float) -> void:
	for i in count:
		if _count >= MAX_SPARKS:
			return
		var angle := dir + randf_range(-spread * 0.5, spread * 0.5)
		_pos[_count] = pos
		_vel[_count] = Vector2.from_angle(angle) * speed * randf_range(0.45, 1.0)
		var span := life * randf_range(0.7, 1.15)
		_life[_count] = span
		_life_max[_count] = span
		_tint[_count] = color
		_count += 1

func _emit_ring(pos: Vector2, color: Color, from_radius: float, to_radius: float,
		life: float, width: float) -> void:
	if _rings.size() >= MAX_RINGS:
		return
	_rings.append({
		"pos": pos, "color": color, "from": from_radius, "to": to_radius,
		"life": life, "life_max": life, "width": width,
	})

func _emit_flash(pos: Vector2, color: Color, radius: float, life: float) -> void:
	if _flashes.size() >= MAX_FLASHES:
		return
	_flashes.append({
		"pos": pos, "color": color, "radius": radius, "life": life, "life_max": life,
	})

# --- Simulation ----------------------------------------------------------

func _process(delta: float) -> void:
	_step_sparks(delta)
	_step_timed(_rings, delta)
	_step_timed(_flashes, delta)
	var busy := _count > 0 or not _rings.is_empty() or not _flashes.is_empty()
	# One extra redraw after the last effect dies, to clear the canvas.
	if busy or _was_busy:
		queue_redraw()
	_was_busy = busy

func _step_sparks(delta: float) -> void:
	# Exponential decay keeps the drag frame-rate independent, which a
	# naive (1 - drag * delta) does not at web frame times.
	var damping := exp(-SPARK_DRAG * delta)
	var i := 0
	while i < _count:
		var remaining := _life[i] - delta
		if remaining <= 0.0:
			_count -= 1
			_pos[i] = _pos[_count]
			_vel[i] = _vel[_count]
			_life[i] = _life[_count]
			_life_max[i] = _life_max[_count]
			_tint[i] = _tint[_count]
			continue
		_life[i] = remaining
		_vel[i] *= damping
		_pos[i] += _vel[i] * delta
		i += 1

func _step_timed(items: Array[Dictionary], delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		items[index].life -= delta
		if items[index].life <= 0.0:
			items.remove_at(index)

# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	for flash_fx in _flashes:
		var t: float = flash_fx.life / flash_fx.life_max
		var color: Color = Palette.hot(flash_fx.color, 1.2 + 2.4 * t)
		color.a = flash_fx.color.a * t * 0.9
		var span: float = flash_fx.radius * (0.6 + 0.4 * (1.0 - t))
		draw_texture_rect(_glow_tex,
			Rect2(flash_fx.pos - Vector2(span, span), Vector2(span, span) * 2.0), false, color)
	for ring_fx in _rings:
		var t: float = ring_fx.life / ring_fx.life_max
		# Fast out of the gate, easing into the final radius.
		var progress := 1.0 - pow(t, 3.0)
		var color: Color = Palette.hot(ring_fx.color, 0.8 + 1.8 * t)
		color.a = ring_fx.color.a * t
		draw_arc(ring_fx.pos, lerpf(ring_fx.from, ring_fx.to, progress), 0.0, TAU, 48,
			color, ring_fx.width * (0.35 + 0.65 * t), true)
	_draw_sparks()

func _draw_sparks() -> void:
	if _count == 0:
		return
	_line_points.resize(_count * 2)
	_line_colors.resize(_count)
	for i in _count:
		var t := _life[i] / _life_max[i]
		_line_points[i * 2] = _pos[i]
		_line_points[i * 2 + 1] = _pos[i] - _vel[i] * SPARK_STRETCH
		# Squared falloff: a spark is a hot filament for most of its life,
		# then drops off a cliff rather than lingering as grey mush.
		var color := Palette.hot(_tint[i], 0.6 + 2.4 * t * t)
		color.a = _tint[i].a * t
		_line_colors[i] = color
	draw_multiline_colors(_line_points, _line_colors, SPARK_WIDTH)
