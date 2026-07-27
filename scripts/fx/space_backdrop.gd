class_name SpaceBackdrop
extends Node2D

## Deep-space backdrop: a nebula wash, a seeded starfield, and a faint
## navigation grid under the play area.
##
## This covers every pixel on screen on a web build, so it is deliberately
## cheap: the starfield and grid are baked into one `PackedVector2Array`
## per layer at load and redrawn as a single `draw_multiline` call each,
## and the whole backdrop is about 30 primitives. The nebula breathes so
## the screen never looks like a static wallpaper.

const GRID_SPACING := 96.0
const GRID_MAJOR_EVERY := 4
## Fixed seed: the starfield should look authored, not different per run.
const STAR_SEED := 20260727
const NEBULA_TEX_SIZE := 256

## Far, mid, near parallax-ish layers — near stars are longer and bloom.
@export var star_counts := PackedInt32Array([150, 74, 24])

var _size := Vector2.ZERO
var _star_layers: Array[PackedVector2Array] = []
var _grid_minor := PackedVector2Array()
var _grid_major := PackedVector2Array()
var _clouds: Array[Dictionary] = []
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
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.42))
	_nebula_tex = GradientTexture2D.new()
	_nebula_tex.gradient = gradient
	_nebula_tex.fill = GradientTexture2D.FILL_RADIAL
	_nebula_tex.fill_from = Vector2(0.5, 0.5)
	_nebula_tex.fill_to = Vector2(1.0, 0.5)
	_nebula_tex.width = NEBULA_TEX_SIZE
	_nebula_tex.height = NEBULA_TEX_SIZE

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
	for layer in _star_layers.size():
		var color: Color = STAR_COLORS[layer]
		# Only the nearest layer is bright enough to bloom.
		if layer == _star_layers.size() - 1:
			color = Palette.hot(color, 1.5)
		draw_multiline(_star_layers[layer], color, float(STAR_WIDTHS[layer]))

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
