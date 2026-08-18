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
		&"rail": _rail(),
		&"pulse": _pulse(),
		&"barrage": _barrage(),
		&"kill": _kill(),
		&"hull": _hull(),
		&"level": _level(),
		&"deploy": _deploy(),
	}

## A blaster, not a knock. The earlier version swept 430->150Hz, which is
## acoustically a thud — it was built as a crossbow bolt and still read as
## one. A weapon's sci-fi signature lives at 1-3kHz, but this fires every
## 0.7s from the first second of a run to the last, so it cannot simply move
## up there and get bright.
##
## So it splits, the same way the level-up sting does: the body stays low
## where it carries weight without fatiguing, and a brief zip on top does
## the identifying. The ear is 15-20dB more sensitive at 1-2kHz than in the
## bass, which is why the zip's amplitude can be a third of the body's and
## still be the part you notice.
static func _rail() -> AudioStreamWAV:
	var count := int(RATE * 0.07)
	var out := _buffer(count)
	var rng := _rng(7)
	var body_phase := 0.0
	var zip_phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		var time := float(i) / float(RATE)
		# sqrt() lands on the low note within a few ms, so the drop reads as
		# a transient rather than a sweep you can follow down.
		body_phase += TAU * lerpf(300.0, 120.0, sqrt(t)) / RATE
		# Sweep and decay both run on absolute seconds, so this stays a 20ms
		# zip if the sound's overall length is ever retuned.
		zip_phase += TAU * lerpf(1900.0, 800.0, minf(time / 0.020, 1.0)) / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		# The 1.5ms ramp is there to kill the DC-step pop and nothing else —
		# too short to soften the attack, because a shot needs its edge.
		out[i] = (sin(body_phase) * 0.42 * exp(-19.0 * t)
				+ sin(zip_phase) * 0.13 * exp(-90.0 * time)
				+ smoothed * 0.07 * exp(-60.0 * t)) * minf(t / 0.0015, 1.0)
	return _pcm(out)

## Capacitor dump: a low sweep with an audible swell rather than a click,
## so it reads as a discharge building and releasing. The swell is the right
## gesture and is kept.
##
## It used to bottom out at 68Hz, which is below what a laptop speaker
## reproduces at all — so on the hardware this actually ships to, the AoE
## burst was very nearly silent. Raised to sit where it can be heard.
static func _pulse() -> AudioStreamWAV:
	var count := int(RATE * 0.45)
	var out := _buffer(count)
	var rng := _rng()
	var phase := 0.0
	var ring_phase := 0.0
	var smoothed := 0.0
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(330.0, 130.0, t)
		phase += TAU * freq / RATE
		# 2.4x, deliberately not a whole number: an integer ratio is a
		# harmonic and would only thicken the note, where an irrational one
		# beats against it and reads as metal.
		ring_phase += TAU * freq * 2.4 / RATE
		smoothed = lerpf(smoothed, rng.randf_range(-1.0, 1.0), NOISE_SMOOTH)
		var env := minf(t / 0.09, 1.0) * exp(-3.4 * t)
		out[i] = (sin(phase) * 0.5 + sin(ring_phase) * 0.16 + smoothed * 0.12) * env
	return _pcm(out)

## Orbital strike: a sharp crack over a long low boom.
static func _barrage() -> AudioStreamWAV:
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
## a swarmer and a carrier.
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
static func _deploy() -> AudioStreamWAV:
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
## the two long ones: thunder and a barrage overlapping would otherwise read
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
