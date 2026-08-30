extends Resource
class_name StatusEffectDefinition
## Durations are in CYCLES (DEC-014). Per-tick behaviour is blocked on DEC-015.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false

## -1 means "until explicitly removed". 0 is invalid — an effect that lasts no
## cycles is a no-op and is almost always an authoring mistake.
@export var duration_cycles: int = 1
## Additive fixed-point modifiers keyed by stat name.
@export var stat_modifiers: Dictionary = {}
@export var prevents_action: bool = false
@export var stacks: bool = false
## Abilities or items that clear this effect. Reachability rule: a status that
## prevents action and lasts forever with no cure is a soft-lock.
@export var removed_by: Array[Resource] = []

@export_group("BLOCKED — do not set")
## Damage-over-time cadence needs a tick model. -1 = not set.
@export var blocked_tick_interval: int = -1
