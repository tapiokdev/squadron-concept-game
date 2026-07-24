class_name LevelUpScreen
extends CanvasLayer

## Choose-one-of-three level-up screen. Pauses the tree while open;
## this layer runs PROCESS_MODE_ALWAYS so the buttons stay clickable.
## UI is code-built — placeholder until the art pass.

signal choice_made

var _buttons_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "LEVEL UP — choose one"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 6)
	_buttons_box.custom_minimum_size = Vector2(420, 0)
	vbox.add_child(_buttons_box)

func offer(options: Array[Dictionary]) -> void:
	for child in _buttons_box.get_children():
		child.queue_free()
	for opt in options:
		var button := Button.new()
		button.text = "%s\n%s" % [opt.title, opt.desc]
		button.pressed.connect(_on_pick.bind(opt))
		_buttons_box.add_child(button)
	visible = true
	get_tree().paused = true

func _on_pick(opt: Dictionary) -> void:
	opt.apply.call()
	visible = false
	get_tree().paused = false
	choice_made.emit()
