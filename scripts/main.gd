extends Node2D

## Run controller: wires the systems together and owns the run timer and
## win/lose state. End-of-run UI is a later phase; for now the HUD label
## announces the result.

## Tunable per the brief — 8 min starting point, revisit after playtests.
@export var run_duration := 480.0
## Grace before the first control prompt. Long enough that a player who
## already knows the game never sees it, short enough that one who does not
## is not left watching the tower take hits.
const HINT_DELAY := 4.0
## Safety cap on the mop-up phase. Every enemy paths at the tower, so the
## field converges on its own — a Swarmer crosses from the far edge in about
## 9s, a Dreadnought in 27 — and a live Carrier keeps launching its brood
## regardless. This exists only so a shipped build cannot hang on one
## straggler that somehow never arrives.
const MOP_UP_TIMEOUT := 60.0

@onready var enemy_pool: EnemyPool = $EnemyPool
@onready var projectile_pool: ProjectilePool = $ProjectilePool
@onready var tower: Tower = $Tower
@onready var rail: RailWeapon = $Tower/Rail
@onready var pulse: PulseWeapon = $Tower/Pulse
@onready var barrage: BarrageSkill = $Barrage
@onready var squad: DroneSquad = $Squad

const BASTION := preload("res://data/drones/bastion.tres")
@onready var spawner: EnemySpawner = $Spawner
@onready var hud: Hud = $HUD
@onready var level_up_screen: LevelUpScreen = $LevelUpScreen

var elapsed := 0.0
var run_over := false
## Reaching the timer stops the spawner but does not end the run: the field
## still has to be cleared. The tower stays killable throughout, so the last
## thirty seconds are the run's climax rather than a lap of honour.
var mopping_up := false
var _mop_up_left := 0.0

## XP curve tuned so a meaningful build (both drone types, stacking,
## 1-2 weapon upgrades) is assembled by the ~min 5 elite. Tune freely.
var xp := 0
var level := 1
var pending_levelups := 0
var pulse_tier := 0
## Stacks taken of each repeatable damage pick. Counters rather than
## reading the weapon back, because the card title needs to name the stack
## the player is about to take, not the damage it happens to sit at.
var rail_power := 0
var pulse_power := 0
var barrage_power := 0
var _picks_offered := 0
var _hints_done := false

func xp_to_next() -> int:
	return 15 + (level - 1) * 12

func _ready() -> void:
	tower.position = get_viewport_rect().size * 0.5
	tower.died.connect(_end_run.bind(false))
	enemy_pool.enemy_killed.connect(_on_enemy_killed)
	spawner.setup(enemy_pool, tower)
	rail.setup(enemy_pool, projectile_pool, tower)
	pulse.setup(enemy_pool, tower)
	barrage.setup(enemy_pool, tower)
	squad.setup(enemy_pool, tower)
	enemy_pool.squad = squad
	# Free starting drone so the rally-point mechanic is engaged
	# immediately (brief: first offer drone-only OR free start).
	squad.try_add_drone(BASTION)

func _process(delta: float) -> void:
	if run_over:
		return
	if pending_levelups > 0 and not level_up_screen.visible:
		var track := "squad" if _picks_offered % 2 == 0 else "tower"
		var offer: Dictionary = UpgradePool.roll(self, track)
		if offer.options.is_empty():
			pending_levelups = 0
		else:
			pending_levelups -= 1
			_picks_offered += 1
			var title: String = "LEVEL UP — reinforce your squad" if offer.track == "squad" \
					else "LEVEL UP — upgrade your tower"
			level_up_screen.offer(offer.options, title)
	if mopping_up:
		_mop_up_left -= delta
		if enemy_pool.live_count == 0 or _mop_up_left <= 0.0:
			_end_run(true)
			return
	else:
		elapsed += delta
		if elapsed >= run_duration:
			_begin_mop_up()
	_update_hints()
	hud.update_run(run_duration - elapsed, tower.hp, tower.max_hp,
		level, xp, xp_to_next(), enemy_pool.live_count)

## Opening chain: the squad now starts below the mothership with the first
## lane above it, so a rally order is the run's first real question — but
## nothing on screen says which button gives one. Each prompt appears only
## for a player who has not already done the thing, and the pair never
## returns once both are done, so a second run is never nagged.
##
## Rally comes first because it is the brief's differentiator; the barrage
## follows once the squad is placed, rather than competing for the same
## glance.
func _update_hints() -> void:
	# Outranks the opening chain, which is long finished by the eight-minute
	# mark anyway. The timer reads 0:00 through this phase, so without a line
	# here the run looks won while it is still very much winnable-or-not.
	if mopping_up:
		hud.show_hint("SURVIVE UNTIL THE END")
		return
	if _hints_done:
		return
	if not squad.has_rallied:
		if elapsed >= HINT_DELAY:
			hud.show_hint("RIGHT-CLICK TO RALLY YOUR DRONES")
		return
	if not barrage.has_cast:
		hud.show_hint("LEFT-CLICK TO CALL A BARRAGE")
		return
	_hints_done = true
	hud.hide_hint()

func _on_enemy_killed(amount: int) -> void:
	if run_over:
		return
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_levelups += 1

## The timer running out stops reinforcements, not the fight. Everything
## else keeps going — XP, level-ups, the Barrage recharging — because
## `run_over` stays false; only spawning and the clock stop.
##
## A live Carrier is deliberately left alone. Its brood comes from
## Enemy._process under Behavior.SPAWNER, not from the spawner node, so
## killing the boss becomes the actual finale rather than an optional
## side-task.
func _begin_mop_up() -> void:
	mopping_up = true
	_mop_up_left = MOP_UP_TIMEOUT
	spawner.active = false

func _end_run(won: bool) -> void:
	if run_over:
		return
	run_over = true
	# Captured before clearing: dying with the field uncleared is a different
	# result from being overrun at 6:30, and "survived 8:00 of 8:00" would
	# read as a win.
	var in_mop_up := mopping_up
	mopping_up = false
	spawner.active = false
	hud.hide_hint()
	var survived := int(elapsed)
	var total := int(run_duration)
	# _process bails once the run is over, so push the final numbers in
	# by hand — otherwise the readout freezes on the last frame's values.
	hud.update_run(run_duration - elapsed, tower.hp, tower.max_hp,
		level, xp, xp_to_next(), enemy_pool.live_count)
	if won:
		hud.show_result("YOU SURVIVED\n%d:%02d" % [total / 60, total % 60])
	elif in_mop_up:
		hud.show_result("MOTHERSHIP DESTROYED\nthe last wave got through")
	else:
		hud.show_result("MOTHERSHIP DESTROYED\nsurvived %d:%02d of %d:%02d" % [
			survived / 60, survived % 60, total / 60, total % 60,
		])
	print("[run] over — %s at %ds" % ["won" if won else "lost", survived])
