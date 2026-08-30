extends RefCounted
class_name PendingDecisions
## Registry of design decisions that are NOT yet made, and the schema/validation
## surface each one blocks.
##
## Purpose: make unresolved design explicit and machine-detectable instead of
## letting "the code needed a value" quietly become a design decision. Nothing
## here may be resolved by Claude. Each entry names the decision, who it waits
## on, and exactly what stays impossible until it is answered.
##
## The validator reads this registry and reports blocked rules as BLOCKED rather
## than passing them silently. Content that references a blocked field FAILS.

enum Status { BLOCKED, RESOLVED }

## Decision id -> { question, blocks, status }
const REGISTRY: Dictionary = {
	&"DEC-015": {
		"question": "Approve the fixed-timestep, phase-ordered tick simulation model?",
		"status": Status.BLOCKED,
		"blocks": [
			"All sub-cycle (per-tick) temporal quantities.",
			"Projectile position during flight.",
			"Ability wind-up / active / recovery windows.",
			"Any duration finer than one planning cycle.",
		],
	},
	&"DEC-015-Q1": {
		"question": "May two combatants destroy each other in the same tick?",
		"status": Status.BLOCKED,
		"blocks": [
			"Resolver death-check ordering.",
			"Whether any ability needs a 'survives lethal' flag (do NOT add one speculatively).",
		],
	},
	&"DEC-015-Q2": {
		"question": "How many cycles ahead is enemy intent visible?",
		"status": Status.BLOCKED,
		"blocks": [
			"EnemyDefinition telegraph lead-time field.",
			"Validation that a multi-cycle ability's flight time exceeds intent horizon.",
		],
	},
	&"DEC-015-Q3": {
		"question": "How many ticks constitute one execution window?",
		"status": Status.BLOCKED,
		"blocks": [
			"Any validator rule bounding a tick-denominated value against window length.",
			"Conversion between per-tick and per-cycle rates.",
		],
	},
	&"AMD-001": {
		"question": "Replace DEC-007's menu-JRPG combat command list in the slice definition?",
		"status": Status.BLOCKED,
		"blocks": ["Vertical slice acceptance criteria for combat."],
	},
	&"AMD-002": {
		"question": "Adopt DEC-015's spatial determinism clauses into DEC-004?",
		"status": Status.BLOCKED,
		"blocks": ["Formal determinism clauses for simultaneous movement and projectile crossing."],
	},
	&"AMD-003": {
		"question": "Extend DEC-009's art spec with spatial/telegraph items?",
		"status": Status.BLOCKED,
		"blocks": ["M2 art specification completeness criteria."],
	},
	&"NOUN-001": {
		"question": "What is the ability resource actually called?",
		"status": Status.BLOCKED,
		"blocks": ["Final identifier. Code uses 'ability_resource' as a temporary name (DEC-018)."],
	},
}

## Field-name prefix marking a temporary, unusable placeholder. Any definition
## carrying a field with this prefix set to a non-default value fails validation.
const BLOCKED_FIELD_PREFIX: String = "blocked_"

static func is_blocked(id: StringName) -> bool:
	return REGISTRY.has(id) and REGISTRY[id]["status"] == Status.BLOCKED

static func blocked_ids() -> Array:
	var out: Array = []
	for k in REGISTRY.keys():
		if REGISTRY[k]["status"] == Status.BLOCKED:
			out.append(k)
	# DEC-020: StringName comparison is pointer-based, not lexicographic.
	# Sorting these directly would give a different order per process.
	return DetOrder.sorted_ids(out)
