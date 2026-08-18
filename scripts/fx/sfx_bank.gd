class_name SfxBank
extends RefCounted

## Synthesises the game's entire sound set at load. There are no audio
## assets here for the same reason there are no sprites — nothing has to
## be sourced, licensed, or shipped, and the whole palette stays tunable
## as numbers in this file.
##
## Everything is 16-bit mono at 22 kHz. These are short, mostly noisy
## sounds with little above a few kHz, so a higher rate buys nothing
## audible, and the bank totals under three seconds of audio, which keeps
## both the web download and the one-time generation cost small.
##
## Noise uses a fixed seed so the bank is identical every run — a death
## pop that is subtly different each launch reads as a glitch.

const RATE := 22050
const NOISE_SEED := 5150
## One-pole lowpass coefficient; raw white noise is too hissy to sit
## under the neon look.
const NOISE_SMOOTH := 0.35

static func build_all() -> Dictionary:
	return {
		&"bolt": _bolt(),
		&"pulse": _pulse(),
		&"meteor": _meteor(),
		&"kill": _kill(),
		&"hull": _hull(),
		&"level": _level(),
		&"summon": _summon(),
	}

## A soft thunk, not a zap. This fires every 0.7s from the first second of
## a run to the last — several hundred times — so it carries no square edge
## and almost no top end. The bolt you can see is the real feedback; this
## only has to say the tower is still working.
static func _bolt() -> AudioStreamWAV:
	var count := int(RATE * 0.07)
	var out := _buffer(count)
	var rng := _rng(7)
	var phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		# sqrt() lands on the low note within a few ms, so the drop reads as
		# a transient rather than a sweep you can follow down.
		phase += TAU * lerpf(430.0, 150.0, sqrt(t)) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		# The 1.5ms ramp is there to kill the DC-step pop and nothing else —
		# too short to soften the attack, because a thunk needs its click.
		out[i] = (sin(phase) * 0.5 * exp(-17.0 * t)
				+ smoothed * 0.10 * exp(-48.0 * t)) * minf(t / 0.0015, 1.0)
	return _pcm(out)

## Capacitor dump: a low sweep with an audible swell rather than a click,
## so it reads as a discharge building and releasing.
static func _pulse() -> AudioStreamWAV:
	var count := int(RATE * 0.45)
	var out := _buffer(count)
	var rng := _rng()
	var phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(215.0, 68.0, t) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		var env := minf(t / 0.09, 1.0) * exp(-3.4 * t)
		out[i] = (sin(phase) * 0.55 + smoothed * 0.14) * env
	return _pcm(out)

## Orbital strike: a sharp crack over a long low boom.
static func _meteor() -> AudioStreamWAV:
	var count := int(RATE * 0.75)
	var out := _buffer(count)
	var rng := _rng()
	var phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(125.0, 30.0, sqrt(t)) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		out[i] = sin(phase) * 0.62 * exp(-3.0 * t) + smoothed * 0.38 * exp(-8.5 * t)
	return _pcm(out)

## Short bright pop. Callers pitch it by hull size, so one sample covers
## a swarmer and a broodmother.
static func _kill() -> AudioStreamWAV:
	var count := int(RATE * 0.12)
	var out := _buffer(count)
	var rng := _rng()
	var phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(880.0, 200.0, t) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		out[i] = (sin(phase) * 0.35 + smoothed * 0.5) * exp(-15.0 * t) * 0.55
	return _pcm(out)

## Something hitting the hull: hard attack, low body, gone quickly.
static func _hull() -> AudioStreamWAV:
	var count := int(RATE * 0.20)
	var out := _buffer(count)
	var rng := _rng()
	var phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(240.0, 58.0, sqrt(t)) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		out[i] = sin(phase) * 0.6 * exp(-9.0 * t) + smoothed * 0.22 * exp(-24.0 * t)
	return _pcm(out)

## A near tick over distant thunder. The roll on its own kept getting lost:
## it is all bottom end under a soft attack, which is the exact shape a busy
## mix swallows and a laptop speaker cannot reproduce. The tick is not a
## thunder crack — it is the panel answering, a near sound over a far one.
## It sits mid-band because everything else in the bank is low or noisy, so
## 1.4kHz is empty air; the ear finds it without the sound getting louder.
static func _level() -> AudioStreamWAV:
	var count := int(RATE * 0.90)
	var out := _buffer(count)
	var rng := _rng(31)
	var phase := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	for i in count:
		var t := float(i) / float(count)
		var time := float(i) / float(RATE)
		# Two poles, not the usual one: a single NOISE_SMOOTH pass still
		# hisses enough to read as static rather than weather. Cascading
		# costs most of the amplitude, hence the makeup gain below.
		lp1 = lerpf(lp1, rng.randf_range(-1.0, 1.0), 0.10)
		lp2 = lerpf(lp2, lp1, 0.10)
		phase += TAU * lerpf(90.0, 45.0, sqrt(t)) / RATE
		# Two incommensurate wobbles, so the roll never settles into a beat.
		var roll := 0.62 + 0.26 * sin(TAU * 3.1 * time) + 0.12 * sin(TAU * 1.7 * time)
		var env := minf(t / 0.022, 1.0) * exp(-3.2 * t)
		# Decays in absolute seconds, not run-length, so the tick stays a tick
		# if the roll is ever retuned longer. The 0.6ms ramp only kills the
		# DC-step pop — any softer and it stops being an attack.
		var tick := sin(TAU * 1400.0 * time) * exp(-42.0 * time) \
				* minf(time / 0.0006, 1.0) * 0.16
		# The sine is weight for headphones, not the sound — laptop speakers
		# reproduce nothing down there, so the filtered noise has to carry it.
		out[i] = (lp2 * 2.5 + sin(phase) * 0.22) * roll * env + tick
	return _pcm(out)

## Rising chirp for a unit arriving on station.
static func _summon() -> AudioStreamWAV:
	var count := int(RATE * 0.22)
	var out := _buffer(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(320.0, 900.0, t * t) / RATE
		out[i] = sin(phase) * exp(-5.0 * t) * minf(t / 0.03, 1.0) * 0.42
	return _pcm(out)

static func _buffer(count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	return out

## `offset` gives a generator its own noise sequence. Sounds that share a
## seed also share their noise, which is fine for short pops but not for
## the two long ones: thunder and a meteor overlapping would otherwise read
## as a single doubled sound rather than two events.
static func _rng(offset: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED + offset
	return rng

static func _pcm(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream
