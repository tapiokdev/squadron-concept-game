class_name Hud
extends CanvasLayer

## Run HUD: timer, hull integrity, level progress, threat count.
##
## Bars are drawn from primitives like the rest of the game rather than
## themed ProgressBars, so the HUD sits in the same art direction as the
## ships. Labels appear only where text is genuinely unavoidable, and all
## of them carry a dark outline — this UI floats over a starfield, and
## thin light text on it is unreadable without one.
##
## The tower carries its own condition ring; this is the precise readout
## for when the player needs a number rather than an impression.

const BAR_ORIGIN := Vector2(18.0, 46.0)
const BAR_SIZE := Vector2(210.0, 12.0)
## Ticks give the bar a scale, so "how much is left" is judgeable.
const BAR_SEGMENTS := 7
const XP_STRIP_HEIGHT := 3.0
## How far the result banner sits above centre, clearing the mothership and
## its rings without drifting up into the timer.
const BANNER_LIFT := 110.0

## Anchors only resolve against a Control parent, so everything lives
## under one full-rect root rather than directly on the CanvasLayer.
var _root: Control
var _timer: Label
var _hp_text: Label
var _level: Label
var _threat: Label
var _banner: Label
var _hint: Label

var _health := 1.0
var _progress := 0.0
var _hint_phase := 0.0

func _ready() -> void:
	layer = 5
	_root = Control.new()
	# ...and_offsets_ matters: plain set_anchors_preset re-derives the
	# offsets to preserve the current rect, which for a fresh node means
	# it stays collapsed at its minimum size in the top-left corner.
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_bars)
	add_child(_root)

	_timer = _add_label(24, Color(0.88, 0.95, 1.0))
	_timer.position = Vector2(18.0, 10.0)

	_hp_text = _add_label(13, Color(0.66, 0.80, 0.92))
	_hp_text.position = Vector2(BAR_ORIGIN.x + BAR_SIZE.x + 10.0, BAR_ORIGIN.y - 4.0)

	_level = _add_label(18, Color(0.72, 0.94, 1.0))
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor_right(_level, 12.0)

	_threat = _add_label(12, Color(0.72, 0.55, 0.68))
	_threat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor_right(_threat, 40.0)

	# Control prompts live at the bottom edge, out of the play space and
	# where prompts are conventionally looked for.
	_hint = _add_label(15, Color(0.62, 0.86, 1.0))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.offset_bottom = -54.0
	_hint.visible = false

	_banner = _add_label(34, Color(0.92, 0.97, 1.0))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The mothership sits dead centre of the viewport, so a centred banner
	# lands right on top of it. Shrinking the rect from the bottom lifts the
	# text by half the amount taken off.
	_banner.offset_bottom = -BANNER_LIFT * 2.0
	_banner.visible = false

func _add_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# Everything here sits over stars and nebula; without an outline the
	# thin glyphs disappear the moment something bright passes behind.
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.02, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func _anchor_right(label: Label, top: float) -> void:
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -220.0
	label.offset_right = -18.0
	label.offset_top = top

func update_run(remaining: float, hp: float, max_hp: float,
		level: int, xp: int, xp_needed: int, threat: int) -> void:
	var whole := int(maxf(remaining, 0.0))
	_timer.text = "%d:%02d" % [whole / 60, whole % 60]
	_hp_text.text = "%d / %d" % [roundi(hp), roundi(max_hp)]
	_level.text = "LV %d" % level
	_threat.text = "%d hostile" % threat if threat == 1 else "%d hostiles" % threat
	_health = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_progress = clampf(float(xp) / float(maxi(xp_needed, 1)), 0.0, 1.0)
	# A hint that simply sits there is easy to look past, and this one has to
	# be noticed by someone who does not yet know the control exists. Ridden
	# off this call rather than a _process of its own, since main already
	# drives the HUD every frame.
	if _hint.visible:
		_hint_phase += 0.045
		_hint.modulate.a = 0.62 + 0.38 * (0.5 + 0.5 * sin(_hint_phase))
	_root.queue_redraw()

## Control prompt. Called every frame while a hint is wanted, so it
## early-outs on an unchanged string rather than re-laying out the label.
func show_hint(text: String) -> void:
	if _hint.visible and _hint.text == text:
		return
	_hint.text = text
	_hint.visible = true

func hide_hint() -> void:
	_hint.visible = false

func show_result(text: String) -> void:
	_banner.text = text
	_banner.visible = true

func _draw_bars() -> void:
	var width := _root.size.x
	# Level progress runs the full width of the screen edge — always in
	# peripheral vision, never in the way.
	_root.draw_rect(Rect2(0.0, 0.0, width, XP_STRIP_HEIGHT), Palette.fade(Palette.XP, 0.16))
	if _progress > 0.0:
		_root.draw_rect(Rect2(0.0, 0.0, width * _progress, XP_STRIP_HEIGHT),
			Palette.neon(Palette.XP, 1.2))
	var frame := Rect2(BAR_ORIGIN, BAR_SIZE)
	_root.draw_rect(frame, Palette.fade(Palette.TOWER, 0.10))
	if _health > 0.0:
		var color := Palette.TOWER.lerp(Palette.DANGER, clampf((1.0 - _health) * 1.4, 0.0, 1.0))
		_root.draw_rect(Rect2(BAR_ORIGIN, Vector2(BAR_SIZE.x * _health, BAR_SIZE.y)),
			Palette.neon(color, 1.25))
	for i in range(1, BAR_SEGMENTS):
		var x := BAR_ORIGIN.x + BAR_SIZE.x * float(i) / float(BAR_SEGMENTS)
		_root.draw_line(Vector2(x, BAR_ORIGIN.y), Vector2(x, BAR_ORIGIN.y + BAR_SIZE.y),
			Palette.VOID, 1.0)
	_root.draw_rect(frame, Palette.fade(Palette.TOWER, 0.45), false, 1.0)
