extends GutTest
## Validator tests. Both directions: valid content must pass, deliberately
## invalid content must fail. A validator only tested against good content is
## indistinguishable from one that always returns success.

var v: ContentValidator

func before_each() -> void:
	v = ContentValidator.new()

func _errors_from(root: String) -> Array:
	return v.validate(root)["errors"]

func _has(errs: Array, needle: String) -> bool:
	for e: String in errs:
		if String(e).findn(needle) != -1:
			return true
	return false

# --- valid content must pass -------------------------------------------------

func test_shipped_content_has_zero_errors() -> void:
	var r := v.validate("res://data")
	assert_eq(r["errors"], [], "res://data must validate clean")
	assert_gt(r["checked"], 0, "validator must actually find content")

func test_shipped_content_reports_blocked_decisions() -> void:
	var r := v.validate("res://data")
	assert_gt(r["blocked"].size(), 0, "unresolved decisions must be reported, not hidden")
	assert_true(r["blocked"].has("DEC-015"), "DEC-015 must be listed as blocked")

# --- invalid content must fail -----------------------------------------------

const INVALID := "res://tests/fixtures/invalid"

func test_invalid_fixtures_produce_errors() -> void:
	assert_gt(_errors_from(INVALID).size(), 0, "invalid fixtures must not pass")

func test_catches_malformed_identifier() -> void:
	assert_true(_has(_errors_from(INVALID), "must match ^[a-z]"))

func test_catches_duplicate_identifier() -> void:
	assert_true(_has(_errors_from(INVALID), "duplicate id"))

func test_catches_blocked_field_being_set() -> void:
	# The core M1 contract rule: touching a field whose governing decision is
	# unresolved must fail the build rather than silently choosing behavior.
	var errs := _errors_from(INVALID)
	assert_true(_has(errs, "blocked_windup_ticks"), "blocked ability field must fail")
	assert_true(_has(errs, "blocked_intent_horizon_cycles"), "blocked enemy field must fail")
	assert_true(_has(errs, "governing decision is unresolved"))

func test_catches_out_of_range_fixed_point() -> void:
	assert_true(_has(_errors_from(INVALID), "out of range"))

func test_catches_two_character_party_violation() -> void:
	# DEC-014 locks the party at exactly two.
	assert_true(_has(_errors_from(INVALID), "exactly 2 characters (DEC-014)"))

func test_catches_non_ascending_relationship_tiers() -> void:
	# Unordered tiers would make progression checks order-dependent (DEC-004).
	assert_true(_has(_errors_from(INVALID), "not strictly ascending"))

func test_catches_invented_creative_content() -> void:
	# DEC-008: the characters and the bond are unresolved creative design.
	# Non-placeholder content of those types means someone invented them.
	assert_true(_has(_errors_from(INVALID), "unresolved creative design (DEC-008)"))

func test_catches_soft_lock_status() -> void:
	assert_true(_has(_errors_from(INVALID), "soft-lock"))

func test_catches_noop_status_duration() -> void:
	assert_true(_has(_errors_from(INVALID), "duration_cycles 0"))

func test_catches_unaffordable_enemy_ability() -> void:
	assert_true(_has(_errors_from(INVALID), "unusable"))

func test_catches_encounter_array_mismatch() -> void:
	assert_true(_has(_errors_from(INVALID), "spawn positions"))

func test_catches_unreachable_projectile() -> void:
	assert_true(_has(_errors_from(INVALID), "can never reach anything"))

func test_catches_relationship_as_sole_numeric_source() -> void:
	# Constitution §6 / DEC-016.
	assert_true(_has(_errors_from(INVALID), "sole numeric source"))

# --- validator behavior itself ------------------------------------------------

func test_validator_is_deterministic_across_runs() -> void:
	# Same input, same output, same order. DEC-004 applies to tooling too.
	var a: Array = ContentValidator.new().validate(INVALID)["errors"]
	var b: Array = ContentValidator.new().validate(INVALID)["errors"]
	assert_eq(a, b, "validator output must be order-stable across runs")

func test_validator_does_not_repair_content() -> void:
	# It must reject, never normalise. Re-validating must give identical errors,
	# proving the first pass mutated nothing.
	var first := _errors_from(INVALID).size()
	var second: int = ContentValidator.new().validate(INVALID)["errors"].size()
	assert_eq(first, second, "validation must not mutate the content it checks")
