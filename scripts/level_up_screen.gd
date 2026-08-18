class_name LevelUpScreen
extends CanvasLayer

## Choose-one-of-three level-up screen. Pauses the tree while open; this
## layer runs PROCESS_MODE_ALWAYS so the buttons stay clickable.
##
## Styled with StyleBoxFlat rather than custom-drawn cards: the same neon
## look for a fraction of the code, and Buttons keep their focus and
## keyboard handling for free. Offers are colour-coded by track — the
## screen alternates squad and tower picks, and the player should see
## which one they're being handed before reading a word.

signal choice_made

const SQUAD_ACCENT := Palette.COMMAND
const TOWER_ACCENT := Palette.TOWER
const PANEL_WIDTH := 460

## Seconds for the border light to complete one lap. Slow enough to read as
## a sweep rather than a spinner — this sits behind text people are reading.
const ORBIT_PERIOD := 3.0
## Trail length and sampling step, both in pixels, so the light looks the
## same whatever height the cards happen to give the panel.
const TRAIL_PX := 170.0
const TRAIL_STEP := 8.0

## The sting used to fire on the same frame as the pause, which is the
## busiest frame of the run — the kill that earned the level is still
## ringing. Pausing stops any new combat sound from starting, so the mix
## clears itself in about this long; waiting buys the sting a quiet room
## to land in, which is worth more than volume ever was.
const STING_DELAY := 0.15

var _title: Label
var _buttons_box: VBoxContainer
var _panel: PanelContainer

var _orbit: Control
var _orbit_glow: GradientTexture2D
var _orbit_phase := 0.0
var _orbit_accent := TOWER_ACCENT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style(TOWER_ACCENT))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 8)
	_buttons_box.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	vbox.add_child(_buttons_box)

	# Added last so it draws over the panel border it runs along, and set to
	# ignore the mouse so it never steals a click from a card underneath.
	_orbit = Control.new()
	_orbit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orbit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orbit.draw.connect(_draw_orbit)
	add_child(_orbit)
	# Built once: radial() allocates a Gradient and a texture, which is not
	# something to do every frame.
	_orbit_glow = GlowTexture.radial(64, 0.28, 0.45)
	set_process(false)

func _process(delta: float) -> void:
	_orbit_phase = fposmod(_orbit_phase + delta / ORBIT_PERIOD, 1.0)
	_orbit.queue_redraw()

func offer(options: Array[Dictionary], title: String = "LEVEL UP — choose one") -> void:
	var accent := SQUAD_ACCENT if title.contains("squad") else TOWER_ACCENT
	_title.text = title
	_title.add_theme_color_override("font_color", Palette.neon(accent, 1.15))
	_panel.add_theme_stylebox_override("panel", _panel_style(accent))
	for child in _buttons_box.get_children():
		child.queue_free()
	for opt in options:
		_buttons_box.add_child(_make_card(opt, accent))
	# Restarting the lap from the panel's top-left corner makes the reveal
	# read as deliberate instead of catching a loop already in progress.
	_orbit_accent = accent
	_orbit_phase = 0.0
	set_process(true)
	visible = true
	get_tree().paused = true
	# SceneTreeTimer processes while paused by default, which is the whole
	# reason this works. The visible check covers a player who picks inside
	# the delay — without it the sting lands in resumed combat, which is
	# the exact thing the delay exists to avoid.
	get_tree().create_timer(STING_DELAY).timeout.connect(
			func() -> void:
				if visible:
					Sfx.play(&"level", 1.0, -9.0))
	# Let a keyboard or gamepad player commit without reaching for the
	# mouse; the first card is focused as soon as the box lays out.
	if not _buttons_box.get_children().is_empty():
		_buttons_box.get_child(0).call_deferred("grab_focus")

func _make_card(opt: Dictionary, accent: Color) -> Button:
	var card := Button.new()
	card.text = "%s\n%s" % [String(opt.title).to_upper(), opt.desc]
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override("font_size", 14)
	card.add_theme_color_override("font_color", Color(0.80, 0.90, 0.98))
	card.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	card.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	card.add_theme_stylebox_override("normal", _card_style(accent, 0.16, 0.0))
	card.add_theme_stylebox_override("hover", _card_style(accent, 0.30, 0.9))
	card.add_theme_stylebox_override("focus", _card_style(accent, 0.30, 0.9))
	card.add_theme_stylebox_override("pressed", _card_style(accent, 0.55, 1.4))
	card.pressed.connect(_on_pick.bind(opt))
	return card

## Cards are dark plates with a thick accent stripe down the left edge —
## the stripe is what makes a row read as a choice rather than a label.
func _card_style(accent: Color, accent_alpha: float, glow: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.045, 0.06, 0.10, 0.95)
	box.border_color = Palette.fade(accent, accent_alpha) if glow <= 0.0 \
			else Palette.neon(accent, glow)
	box.border_width_left = 4
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(2)
	box.content_margin_left = 16
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _panel_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.028, 0.055, 0.96)
	box.border_color = Palette.fade(accent, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 16
	box.content_margin_bottom = 18
	return box

## A light running the panel's edge. The screen stops the game dead, so the
## one thing still moving on it should be the thing the player is meant to
## be reading. Glow is free here — bloom is on and covers CanvasLayers, so
## anything past 1.0 bleeds without a shader.
func _draw_orbit() -> void:
	# The panel is in a CenterContainer and resizes with the card text, so
	# its rect only means anything after a layout pass — read it per frame.
	var rect := _panel.get_global_rect().grow(1.0)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var to_local := _orbit.get_global_transform().affine_inverse()
	# Stepping by pixels rather than by a fixed segment count keeps the trail
	# the same length whatever size the panel is, and bounds the corner a
	# segment cuts to TRAIL_STEP — invisible under a 2px line and bloom.
	var step := TRAIL_STEP / (2.0 * (rect.size.x + rect.size.y))
	var segments := int(TRAIL_PX / TRAIL_STEP)
	# Tail first, so each brighter segment overlaps the dimmer one behind it.
	for i in range(segments, 0, -1):
		var f := float(i) / float(segments)
		var falloff := (1.0 - f) * (1.0 - f)
		var a := to_local * _perimeter(rect, _orbit_phase - step * float(i))
		var b := to_local * _perimeter(rect, _orbit_phase - step * float(i - 1))
		# Alpha falls off with brightness: a dim opaque line would paint over
		# the panel's own border and trail a dark gap behind the light.
		var tint := Palette.neon(_orbit_accent, 0.35 + 1.9 * falloff)
		_orbit.draw_line(a, b, Palette.fade(tint, falloff), 2.0, true)
	var head := to_local * _perimeter(rect, _orbit_phase)
	_orbit.draw_texture_rect(_orbit_glow,
			Rect2(head - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), false,
			Palette.fade(_orbit_accent, 0.5))
	_orbit.draw_circle(head, 2.5, Palette.neon(_orbit_accent, 3.0))

## Maps u onto the rect's perimeter, clockwise from the top-left corner.
func _perimeter(rect: Rect2, u: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var d := fposmod(u, 1.0) * 2.0 * (w + h)
	if d < w:
		return rect.position + Vector2(d, 0.0)
	d -= w
	if d < h:
		return rect.position + Vector2(w, d)
	d -= h
	if d < w:
		return rect.position + Vector2(w - d, h)
	return rect.position + Vector2(0.0, h - (d - w))

func _on_pick(opt: Dictionary) -> void:
	opt.apply.call()
	set_process(false)
	visible = false
	get_tree().paused = false
	choice_made.emit()
