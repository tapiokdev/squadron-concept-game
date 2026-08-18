class_name DroneDef
extends Resource

## Data definition for one drone type, mirroring EnemyDef. Picking the
## same type again in the upgrade screen adds another unit (stacking);
## respawn time grows per extra copy — see DroneSquad.

## Hull frame. BRAWLER is the broad shielded drone that holds a line;
## LANCER is the slim standoff drone. Explicit rather than inferred from
## attack_range so a future type isn't forced to look like its range.
enum Frame { BRAWLER, LANCER }

@export var display_name: String = ""
@export var frame: Frame = Frame.BRAWLER
@export var max_hp: float = 60.0
@export var speed: float = 90.0
@export var radius: float = 10.0
@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.0
@export var attack_range: float = 34.0
@export var base_respawn: float = 10.0
@export var color: Color = Color.WHITE
