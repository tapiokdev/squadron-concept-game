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
@onready var spawner: EnemySpawner = $Spawner
@onready var info_label: Label = $HUD/InfoLabel

var elapsed := 0.0
var run_over := false

func _ready() -> void:
	tower.position = get_viewport_rect().size * 0.5
	tower.died.connect(_end_run.bind(false))
	spawner.setup(enemy_pool, tower)
	bolt.setup(enemy_pool, projectile_pool, tower)
	pulse.setup(enemy_pool, tower)
	meteor.setup(enemy_pool, tower)

func _process(delta: float) -> void:
	if run_over:
		return
	elapsed += delta
	if elapsed >= run_duration:
		_end_run(true)
		return
	var remaining := int(run_duration - elapsed)
	info_label.text = "%d:%02d   HP %d/%d   enemies %d" % [
		int(remaining / 60.0), remaining % 60, roundi(tower.hp), roundi(tower.max_hp),
		enemy_pool.live_count,
	]

func _end_run(won: bool) -> void:
	if run_over:
		return
	run_over = true
	spawner.active = false
	info_label.text = "YOU SURVIVED" if won else "TOWER DESTROYED"
	print("[run] over — %s" % ("won" if won else "lost"))
