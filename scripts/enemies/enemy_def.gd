class_name EnemyDef
extends Resource

## Data definition for one enemy type. Enemies are pooled and reconfigured
## from one of these on spawn, so everything type-specific lives here.

## SPAWNER (Broodmother periodic spawn / Popper death-spawn) is added once
## that behaviour exists; the pool and enemy don't care about the value yet.
enum Behavior { WALKER }

@export var display_name: String = ""
@export var behavior: Behavior = Behavior.WALKER
@export var max_hp: float = 10.0
@export var speed: float = 60.0
@export var radius: float = 8.0
@export var contact_damage: float = 5.0
@export var attack_interval: float = 0.8
@export var xp_value: int = 1
@export var color: Color = Color.WHITE
