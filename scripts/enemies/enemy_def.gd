class_name EnemyDef
extends Resource

## Data definition for one enemy type. Enemies are pooled and reconfigured
## from one of these on spawn, so everything type-specific lives here.

## WALKER walks at the tower. SPAWNER also periodically spawns
## `spawned_def` enemies (Broodmother); a death-spawn variant for the
## optional Popper can reuse the same fields later.
enum Behavior { WALKER, SPAWNER }

## Hull outline. Shape carries an enemy's role faster than colour does,
## especially in a dense swarm where everything overlaps, so each type
## gets its own silhouette instead of a tinted circle. DART and CHEVRON
## point along their heading; HEX and CARRIER read the same at any angle.
enum Silhouette { DART, CHEVRON, HEX, CARRIER }

@export var display_name: String = ""
@export var behavior: Behavior = Behavior.WALKER
@export var max_hp: float = 10.0
@export var speed: float = 60.0
@export var radius: float = 8.0
@export var contact_damage: float = 5.0
@export var attack_interval: float = 0.8
@export var xp_value: int = 1
@export var silhouette: Silhouette = Silhouette.DART
@export var color: Color = Color.WHITE

@export_group("Spawner behaviour")
@export var spawned_def: EnemyDef
@export var spawn_interval: float = 4.0
@export var spawn_count: int = 3
