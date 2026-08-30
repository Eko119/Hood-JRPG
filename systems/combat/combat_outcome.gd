extends RefCounted
class_name CombatOutcome
## A single state transition produced by evaluating one tick.
##
## Q1 is the whole reason this type exists. Outcomes are COMPUTED against the
## immutable tick-start snapshot and only APPLIED after every outcome for that
## tick has been computed. That separation is what makes mutual destruction
## work and what makes internal iteration order irrelevant to the result.
##
## CONTRACT TRACE for each kind:
##   DAMAGE          Q1 (lethal outcomes), AbilityDefinition.base_power_fx
##   SPEND_RESOURCE  DEC-018, AbilityDefinition.ability_resource_cost
##   REGEN_RESOURCE  DEC-018 via BalanceConstants
##   SET_POSITION    DEC-017 (fixed-point continuous space)
##   APPLY_STATUS    StatusEffectDefinition
##
## NOTE: nothing here decides WHEN an ability produces an outcome. That mapping
## is an unresolved semantic (see docs/m2-open-semantics.md) and is deliberately
## absent rather than guessed.

enum Kind { DAMAGE, SPEND_RESOURCE, REGEN_RESOURCE, SET_POSITION, APPLY_STATUS }

var kind: Kind
var target_id: StringName = &""
var source_id: StringName = &""
## Fixed-point scalar for DAMAGE / SPEND / REGEN. Unused for others.
var amount: int = 0
## Fixed-point position for SET_POSITION. Unused for others.
var position: PackedInt64Array = PackedInt64Array([0, 0])
var status_id: StringName = &""
var status_cycles: int = 0

static func damage(target: StringName, source: StringName, amount_fx: int) -> CombatOutcome:
	var o := CombatOutcome.new()
	o.kind = Kind.DAMAGE
	o.target_id = target
	o.source_id = source
	o.amount = amount_fx
	return o

static func spend(target: StringName, amount_fx: int) -> CombatOutcome:
	var o := CombatOutcome.new()
	o.kind = Kind.SPEND_RESOURCE
	o.target_id = target
	o.amount = amount_fx
	return o

static func regen(target: StringName, amount_fx: int) -> CombatOutcome:
	var o := CombatOutcome.new()
	o.kind = Kind.REGEN_RESOURCE
	o.target_id = target
	o.amount = amount_fx
	return o

static func set_position(target: StringName, pos: PackedInt64Array) -> CombatOutcome:
	var o := CombatOutcome.new()
	o.kind = Kind.SET_POSITION
	o.target_id = target
	o.position = PackedInt64Array([pos[0], pos[1]])
	return o

static func apply_status(target: StringName, sid: StringName, cycles: int) -> CombatOutcome:
	var o := CombatOutcome.new()
	o.kind = Kind.APPLY_STATUS
	o.target_id = target
	o.status_id = sid
	o.status_cycles = cycles
	return o
