class_name SpaceBackdrop
extends Node2D

## Deep-space backdrop: a nebula wash, a seeded starfield, and a faint
## navigation grid under the play area.
##
## This covers every pixel on screen on a web build, so it is deliberately
## cheap: the starfield and grid are baked into one `PackedVector2Array`
## per layer at load and redrawn as a single `draw_multiline` call each,
## and the whole backdrop is about 30 primitives. The nebula breathes and
## the starfield drifts, so the screen never looks like a static wallpaper.
##
## Nothing is rebuilt to make the stars move: the baked points are drawn
## through a wrapped `draw_set_transform`, so the drift costs one extra
## call per layer and no per-frame allocation.

const GlowTexture = preload("res://scripts/fx/glow_texture.gd")
const Palette = preload("res://scripts/fx/palette.gd")

const GRID_SPACING := 96.0
const GRID_MAJOR_EVERY := 4
## Fixed seed: the starfield should look authored, not different per run.
const STAR_SEED := 20260727
const NEBULA_TEX_SIZE := 256

## Far, mid, near parallax-ish layers — near stars are longer and bloom.
@export var star_counts := PackedInt32Array([150, 74, 24])

## Which way the starfield slides. The mothership is welded to the centre
## of the screen, so travel can only be shown by moving everything else:
## stars falling read as the ship holding a course "up", into the lanes the
## invasion comes down. Any direction works — the wrap adapts.
const DRIFT := Vector2(0.0, 1.0)
## Pixels per second for the nearest layer. Deliberately a crawl — this is
## meant to register as depth at the edge of attention, never as something
## competing with the swarm for the eye.
const DRIFT_SPEED := 16.0
## Each layer's share of that speed. The spread is the whole effect: at one
## speed the field slides as a flat sheet and reads as a scrolling texture
## rather than as distance.
const STAR_DRIFT := [0.22, 0.5, 1.0]

var _size := Vector2.ZERO
var _star_layers: Array[PackedVector2Array] = []
var _grid_minor := PackedVector2Array()
var _grid_major := PackedVector2Array()
var _clouds: Array[Dictionary] = []
var _wrap_tiles: Array[Vector2] = []
var _nebula_tex: GradientTexture2D
var _phase := 0.0

const STAR_COLORS := [Palette.STAR_FAR, Palette.STAR_MID, Palette.STAR_NEAR]
const STAR_WIDTHS := [1.0, 1.4, 2.0]
const STAR_LENGTHS := [1.0, 1.5, 2.4]

func _ready() -> void:
	# Behind every gameplay layer regardless of sibling order.
	z_index = -100
	_build_nebula_texture()
	_rebuild()
	get_viewport().size_changed.connect(_rebuild)

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _rebuild() -> void:
	_size = get_viewport_rect().size
	_build_stars()
	_build_wrap_tiles()
	_build_grid()
	_build_clouds()
	queue_redraw()

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	_star_layers.clear()
	for layer in star_counts.size():
		# One star = one degenerate-ish segment, so a whole layer is a
		# single draw call instead of N draw_circle calls.
		var points := PackedVector2Array()
		for i in star_counts[layer]:
			var origin := Vector2(rng.randf() * _size.x, rng.randf() * _size.y)
			points.append(origin)
			points.append(origin + Vector2(float(STAR_LENGTHS[layer]), 0.0))
		_star_layers.append(points)

## A drifting layer has to be redrawn at every wrap offset that can still
## reach the screen: one trailing copy per axis it moves along, plus the
## diagonal if it moves along both. `fposmod` pulls the live offset back
## inside one screen whatever the sign of DRIFT, so the trailing copy is
## always exactly one screen behind. Built per resize, not per frame.
func _build_wrap_tiles() -> void:
	var steps_x: Array = [0.0] if is_zero_approx(DRIFT.x) else [0.0, -_size.x]
	var steps_y: Array = [0.0] if is_zero_approx(DRIFT.y) else [0.0, -_size.y]
	_wrap_tiles.clear()
	for x: float in steps_x:
		for y: float in steps_y:
			_wrap_tiles.append(Vector2(x, y))

func _build_grid() -> void:
	_grid_minor = PackedVector2Array()
	_grid_major = PackedVector2Array()
	# Anchor the grid on the screen centre so the mothership sits on an
	# intersection rather than floating between cells.
	var center := _size * 0.5
	var first_x := fmod(center.x, GRID_SPACING)
	var first_y := fmod(center.y, GRID_SPACING)
	# Packed arrays are copy-on-write, so the members are appended to
	# directly rather than through a local alias.
	var col := int(-center.x / GRID_SPACING)
	var x := first_x
	while x <= _size.x:
		if col % GRID_MAJOR_EVERY == 0:
			_grid_major.append(Vector2(x, 0.0))
			_grid_major.append(Vector2(x, _size.y))
		else:
			_grid_minor.append(Vector2(x, 0.0))
			_grid_minor.append(Vector2(x, _size.y))
		x += GRID_SPACING
		col += 1
	var row := int(-center.y / GRID_SPACING)
	var y := first_y
	while y <= _size.y:
		if row % GRID_MAJOR_EVERY == 0:
			_grid_major.append(Vector2(0.0, y))
			_grid_major.append(Vector2(_size.x, y))
		else:
			_grid_minor.append(Vector2(0.0, y))
			_grid_minor.append(Vector2(_size.x, y))
		y += GRID_SPACING
		row += 1

## One shared radial falloff, tinted per cloud at draw time. Stacking
## translucent discs was the texture-free option but banded visibly; a
## 256px gradient is smooth, and it collapses each cloud to one draw call.
func _build_nebula_texture() -> void:
	_nebula_tex = GlowTexture.radial(NEBULA_TEX_SIZE, 0.45, 0.42)

func _build_clouds() -> void:
	# Placed proportionally so they survive a resize, and kept off-centre
	# so the nebula never competes with the action around the tower.
	_clouds = [
		{"at": Vector2(0.16, 0.26), "radius": 0.62, "tint": Palette.NEBULA_COOL, "rate": 0.09},
		{"at": Vector2(0.86, 0.74), "radius": 0.54, "tint": Palette.NEBULA_WARM, "rate": 0.13},
		{"at": Vector2(0.70, 0.12), "radius": 0.38, "tint": Palette.NEBULA_COOL, "rate": 0.07},
	]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), Palette.VOID)
	_draw_nebula()
	if not _grid_minor.is_empty():
		draw_multiline(_grid_minor, Palette.GRID_MINOR, 1.0)
	if not _grid_major.is_empty():
		draw_multiline(_grid_major, Palette.GRID_MAJOR, 1.0)
	_draw_stars()

## The grid deliberately stays put while the stars move: it is the ship's
## own reference frame rather than part of the sky, and holding it still is
## what keeps the drift readable instead of setting the whole screen adrift.
func _draw_stars() -> void:
	for layer in _star_layers.size():
		var color: Color = STAR_COLORS[layer]
		# Only the nearest layer is bright enough to bloom.
		if layer == _star_layers.size() - 1:
			color = Palette.hot(color, 1.5)
		var shift := _drift_shift(layer)
		for tile in _wrap_tiles:
			draw_set_transform(shift + tile)
			draw_multiline(_star_layers[layer], color, float(STAR_WIDTHS[layer]))
	# Stars happen to be drawn last, but leaving a live transform behind is
	# a trap for whatever gets added after them.
	draw_set_transform(Vector2.ZERO)

## How far a layer has slid this frame, wrapped into one screen so the
## offset never grows without bound and the field never runs out of stars.
func _drift_shift(layer: int) -> Vector2:
	var offset := DRIFT * (_phase * DRIFT_SPEED * float(STAR_DRIFT[layer]))
	return Vector2(fposmod(offset.x, _size.x), fposmod(offset.y, _size.y))

func _draw_nebula() -> void:
	if _nebula_tex == null:
		return
	var span := maxf(_size.x, _size.y)
	for cloud in _clouds:
		var center: Vector2 = cloud.at * _size
		var radius: float = cloud.radius * span
		var breath: float = 0.78 + 0.22 * sin(_phase * cloud.rate * TAU)
		var rect := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		draw_texture_rect(_nebula_tex, rect, false, Palette.fade(cloud.tint, breath))
