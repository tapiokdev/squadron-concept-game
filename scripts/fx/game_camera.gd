class_name GameCamera
extends Camera2D

## Screen shake, and nothing else — the tower never moves, so the camera
## parks on the centre of the play area for the whole run.
##
## Trauma decays linearly but displacement scales with its square, so a
## swarmer chipping the hull barely registers while a meteor really
## lands. Offsets come from noise rather than `randf()` so the shake
## reads as motion instead of per-frame buzz.

const MAX_OFFSET := Vector2(16.0, 11.0)
const MAX_ROLL := 0.022
const DECAY := 1.7
## How fast the shake walks through the noise field.
const SHAKE_SPEED := 220.0

static var instance: GameCamera

var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()

## Adds trauma; 0.2 is a hull hit, 0.6 is a meteor. Saturates at 1.0, so
## a swarm landing at once shakes hard but never turns into a blender.
static func shake(amount: float) -> void:
	if instance != null:
		instance.add_trauma(amount)

func _ready() -> void:
	instance = self
	_noise.frequency = 0.08
	_noise.seed = 7
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_recenter()
	make_current()
	get_viewport().size_changed.connect(_recenter)

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Play space is viewport space with the tower in the middle, so parking
## the camera on the centre leaves world and screen coordinates identical.
func _recenter() -> void:
	position = get_viewport_rect().size * 0.5

func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if offset != Vector2.ZERO or rotation != 0.0:
			offset = Vector2.ZERO
			rotation = 0.0
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	_time += delta * SHAKE_SPEED
	var power := _trauma * _trauma
	offset = Vector2(
		MAX_OFFSET.x * power * _noise.get_noise_2d(_time, 0.0),
		MAX_OFFSET.y * power * _noise.get_noise_2d(0.0, _time),
	)
	rotation = MAX_ROLL * power * _noise.get_noise_2d(_time, _time)
