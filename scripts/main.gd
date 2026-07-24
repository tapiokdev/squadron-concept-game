extends Node2D

## Run controller: wires the systems together and owns the run timer and
## win/lose state. End-of-run UI is a later phase; for now the HUD label
## announces the result.

## Tunable per the brief — 8 min starting point, revisit after playtests.
@export var run_duration := 480.0

@onready var enemy_pool: EnemyPool = $EnemyPool
@onready var projectile_pool: ProjectilePool = $ProjectilePool
@onready var tower: Tower = $Tower
@onready var bolt: BoltWeapon = $Tower/Bolt
@onready var pulse: PulseWeapon = $Tower/Pulse
@onready var meteor: MeteorSkill = $Meteor
@onready var squad: SummonSquad = $Squad

const BRUISER := preload("res://data/summons/bruiser.tres")
@onready var spawner: EnemySpawner = $Spawner
@onready var info_label: Label = $HUD/InfoLabel
@onready var level_up_screen: LevelUpScreen = $LevelUpScreen

var elapsed := 0.0
var run_over := false

## XP curve tuned so a meaningful build (both summon types, stacking,
## 1-2 weapon upgrades) is assembled by the ~min 5 elite. Tune freely.
var xp := 0
var level := 1
var pending_levelups := 0
var pulse_boosted := false

func xp_to_next() -> int:
	return 20 + (level - 1) * 15

func _ready() -> void:
	tower.position = get_viewport_rect().size * 0.5
	tower.died.connect(_end_run.bind(false))
	enemy_pool.enemy_killed.connect(_on_enemy_killed)
	spawner.setup(enemy_pool, tower)
	bolt.setup(enemy_pool, projectile_pool, tower)
	pulse.setup(enemy_pool, tower)
	meteor.setup(enemy_pool, tower)
	squad.setup(enemy_pool, tower)
	enemy_pool.squad = squad
	# Free starting summon so the rally-point mechanic is engaged
	# immediately (brief: first offer summon-only OR free start).
	squad.try_add_summon(BRUISER)

func _process(delta: float) -> void:
	if run_over:
		return
	if pending_levelups > 0 and not level_up_screen.visible:
		var options := UpgradePool.roll(self)
		if options.is_empty():
			pending_levelups = 0
		else:
			pending_levelups -= 1
			level_up_screen.offer(options)
	elapsed += delta
	if elapsed >= run_duration:
		_end_run(true)
		return
	var remaining := int(run_duration - elapsed)
	info_label.text = "%d:%02d   HP %d/%d   LV %d  XP %d/%d   enemies %d" % [
		int(remaining / 60.0), remaining % 60, roundi(tower.hp), roundi(tower.max_hp),
		level, xp, xp_to_next(), enemy_pool.live_count,
	]

func _on_enemy_killed(amount: int) -> void:
	if run_over:
		return
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_levelups += 1

func _end_run(won: bool) -> void:
	if run_over:
		return
	run_over = true
	spawner.active = false
	info_label.text = "YOU SURVIVED" if won else "TOWER DESTROYED"
	print("[run] over — %s" % ("won" if won else "lost"))
