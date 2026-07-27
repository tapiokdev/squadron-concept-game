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

var _title: Label
var _buttons_box: VBoxContainer
var _panel: PanelContainer

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

func offer(options: Array[Dictionary], title: String = "LEVEL UP — choose one") -> void:
	var accent := SQUAD_ACCENT if title.contains("squad") else TOWER_ACCENT
	_title.text = title
	_title.add_theme_color_override("font_color", Palette.neon(accent, 1.15))
	_panel.add_theme_stylebox_override("panel", _panel_style(accent))
	for child in _buttons_box.get_children():
		child.queue_free()
	for opt in options:
		_buttons_box.add_child(_make_card(opt, accent))
	visible = true
	get_tree().paused = true
	Sfx.play(&"level", 1.0, -7.0)
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

func _on_pick(opt: Dictionary) -> void:
	opt.apply.call()
	visible = false
	get_tree().paused = false
	choice_made.emit()
