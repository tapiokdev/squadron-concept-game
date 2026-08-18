class_name BarrageSkill
extends Node2D

## LMB active skill: cursor-aimed AoE strike on a long cooldown, the core
## moment-to-moment decision. Tuning intent from the brief: one cast
## clears a single swarmer cluster OR dents one bulwark/elite.
##
## Presented as an orbital strike — a reticle locks onto the marked
## ground while the round falls in from off-screen. The telegraph is not
## just flavour: it is the window in which the player reads whether the
## cast was well aimed, so the marked radius is drawn exactly.

@export var damage := 60.0
@export var radius := 110.0
@export var cooldown := 5.5
## Short telegraph between click and impact so the hit reads on screen.
@export var impact_delay := 0.35
## Behaviour upgrade: the impact echoes once (50% damage, 70% radius).
@export var aftershock := false

const AFTERSHOCK_DELAY := 0.5
## Direction of travel for the incoming round, and how far out it starts.
const ENTRY_DIR := Vector2(0.32, 1.0)
const ENTRY_DISTANCE := 900.0
const STREAK_TAIL := 210.0
const RETICLE_ARCS := 4

var _enemies: EnemyPool
var _tower: Tower
var _cd := 0.0
var _pending_pos := Vector2.ZERO
var _impact_in := -1.0
var _impact_total := 1.0
var _impact_radius := 0.0
var _aftershock_next := false
## Only the first strike has a round falling in; the echo is a ground
## shock, so it gets the reticle but no streak.
var _incoming := false
var _ready_pulse := 0.0
var _entry := ENTRY_DIR.normalized()

func setup(enemies: EnemyPool, tower: Tower) -> void:
	_enemies = enemies
	_tower = tower

func is_ready() -> bool:
	return _cd <= 0.0 and _impact_in < 0.0

func cooldown_fraction() -> float:
	return 1.0 - _cd / cooldown

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_cast(get_global_mouse_position())

func try_cast(pos: Vector2) -> bool:
	if not is_ready():
		return false
	if _tower == null or not _tower.alive:
		return false
	_cd = cooldown
	_pending_pos = pos
	_impact_in = impact_delay
	_impact_total = impact_delay
	_impact_radius = radius
	_aftershock_next = false
	_incoming = true
	return true

func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)
	if _impact_in >= 0.0:
		_impact_in -= delta
		if _impact_in < 0.0:
			_impact()
	_ready_pulse += delta * 3.2
	# The recharge ring breathes while charged, so this node is never
	# idle for long enough to be worth gating the redraw.
	queue_redraw()

func _impact() -> void:
	var mult := 0.5 if _aftershock_next else 1.0
	# Iterate a copy: take_damage can kill and mutate the live list.
	for enemy in _enemies.live.duplicate():
		if _pending_pos.distance_to(enemy.global_position) <= _impact_radius + enemy.def.radius:
			enemy.take_damage(damage * mult)
	FxLayer.flash(_pending_pos, Palette.BARRAGE, _impact_radius * 0.7, 0.18 + 0.2 * mult)
	FxLayer.ring(_pending_pos, Palette.BARRAGE, _impact_radius * 0.25, _impact_radius * 1.3, 0.4, 5.0)
	FxLayer.burst(_pending_pos, Palette.BARRAGE, roundi(24.0 * mult) + 8,
		_impact_radius * 4.0, 0.6)
	GameCamera.shake(0.12 + 0.62 * mult)
	# The echo is the same strike, further away and smaller.
	Sfx.play(&"barrage", 1.0 if mult >= 1.0 else 1.35, -4.0 if mult >= 1.0 else -11.0)
	if aftershock and not _aftershock_next:
		_aftershock_next = true
		_incoming = false
		_impact_radius = radius * 0.7
		_impact_in = AFTERSHOCK_DELAY
		_impact_total = AFTERSHOCK_DELAY

func _draw() -> void:
	_draw_recharge_ring()
	if _impact_in >= 0.0:
		_draw_telegraph()

func _draw_telegraph() -> void:
	var progress := 1.0 - clampf(_impact_in / maxf(_impact_total, 0.0001), 0.0, 1.0)
	# The marked disc is drawn at the true blast radius — this is the
	# player's only chance to judge the aim.
	draw_circle(_pending_pos, _impact_radius, Palette.fade(Palette.BARRAGE, 0.07))
	draw_arc(_pending_pos, _impact_radius, 0.0, TAU, 48, Palette.neon(Palette.BARRAGE, 1.25), 2.0)
	# Brackets close in and rotate as the round comes down, which reads as
	# a lock tightening rather than a static circle.
	var lock := _impact_radius * (1.55 - 0.5 * progress)
	var spin := progress * PI * 0.5
	for i in RETICLE_ARCS:
		var mid := spin + TAU * float(i) / float(RETICLE_ARCS)
		draw_arc(_pending_pos, lock, mid - 0.22, mid + 0.22, 8,
			Palette.hot(Palette.BARRAGE, 1.5), 2.5)
	if _incoming:
		_draw_incoming(progress)

func _draw_incoming(progress: float) -> void:
	var head := _pending_pos - _entry * (ENTRY_DISTANCE * (1.0 - progress))
	draw_line(head - _entry * STREAK_TAIL, head, Palette.fade(Palette.BARRAGE, 0.30), 2.0)
	draw_line(head - _entry * (STREAK_TAIL * 0.3), head, Palette.hot(Palette.BARRAGE, 1.8), 4.0)
	draw_circle(head, 6.0, Palette.hot(Palette.BARRAGE, 2.6))

## The brief requires an always-visible cooldown indicator: a recharge
## ring around the tower that fills clockwise and breathes once charged.
func _draw_recharge_ring() -> void:
	# Nothing left to recharge once the mothership is a wreck.
	if _tower == null or not _tower.alive:
		return
	# Sits in the band the tower reserves for it, clear of the hull
	# integrity ring inside and the shield arcs outside.
	var ring_radius := _tower.radius + 11.0
	if is_ready():
		var beat := 0.5 + 0.5 * sin(_ready_pulse)
		draw_arc(_tower.position, ring_radius, 0.0, TAU, 40,
			Palette.neon(Palette.BARRAGE, 1.1 + 0.35 * beat), 2.5)
		return
	draw_arc(_tower.position, ring_radius, 0.0, TAU, 40, Palette.fade(Palette.BARRAGE, 0.15), 2.5)
	var fraction := cooldown_fraction()
	if fraction > 0.0:
		draw_arc(_tower.position, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * fraction, 40,
			Palette.fade(Palette.neon(Palette.BARRAGE, 1.0), 0.75), 2.5)
