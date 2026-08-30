extends Resource
class_name EncounterDefinition
## A specific arrangement of enemies in continuous space (DEC-017).
##
## Positions are authored explicitly rather than generated. Random spawn
## placement would introduce non-reproducible setup, which defeats the point of
## a deterministic resolver — an encounter must be replayable from its id.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false

## Parallel arrays rather than a nested resource per spawn: keeps the .tres
## readable and keeps ordering explicit. Validator enforces equal lengths and
## that ordering is stable (DEC-004 — spawn order must not vary run to run).
@export var enemies: Array[Resource] = []
## Fixed-point spawn positions, one per enemy, as [x, y] pairs.
@export var spawn_positions: Array[PackedInt64Array] = []

## Battlefield extent, fixed-point. Half-width and half-height from origin.
@export var arena_half_extent_fx: PackedInt64Array = PackedInt64Array([0, 0])
