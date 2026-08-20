class_name StartScreen
extends CanvasLayer

## Click-to-begin gate.
##
## This exists for the web build rather than for ceremony. A browser will
## not start an audio context until the page has had a real user gesture,
## and the canvas does not take mouse or keyboard focus until it is clicked
## — so without this the first run opens silent and unfocused, which would
## hide the entire SFX pass behind a bug that looks like "no sound".
##
## It doubles as the one place the controls are stated outright. The in-run
## prompts teach the same two buttons, but they arrive one at a time and
## only for a player who has not already acted; this is the version you can
## read before anything is shooting at you.
##
## The gate is the paused tree, not a flag: pausing in _ready means nothing
## in the run has ticked when the player finally clicks, so the timer starts
## at a genuine zero however long the page sat there.

const Palette = preload("res://scripts/fx/palette.gd")

const PANEL_WIDTH := 430
const PROMPT_RATE := 2.4

var _prompt: Label
var _phase := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	_add(box, "SURVIVE THE INVASION", 28, Palette.neon(Palette.TOWER, 1.2))
	_add(box, "defend the mothership for eight minutes", 13,
		Color(0.62, 0.76, 0.90))
	_spacer(box, 10)
	_add(box, "RIGHT-CLICK     rally your drones", 14, Palette.neon(Palette.COMMAND, 1.0))
	_add(box, "LEFT-CLICK      call a barrage", 14, Palette.neon(Palette.BARRAGE, 1.0))
	_spacer(box, 12)
	_prompt = _add(box, "CLICK TO BEGIN", 16, Palette.neon(Palette.TOWER, 1.3))

	get_tree().paused = true

func _process(delta: float) -> void:
	# The prompt breathes so a page that has been sitting open still reads as
	# waiting for the player rather than as finished loading.
	_phase += delta * PROMPT_RATE
	_prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_phase))

## _input rather than _unhandled_input, and marked handled: the barrage also
## listens for a left click, and input order between siblings is not worth
## relying on. Without this the click that starts the run also spends it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var go: bool = event is InputEventMouseButton and event.pressed
	if event is InputEventKey and event.pressed and not event.echo:
		go = true
	if not go:
		return
	visible = false
	set_process(false)
	get_tree().paused = false
	# The same click is the browser audio gesture that lets a track start.
	Music.start()
	if Music.DIAG:
		print("[audio] gesture received, gate released")
	get_viewport().set_input_as_handled()

func _add(box: VBoxContainer, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return label

func _spacer(box: VBoxContainer, height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.028, 0.055, 0.96)
	style.border_color = Palette.fade(Palette.TOWER, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	return style
