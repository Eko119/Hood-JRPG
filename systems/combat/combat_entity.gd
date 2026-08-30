extends RefCounted
class_name CombatEntity
## One combatant inside BattleState.
##
## CONTRACT TRACE — every field here is authorized by an existing contract:
##   id                  M1 definitions (stable key, DEC-002)
##   team                DEC-014 (player pair vs enemies)
##   position            DEC-017 continuous space, Q16.16 fixed point
##   hp / max_hp         CharacterDefinition.max_hp, EnemyDefinition.max_hp
##   ability_resource    DEC-018 + *Definition.ability_resource_max
##   collision_radius_fx M1 definitions
##   move_range_fx       M1 move_range_per_cycle_fx
##   defeated            Q1 ("both entities become DEFEATED")
##   statuses            StatusEffectDefinition.duration_cycles
##
## No field is present that is not traceable to a locked contract.

enum Team { PLAYER, ENEMY }

var id: StringName = &""
var team: Team = Team.ENEMY
var position: PackedInt64Array = PackedInt64Array([0, 0])
var hp: int = 1
var max_hp: int = 1
var ability_resource: int = 0
var ability_resource_max: int = 0
var collision_radius_fx: int = 0
var move_range_per_cycle_fx: int = 0
var defeated: bool = false
## [{id: StringName, remaining_cycles: int}] — ordered by DetOrder on write.
var statuses: Array = []

## Deep copy. Required by Q1: each tick is evaluated against an immutable
## snapshot of the state at that tick's beginning, so the snapshot must not
## alias the live state.
func clone() -> CombatEntity:
	var c := CombatEntity.new()
	c.id = id
	c.team = team
	c.position = PackedInt64Array([position[0], position[1]])
	c.hp = hp
	c.max_hp = max_hp
	c.ability_resource = ability_resource
	c.ability_resource_max = ability_resource_max
	c.collision_radius_fx = collision_radius_fx
	c.move_range_per_cycle_fx = move_range_per_cycle_fx
	c.defeated = defeated
	c.statuses = []
	for s in statuses:
		c.statuses.append({"id": s["id"], "remaining_cycles": s["remaining_cycles"]})
	return c

## DEC-019: position and any exactness-critical integer serialize as strings.
func to_dict() -> Dictionary:
	var st: Array = []
	for s in statuses:
		st.append({"id": String(s["id"]), "remaining_cycles": s["remaining_cycles"]})
	return {
		"id": String(id),
		"team": int(team),
		"position": DetSerialize.enc_vec(position),
		"hp": hp,
		"max_hp": max_hp,
		"ability_resource": DetSerialize.enc_int(ability_resource),
		"ability_resource_max": DetSerialize.enc_int(ability_resource_max),
		"collision_radius_fx": DetSerialize.enc_int(collision_radius_fx),
		"move_range_per_cycle_fx": DetSerialize.enc_int(move_range_per_cycle_fx),
		"defeated": defeated,
		"statuses": st,
	}

static func from_dict(d: Dictionary) -> CombatEntity:
	var e := CombatEntity.new()
	e.id = StringName(d["id"])
	e.team = d["team"] as Team
	e.position = DetSerialize.dec_vec(d["position"])
	e.hp = int(d["hp"])
	e.max_hp = int(d["max_hp"])
	e.ability_resource = DetSerialize.dec_int(d["ability_resource"])
	e.ability_resource_max = DetSerialize.dec_int(d["ability_resource_max"])
	e.collision_radius_fx = DetSerialize.dec_int(d["collision_radius_fx"])
	e.move_range_per_cycle_fx = DetSerialize.dec_int(d["move_range_per_cycle_fx"])
	e.defeated = bool(d["defeated"])
	e.statuses = []
	for s in (d["statuses"] as Array):
		e.statuses.append({"id": StringName(s["id"]), "remaining_cycles": int(s["remaining_cycles"])})
	return e
