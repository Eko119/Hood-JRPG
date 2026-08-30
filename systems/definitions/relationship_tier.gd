extends Resource
class_name RelationshipTier
## One step of relationship progression (DEC-016, Constitution §5).

## Bond points required to reach this tier. Unitless and cycle-independent.
@export var threshold: int = 0
@export var display_name: String = ""
## DEC-016: relationships unlock abilities, cooperative actions, and passives.
@export var unlocked_abilities: Array[Resource] = []
## Constitution §6: relationships must NOT be the sole source of numeric growth.
## Passive modifiers are permitted but the validator caps their share.
@export var passive_modifiers: Dictionary = {}
