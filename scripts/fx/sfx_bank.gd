class_name SfxBank
extends RefCounted

## Synthesises the game's entire sound set at load. There are no audio
## assets here for the same reason there are no sprites — nothing has to
## be sourced, licensed, or shipped, and the whole palette stays tunable
## as numbers in this file.
##
## Everything is 16-bit mono at 22 kHz. These are short, bright, mostly
## noisy sounds where a higher rate buys nothing audible, and the bank
## totals well under three seconds of audio, which keeps both the web
## download and the one-time generation cost small.
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

## Descending zap with a square edge for bite, softened by the sine under
## it so a bolt every 0.7s never becomes fatiguing.
static func _bolt() -> AudioStreamWAV:
	var count := int(RATE * 0.10)
	var out := _buffer(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		phase += TAU * lerpf(1500.0, 520.0, t * t) / RATE
		out[i] = (sin(phase) * 0.6 + signf(sin(phase)) * 0.22) * exp(-6.0 * t) * 0.5
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

## Three ascending notes. Constant pitch per note, so the phase can be
## computed directly instead of integrated.
static func _level() -> AudioStreamWAV:
	var count := int(RATE * 0.55)
	var out := _buffer(count)
	var notes := [523.25, 659.25, 880.0]
	var starts := [0.0, 0.10, 0.20]
	for i in count:
		var time := float(i) / float(RATE)
		var sample := 0.0
		for n in notes.size():
			var local: float = time - starts[n]
			if local < 0.0:
				continue
			sample += sin(TAU * float(notes[n]) * local) \
					* exp(-4.5 * local) * minf(local / 0.01, 1.0) * 0.3
		out[i] = sample
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

static func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
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
