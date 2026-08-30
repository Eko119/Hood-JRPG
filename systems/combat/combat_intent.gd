extends RefCounted
class_name CombatIntent
## A committed action for one entity in one execution window.
##
## CONTRACT TRACE — Q2 authorizes exposing "applicable target, movement,
## trajectory, attack, and timing information". Every field below maps to
## something the M1 content contract already defines:
##   actor_id / target_id   M1 stable ids
##   ability_id             AbilityDefinition.id
##   target_position        DEC-017 fixed-point (TargetKind.POINT / DIRECTION)
##   move_destination       CharacterDefinition.move_range_per_cycle_fx
##
## DELIBERATELY ABSENT: a resolution-tick field. Q2 authorizes EXPOSING timing
## that exists; it does not create timing semantics. Which tick within the window
## a planned action resolves on is not determined by any locked contract
## (docs/m2-open-semantics.md, OPEN-1). Adding the field would encode a model.

var actor_id: StringName = &""
var ability_id: StringName = &""          # empty = no ability this window
var target_id: StringName = &""           # empty = no entity target
var has_target_position: bool = false
var target_position: PackedInt64Array = PackedInt64Array([0, 0])
var has_move: bool = false
var move_destination: PackedInt64Array = PackedInt64Array([0, 0])

func to_dict() -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"ability_id": String(ability_id),
		"target_id": String(target_id),
		"has_target_position": has_target_position,
		"target_position": DetSerialize.enc_vec(target_position),
		"has_move": has_move,
		"move_destination": DetSerialize.enc_vec(move_destination),
	}

static func from_dict(d: Dictionary) -> CombatIntent:
	var i := CombatIntent.new()
	i.actor_id = StringName(d["actor_id"])
	i.ability_id = StringName(d["ability_id"])
	i.target_id = StringName(d["target_id"])
	i.has_target_position = bool(d["has_target_position"])
	i.target_position = DetSerialize.dec_vec(d["target_position"])
	i.has_move = bool(d["has_move"])
	i.move_destination = DetSerialize.dec_vec(d["move_destination"])
	return i
