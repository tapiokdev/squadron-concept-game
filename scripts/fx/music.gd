class_name Music
extends Node

## Background music: one looping underscore, started by the player's first
## click rather than at load.
##
## The click is the point. A browser will not resume its audio context until
## the page has had a real user gesture, so a track started in _ready() on the
## web plays into a suspended context and is either lost or picked up
## mid-phrase whenever the context finally wakes. StartScreen already exists
## to collect that gesture for the SFX bank; the music rides the same one.
##
## Reached statically like Sfx and FxLayer, and for the same reason: the one
## caller shouldn't have to be wired to something this peripheral, and the
## entry point no-ops when nothing is in the tree.

const TRACK := preload("res://audio/cyberwave_underscore_300694.mp3")

## Sits under a bank whose loudest cue plays at -9 dB. Music needs more room
## than that number suggests, because those are transients and this is
## continuous — a level that matches them in peak buries them in average.
## A listening call, not a derived one.
const VOLUME_DB := -21.0
## Floor of the fade. Below roughly -50 dB nothing is audible anyway, so this
## is silence for practical purposes without the special case that an actual
## -inf would need.
const SILENT_DB := -60.0
## Long enough not to read as a cut, short enough that the opening seconds of
## a run are not played over nothing.
const FADE_IN := 1.6

static var instance: Music

var _player: AudioStreamPlayer
var _fade := 0.0

static func start() -> void:
	if instance != null:
		instance._start()

func _ready() -> void:
	instance = self
	# The level-up screen pauses the tree, and music that stops dead every
	# time the player takes a pick is worse than no music at all.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = TRACK
	_player.volume_db = SILENT_DB
	add_child(_player)
	# Nothing to advance until the fade is running.
	set_process(false)

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Idempotent: a restart reloads the scene, so this node and its start screen
## are both new, but a stray second call within one run must not restart the
## track from the top.
func _start() -> void:
	if _player.playing:
		return
	_fade = 0.0
	_player.volume_db = SILENT_DB
	_player.play()
	set_process(true)

func _process(delta: float) -> void:
	_fade = minf(_fade + delta / FADE_IN, 1.0)
	# Interpolating in dB rather than amplitude: dB is roughly how the ear
	# measures loudness, so this reads as an even swell where a linear ramp
	# in amplitude stays inaudible and then arrives all at once near the end.
	_player.volume_db = lerpf(SILENT_DB, VOLUME_DB, _fade)
	if _fade >= 1.0:
		set_process(false)
