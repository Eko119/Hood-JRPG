extends Resource
class_name EnemyDefinition
## An enemy combatant. Extended at M1 for continuous space and abilities.
##
## WHAT AN ENEMY REPRESENTS in this world is unresolved creative design
## (design-constitution.md §9) and is not encoded here.
##
## `id` is the stable key saves and cross-references point at. Never reused
## after deletion; renaming is a migration, not an edit.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false

@export_group("Core stats")
@export var max_hp: int = 1
@export var ability_resource_max: int = 0

@export_group("Spatial (DEC-017, fixed-point)")
@export var move_range_per_cycle_fx: int = 0
@export var collision_radius_fx: int = 0

@export_group("Abilities")
@export var abilities: Array[Resource] = []

@export_group("Rewards")
@export var xp_reward: int = 0
@export var money_reward: int = 0
@export var encounter_tier: int = 1

@export_group("BLOCKED — do not set")
## How many cycles ahead this enemy's intent is telegraphed. Blocked on
## DEC-015-Q2. -1 = not set, the only value validation accepts.
@export var blocked_intent_horizon_cycles: int = -1
