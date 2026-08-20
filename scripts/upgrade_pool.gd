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

const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## Label for the stack a repeatable pick is about to add. Unlike the
## one-time tiers these have no ceiling — a long run can stack past X — so
## this falls back to a count instead of indexing off the end.
static func _stack_label(taken: int) -> String:
	return NUMERALS[taken] if taken < NUMERALS.size() else "x%d" % (taken + 1)

## The flat damage picks the POC deliberately did without. They are allowed
## in only where the alternative is worse: past exhaustion the choice is not
## "interesting pick vs boring pick", it is "boring pick vs nothing at all",
## and the run currently answers that with nothing while enemy HP keeps
## scaling. Tower weapons only — their damage is a plain node property,
## whereas DroneDef is a shared preloaded resource and buffing a drone would
## mutate the .tres for the whole editor session rather than this run.
static func _sustain_options(main: Node) -> Array[Dictionary]:
	return [
		{
			"id": "rail_power",
			"title": "Rail: overcharge %s" % _stack_label(main.rail_power),
			"desc": "+5 Rail damage per shot",
			"apply": func() -> void:
				main.rail_power += 1
				main.rail.damage += 5.0,
		},
		{
			"id": "pulse_power",
			"title": "Pulse: amplitude %s" % _stack_label(main.pulse_power),
			"desc": "+3 Pulse damage per burst",
			"apply": func() -> void:
				main.pulse_power += 1
				main.pulse.damage += 3.0,
		},
		{
			"id": "barrage_power",
			"title": "Barrage: heavier payload %s" % _stack_label(main.barrage_power),
			"desc": "+25 Barrage impact damage",
			"apply": func() -> void:
				main.barrage_power += 1
				main.barrage.damage += 25.0,
		},
	]

static func _tower_options(main: Node) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not main.pulse.enabled:
		options.append({
			"id": "unlock_pulse",
			"title": "New weapon: Pulse",
			"desc": "AoE burst around the mothership — answers swarms",
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
	# An empty list here is the gate: every behaviour upgrade is taken, which
	# by the XP curve happens around 4:49 — eleven seconds before the Carrier,
	# with three minutes of climbing enemy HP still to come. Without these the
	# remaining level-ups of the run are discarded outright.
	#
	# It also means Pulse is unlocked, since unlock_pulse is offered for as
	# long as it is not, so the Pulse pick below needs no guard of its own.
	if options.is_empty():
		options.append_array(_sustain_options(main))
	# Heals sit alongside whatever else is on offer, not only at the end;
	# only offered when actually damaged.
	if main.tower.hp < main.tower.max_hp:
		options.append({
			"id": "emergency_repairs",
			"title": "Emergency repairs",
			"desc": "Restore 25 mothership HP",
			"apply": func() -> void: main.tower.heal(25.0),
		})
	return options
