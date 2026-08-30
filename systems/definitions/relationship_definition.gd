extends Resource
class_name RelationshipDefinition
## The bond as data (Constitution §5, DEC-016). DEC-014 locks the party at
## exactly two characters, so a relationship is between exactly two ids.
##
## WHAT THE BOND ACTUALLY IS is unresolved creative design and is NOT expressed
## here — this type carries only its mechanical surface.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false

## Exactly two character ids. Validator enforces the count and that they differ.
@export var between: Array[StringName] = []
## Ordered ascending by threshold. Validator enforces the ordering, because
## unordered tiers would make progression checks order-dependent (DEC-004).
@export var tiers: Array[RelationshipTier] = []
