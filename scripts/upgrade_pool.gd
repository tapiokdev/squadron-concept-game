class_name UpgradePool
extends RefCounted

## Builds the choose-one-of-three offer from current game state.
## POC content only: summons (repeatable up to the shared cap), the
## Pulse unlock, and behaviour upgrades — no raw stat passives.

const BRUISER := preload("res://data/summons/bruiser.tres")
const ARCHER := preload("res://data/summons/archer.tres")

static func roll(main: Node, count: int = 3) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if main.squad.total_units() < SummonSquad.MAX_UNITS:
		options.append({
			"id": "add_bruiser",
			"title": "Summon Bruiser",
			"desc": "Melee tank joins the squad (respawn grows per copy)",
			"apply": func() -> void: main.squad.try_add_summon(BRUISER),
		})
		options.append({
			"id": "add_archer",
			"title": "Summon Archer",
			"desc": "Long-range shooter joins the squad (respawn grows per copy)",
			"apply": func() -> void: main.squad.try_add_summon(ARCHER),
		})
	if not main.pulse.enabled:
		options.append({
			"id": "unlock_pulse",
			"title": "New weapon: Pulse",
			"desc": "AoE burst around the tower — answers swarms",
			"apply": func() -> void: main.pulse.enabled = true,
		})
	elif not main.pulse_boosted:
		options.append({
			"id": "pulse_boost",
			"title": "Pulse: wider & faster",
			"desc": "+40% radius, fires 30% more often",
			"apply": func() -> void:
				main.pulse_boosted = true
				main.pulse.radius *= 1.4
				main.pulse.cooldown *= 0.7,
		})
	if main.bolt.spread_count == 1:
		options.append({
			"id": "bolt_spread",
			"title": "Bolt: triple spread",
			"desc": "Bolt fires a spread of 3 projectiles",
			"apply": func() -> void: main.bolt.spread_count = 3,
		})
	options.shuffle()
	return options.slice(0, count)
