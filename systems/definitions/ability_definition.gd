extends Resource
class_name AbilityDefinition
## A tactical verb. Constitution §5 favours interacting verbs over scripted
## combos, so this type carries interaction surface (range, area, projectile
## behaviour, status application) and deliberately does NOT carry a table of
## named combo outcomes.
##
## UNITS: distances are Q16.16 fixed point (DEC-017). Durations are in CYCLES,
## which DEC-014 locks. Nothing here is tick-denominated, because DEC-015 is
## only PROPOSED — see blocked_* fields below.

enum TargetKind { SELF, ALLY, ENEMY, POINT, DIRECTION }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var authored: bool = false

@export_group("Cost")
## DEC-018. Named 'ability_resource' pending NOUN-001; do not rename to a
## guessed final name. Fixed-point.
@export var ability_resource_cost: int = 0

@export_group("Targeting")
@export var target_kind: TargetKind = TargetKind.ENEMY
## Maximum distance from caster, fixed-point. 0 means self/no reach.
@export var range_fx: int = 0
## Effect radius at the impact point, fixed-point. 0 means single target.
@export var area_radius_fx: int = 0

@export_group("Projectile")
## DEC-014's consequences lock that in-flight entities persist across planning
## phases. Cycle-denominated, so it is derivable without DEC-015.
@export var is_projectile: bool = false
## Cycles before impact. 0 = resolves within the cycle it is cast.
## Arco's defining tension lives here: >0 means you aim where a target will be.
@export var flight_cycles: int = 0

@export_group("Effect")
## Base magnitude, fixed-point. The DAMAGE FORMULA is resolver behaviour (M2)
## and is deliberately not expressed here.
@export var base_power_fx: int = 0
@export var applies_status: Resource = null   # StatusEffectDefinition or null

@export_group("Cooperative")
## Constitution §5. Cooperative actions exist and are unlocked by relationship
## progression (DEC-016). Whether this ability requires both characters.
@export var is_cooperative: bool = false

@export_group("BLOCKED — do not set")
## Sub-cycle timing requires DEC-015 approval. -1 means "not set", which is the
## only value validation accepts. Setting anything else fails the build, by
## design: the field exists to make the dependency visible, not to be used.
@export var blocked_windup_ticks: int = -1
@export var blocked_recovery_ticks: int = -1
@export var blocked_projectile_speed_per_tick: int = -1
