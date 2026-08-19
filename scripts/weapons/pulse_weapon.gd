class_name PulseWeapon
extends Node2D

## Pulse: AoE burst around the tower, the answer to swarms. Not part of
## the starting kit — the Phase 5 upgrade screen offers it, so it ships
## disabled. Behaviour upgrades later just raise radius / lower cooldown.

const Palette = preload("res://scripts/fx/palette.gd")

@export var enabled := false
@export var damage := 7.0
@export var cooldown := 2.2
@export var radius := 150.0

const FLASH_TIME := 0.25
## Enemies caught in one burst for it to play at full level.
const FULL_VOICE_HITS := 6

var _enemies: EnemyPool
var _tower: Tower
var _cd := 0.0
var _flash := 0.0

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()
	if not enabled or _tower == null or not _tower.alive:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _cd > 0.0:
		return
	var hits := 0
	# Iterate a copy: take_damage can kill and mutate the live list.
	for enemy in _enemies.live.duplicate():
		if _tower.position.distance_to(enemy.global_position) <= radius + enemy.def.radius:
			enemy.take_damage(damage)
			hits += 1
	if hits > 0:
		_cd = cooldown
		_flash = FLASH_TIME
		# The wave travelling outward is what sells this as a discharge;
		# a ring that simply appears at full size reads as a UI overlay.
		FxLayer.ring(_tower.position, Palette.PULSE, radius * 0.2, radius, FLASH_TIME, 4.0)
		FxLayer.flash(_tower.position, Palette.PULSE, radius * 0.35, 0.16)
		GameCamera.shake(0.14)
		# Late in a run this fires every 1.4s, so the two things that made it
		# fatiguing were uniformity and repetition rather than level. Pitch
		# jitter is what the Rail already uses to stop reading as a machine;
		# scaling by hit count means clipping one straggler is a murmur and
		# only wiping a cluster is the full sound, which also drops the
		# average because most bursts are small.
		var weight := clampf(float(hits) / float(FULL_VOICE_HITS), 0.0, 1.0)
		Sfx.play(&"pulse", randf_range(0.94, 1.08), lerpf(-16.0, -9.0, weight))
		queue_redraw()

## The expanding wave is an FX-layer ring; this is just the residual wash
## of light inside it while the capacitor dumps.
func _draw() -> void:
	if _flash <= 0.0:
		return
	var alpha := _flash / FLASH_TIME
	draw_circle(Vector2.ZERO, radius, Palette.fade(Palette.PULSE, alpha * 0.12))
