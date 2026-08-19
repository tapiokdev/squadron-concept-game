class_name Sfx
extends Node

## Sound playback service. Owns a fixed set of voices and round-robins
## them, so a busy frame can never spawn players without bound.
##
## Reached statically for the same reason as FxLayer: the callers are
## pooled enemies and weapons that shouldn't need wiring for something
## cosmetic, and the entry point no-ops when nothing is in the tree.

const SfxBank = preload("res://scripts/fx/sfx_bank.gd")

const VOICES := 12

## Floor between repeats of the same sound. A swarm wiping out fires
## dozens of kills in one frame; without this it is a wall of noise and
## every voice is spent on the same pop.
const MIN_GAP := {
	&"kill": 0.045,
	&"hull": 0.06,
	&"rail": 0.05,
}

static var instance: Sfx

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}

static func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if instance != null:
		instance._play(id, pitch, volume_db)

func _ready() -> void:
	instance = self
	# The level-up screen pauses the tree and still needs its roll.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bank = SfxBank.build_all()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _play(id: StringName, pitch: float, volume_db: float) -> void:
	var stream: AudioStreamWAV = _bank.get(id)
	if stream == null:
		return
	# Wall-clock, so the floor holds under pause and slow motion alike.
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = MIN_GAP.get(id, 0.0)
	if gap > 0.0 and now - float(_last.get(id, -99.0)) < gap:
		return
	_last[id] = now
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
