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

## Flip to true to have the audio layer report itself. print() reaches the
## browser console in a web build, which is the only window into what audio is
## doing there — the editor cannot show it, and the failure this caught (see
## _bind_bus) was invisible from anywhere else. Kept rather than deleted
## because the next web audio problem will need exactly this again.
const DIAG := false

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
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = TRACK
	_player.volume_db = SILENT_DB
	add_child(_player)
	_bind_bus()
	# AudioServer is not part of the tree, so a scene reload finds the filters
	# still sitting wherever the last run left them. Without this reset, a
	# restart from inside a level-up leaves the music band-limited for good.
	_band = 0.0
	_band_target = 0.0
	_apply_band()
	if DIAG:
		print("[audio] driver=%s rate=%d buses=%d music_bus=%d master_mute=%s master_db=%.1f" % [
			AudioServer.get_driver_name(), AudioServer.get_mix_rate(),
			AudioServer.get_bus_count(), AudioServer.get_bus_index(BUS_NAME),
			AudioServer.is_bus_mute(0), AudioServer.get_bus_volume_db(0)])
		print("[audio] track_len=%.1f player_bus=%s filters_bound=%s" % [
			TRACK.get_length(), _player.bus, _high != null])
	# Nothing to advance until a transition is running.
	set_process(false)

func _exit_tree() -> void:
	if instance == self:
		instance = null

## The bus and its two filters come from default_bus_layout.tres, which the
## engine loads before any of this runs.
##
## They used to be built here with AudioServer.add_bus() at _ready time, and
## that shipped a web build with **no audio at all** — SFX included, though
## those were never on this bus. It works perfectly on desktop, so the editor
## could not show it. Mutating the bus graph after the audio driver has
## initialised is evidently a very different proposition on the web backend,
## and when it goes wrong it takes Master down with it.
##
## Declaring the buses in a layout resource means they exist before the driver
## starts, and nothing mutates the graph at runtime. Do not move this back into
## code.
func _bind_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		# Layout missing or failed to load. Stay on Master rather than dying:
		# the duck still works, only the filter sweep is lost.
		push_warning("Music: bus not found in the layout; staying on Master.")
		return
	_high = AudioServer.get_bus_effect(idx, 0) as AudioEffectFilter
	_low = AudioServer.get_bus_effect(idx, 1) as AudioEffectFilter
	_player.bus = BUS_NAME

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
	if DIAG:
		print("[audio] music start: playing=%s db=%.1f" % [_player.playing, _player.volume_db])

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
		if DIAG:
			var hi: float = _high.cutoff_hz if _high != null else -1.0
			var lo: float = _low.cutoff_hz if _low != null else -1.0
			print("[audio] settled db=%.1f band=%.2f hi=%.0f lo=%.0f" % [_db, _band, hi, lo])
		set_process(false)

## Geometric rather than linear, because frequency is perceived in ratios:
## this moves each cutoff a constant number of octaves per unit of _band. A
## linear sweep of the low-pass would spend nearly all its travel above
## hearing and then fall through the audible range in the last instant.
##
## No-ops when the bus was not found, so a missing layout costs the filter
## sweep and nothing else.
func _apply_band() -> void:
	if _high == null or _low == null:
		return
	_high.cutoff_hz = HIGH_OPEN * pow(HIGH_BAND / HIGH_OPEN, _band)
	_low.cutoff_hz = LOW_OPEN * pow(LOW_BAND / LOW_OPEN, _band)
