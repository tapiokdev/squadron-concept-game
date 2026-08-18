class_name UpgradePool
extends RefCounted

## Builds the level-up offer from current game state. Offers alternate
## between two tracks (squad picks on one parity, tower/weapon picks on
## the other) so the player never has to starve one side to feed the
## other — and the power envelope per level stays predictable for wave
## tuning. POC content only: no raw stat passives.

const BASTION := preload("res://data/drones/bastion.tres")
const LANCER := preload("res://data/drones/lancer.tres")

## Returns {"track": actually-used track, "options": up to `count` picks}.
## options is empty only when both tracks are exhausted.
static func roll(main: Node, track: String, count: int = 3) -> Dictionary:
	var squad_options := _squad_options(main)
	var tower_options := _tower_options(main)
	var options := squad_options if track == "squad" else tower_options
	if options.is_empty():
		# The chosen track ran dry (cap reached / all taken) — offer the
		# other one instead of skipping the level.
		track = "tower" if track == "squad" else "squad"
		options = tower_options if track == "tower" else squad_options
	options.shuffle()
	return {"track": track, "options": options.slice(0, count)}

static func _squad_options(main: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if main.squad.total_units() < DroneSquad.MAX_UNITS:
		options.append({
			"id": "add_bastion",
			"title": "Deploy Bastion",
			"desc": "Heavy drone holds the line (redeploy grows per copy)",
			"apply": func() -> void: main.squad.try_add_drone(BASTION),
		})
		options.append({
			"id": "add_lancer",
			"title": "Deploy Lancer",
			"desc": "Standoff drone, fires at range (redeploy grows per copy)",
			"apply": func() -> void: main.squad.try_add_drone(LANCER),
		})
	return options

static func _tower_options(main: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not main.pulse.enabled:
		options.append({
			"id": "unlock_pulse",
			"title": "New weapon: Pulse",
			"desc": "AoE burst around the tower — answers swarms",
			"apply": func() -> void: main.pulse.enabled = true,
		})
	elif main.pulse_tier < 2:
		options.append({
			"id": "pulse_boost",
			"title": "Pulse: wider & faster %s" % ["I", "II"][main.pulse_tier],
			"desc": "+25% radius, fires 20% more often",
			"apply": func() -> void:
				main.pulse_tier += 1
				main.pulse.radius *= 1.25
				main.pulse.cooldown *= 0.8,
		})
	if main.rail.spread_count == 1:
		options.append({
			"id": "rail_spread",
			"title": "Rail: triple spread",
			"desc": "Rail fires a spread of 3 shots",
			"apply": func() -> void: main.rail.spread_count = 3,
		})
	if main.rail.pierce == 0:
		options.append({
			"id": "rail_pierce",
			"title": "Rail: piercing shots",
			"desc": "Rail shots pass through one extra hostile",
			"apply": func() -> void: main.rail.pierce = 1,
		})
	if not main.barrage.aftershock:
		options.append({
			"id": "barrage_aftershock",
			"title": "Barrage: aftershock",
			"desc": "Impacts echo once for 50% damage",
			"apply": func() -> void: main.barrage.aftershock = true,
		})
	# Repeatable fallback so late level-ups stay meaningful after the
	# real upgrades run out; only offered when actually damaged.
	if main.tower.hp < main.tower.max_hp:
		options.append({
			"id": "emergency_repairs",
			"title": "Emergency repairs",
			"desc": "Restore 25 tower HP",
			"apply": func() -> void: main.tower.heal(25.0),
		})
	return options
