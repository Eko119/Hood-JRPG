extends Resource
class_name EquipmentDefinition
## DEC-016: equipment is one of three progression layers and is explicitly kept
## "understandable and relatively limited in complexity" — so this type stays
## deliberately thin. No sockets, no affixes, no procedural generation.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var authored: bool = false

## Which slot this occupies. The slot vocabulary is content, not schema.
@export var slot: StringName = &""
## Additive fixed-point modifiers keyed by stat name.
@export var stat_modifiers: Dictionary = {}
## DEC-016 permits equipment to grant abilities.
@export var granted_abilities: Array[Resource] = []
@export var price: int = 0
@export var sellable: bool = true
## Balance band. Used by the validator's dominated-item warning.
@export var tier: int = 1
