extends Resource
class_name CharacterDefinition
## A playable character. DEC-014 locks the party at exactly two, so there will
## be two of these — not a roster.
##
## Deliberately minimal stat block. HP and ability_resource are mechanically
## implied by locked decisions (things die; DEC-018 defines a spendable
## resource). Movement is implied by continuous space plus the locked cycle.
## A broader stat list (attack/defense/magic/resistance/luck) is NOT included:
## no locked decision establishes it, and inventing one would encode a damage
## model that belongs to M2.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false

@export_group("Core stats")
@export var max_hp: int = 1
## DEC-018, fixed-point. Named per NOUN-001 placeholder.
@export var ability_resource_max: int = 0

@export_group("Movement")
## Distance movable in one planning cycle, fixed-point. Per-CYCLE, which DEC-014
## locks. A per-tick speed would require DEC-015 and is therefore absent.
@export var move_range_per_cycle_fx: int = 0
@export var collision_radius_fx: int = 0

@export_group("Progression (DEC-016 layer A: levels)")
## "Levels primarily provide predictable increases to core character capability."
## Linear per-level increments only — no curve shape is chosen, because none is
## specified by a locked decision.
@export var hp_per_level: int = 0
@export var ability_resource_per_level_fx: int = 0
@export var max_level: int = 1

@export_group("Progression (DEC-016 layer B: equipment)")
@export var equipment_slots: Array[StringName] = []

@export_group("Abilities")
@export var starting_abilities: Array[Resource] = []

## NOTE: ability_resource regeneration is NOT configured here. DEC-018 governs it
## via BalanceConstants.RESOURCE_REGEN_*; duplicating those values per character
## would create a second source of truth for the same rule.
