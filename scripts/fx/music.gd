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
## Reached statically like Sfx and FxLayer, and for the same reason: callers
## shouldn't have to be wired to something this peripheral, and the entry
## points no-op when nothing is in the tree.
##
## The track plays on its own bus, so a level-up can duck it and squeeze it
## into a comms band without touching the SFX, which stay on Master.

const TRACK := preload("res://audio/cyberwave_underscore_300694.mp3")

const BUS_NAME := &"Music"

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

## Depth of the level-up duck, relative to VOLUME_DB so that retuning the
## master level carries the duck with it instead of silently changing how far
## down it goes.
const DUCK_DB := -3.0
## Lands just inside the level-up screen's own STING_DELAY of 0.15s, so the
## sting arrives over music that has already got out of the way rather than
## one still moving.
const DUCK_TIME := 0.14
## The band deliberately takes longer than the level does. Getting out of
## the way wants to be quick; closing a band onto a signal wants to be
## heard happening — and the slower sweep keeps each frame's coefficient
## step small enough not to zipper.
const BAND_TIME := 0.30
## Slower coming back than going down, for both. A quick recovery is an event
## in its own right, and the panel closing should not be one.
const RECOVER_TIME := 0.35

## Filter cutoffs, open (transparent) and closed onto the comms band. The
## effects stay enabled at the open values rather than being switched in:
## toggling a filter mid-playback swaps the processing on a buffer boundary
## and can click, where sweeping a cutoff cannot — and a band closing in
## reads as tuning into a channel, which is the whole idea.
const HIGH_OPEN := 20.0
const HIGH_BAND := 380.0
const LOW_OPEN := 20500.0
const LOW_BAND := 2900.0

static var instance: Music

var _player: AudioStreamPlayer
var _high: AudioEffectFilter
var _low: AudioEffectFilter

## Current level and where it is heading, in dB, plus the rate that gets it
## there. One driver serves the opening fade, the duck and the recovery —
## they differ only in target and speed.
var _db := SILENT_DB
var _db_target := SILENT_DB
var _db_rate := 0.0

## 0 = filters transparent, 1 = full comms band. Same three-field shape as
## the volume, advanced by the same _process.
var _band := 0.0
var _band_target := 0.0
var _band_rate := 0.0

static func start() -> void:
	if instance != null:
		instance._start()

## Called as the level-up screen opens and closes. Static rather than a wired
## signal, matching Sfx.play(): the screen should not have to know this node
## exists beyond its name.
static func duck() -> void:
	if instance != null:
		instance._set_ducked(true)

static func unduck() -> void:
	if instance != null:
		instance._set_ducked(false)

func _ready() -> void:
	instance = self
	# The level-up screen pauses the tree, and music that stops dead every
	# time the player takes a pick is worse than no music at all.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	# A restart reloads the scene but not the AudioServer, so the filters can
	# still be sitting wherever the last run left them. Without this reset, a
	# restart from inside a level-up leaves the music band-limited for good.
	_band = 0.0
	_band_target = 0.0
	_apply_band()
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = TRACK
	_player.volume_db = SILENT_DB
	# Set after _ensure_bus, since naming a bus that does not exist yet warns
	# and silently falls back to Master.
	_player.bus = BUS_NAME
	add_child(_player)
	# Nothing to advance until a transition is running.
	set_process(false)

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Built here rather than shipped as a default_bus_layout.tres: the project
## has no audio assets by design, and these two filters exist only to serve
## this one node.
func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx != -1:
		# AudioServer is not part of the tree, so a scene reload finds the
		# bus from the previous run still standing. Adopt it — adding another
		# would stack a duplicate on every restart.
		_high = AudioServer.get_bus_effect(idx, 0) as AudioEffectFilter
		_low = AudioServer.get_bus_effect(idx, 1) as AudioEffectFilter
		return
	idx = AudioServer.get_bus_count()
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
	# Order matters only in that _ensure_bus reads them back by index above.
	_high = AudioEffectHighPassFilter.new()
	_high.cutoff_hz = HIGH_OPEN
	_high.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(idx, _high)
	_low = AudioEffectLowPassFilter.new()
	_low.cutoff_hz = LOW_OPEN
	_low.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(idx, _low)

## Idempotent: a restart reloads the scene, so this node and its start screen
## are both new, but a stray second call within one run must not restart the
## track from the top.
func _start() -> void:
	if _player.playing:
		return
	_db = SILENT_DB
	_player.volume_db = _db
	_player.play()
	_to_db(VOLUME_DB, FADE_IN)

func _set_ducked(on: bool) -> void:
	_band_target = 1.0 if on else 0.0
	_band_rate = 1.0 / (BAND_TIME if on else RECOVER_TIME)
	# The volume is left alone until the track is actually running, or a
	# level-up before the first click would fade an unstarted stream up off
	# the silent floor.
	if _player.playing:
		_to_db(VOLUME_DB + (DUCK_DB if on else 0.0),
			DUCK_TIME if on else RECOVER_TIME)
	set_process(true)

## Retargets from wherever the level currently is, so a transition that
## interrupts another still takes the time it asked for.
func _to_db(target: float, seconds: float) -> void:
	_db_target = target
	_db_rate = absf(target - _db) / maxf(seconds, 0.001)
	set_process(true)

func _process(delta: float) -> void:
	# Moving in dB rather than amplitude: dB is roughly how the ear measures
	# loudness, so this reads as an even ramp where a linear one in amplitude
	# stays inaudible and then arrives all at once near the end.
	_db = move_toward(_db, _db_target, _db_rate * delta)
	_player.volume_db = _db
	if not is_equal_approx(_band, _band_target):
		_band = move_toward(_band, _band_target, _band_rate * delta)
		_apply_band()
	if is_equal_approx(_db, _db_target) and is_equal_approx(_band, _band_target):
		set_process(false)

## Geometric rather than linear, because frequency is perceived in ratios:
## this moves each cutoff a constant number of octaves per unit of _band. A
## linear sweep of the low-pass would spend nearly all its travel above
## hearing and then fall through the audible range in the last instant.
func _apply_band() -> void:
	_high.cutoff_hz = HIGH_OPEN * pow(HIGH_BAND / HIGH_OPEN, _band)
	_low.cutoff_hz = LOW_OPEN * pow(LOW_BAND / LOW_OPEN, _band)
