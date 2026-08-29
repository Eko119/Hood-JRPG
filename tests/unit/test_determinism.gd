extends GutTest
## Regression tests for DEC-004 and DEC-012 — the determinism contract.
##
## These exist because purity does not imply determinism. A pure function that
## calls global randi() is structurally pure and completely irreproducible, and
## a balance report you cannot reproduce is a balance report you cannot act on.
## If these ever fail, the simulator's output stops being trustworthy.

const SEED: int = 847293

func _roll_sequence(seed_value: int, n: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[int] = []
	for i in n:
		out.append(rng.randi_range(1, 100))
	return out

func test_same_seed_yields_same_sequence() -> void:
	assert_eq(_roll_sequence(SEED, 20), _roll_sequence(SEED, 20),
		"identical seeds must produce identical sequences")

func test_different_seed_yields_different_sequence() -> void:
	# Guards against a broken seeding path silently making every battle
	# identical — which would look deterministic and be useless.
	assert_ne(_roll_sequence(SEED, 20), _roll_sequence(SEED + 1, 20),
		"different seeds should diverge")

func test_state_restore_resumes_mid_sequence() -> void:
	# DEC-012. Seed-only replay restarts a battle from turn zero. Saving `state`
	# lets us resume at the exact turn a simulation failed — and, more urgently,
	# stops a mid-battle save/load from silently changing the player's rolls.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in 3:
		rng.randi_range(1, 100)
	var checkpoint := rng.state

	var first: Array[int] = []
	for i in 5:
		first.append(rng.randi_range(1, 100))

	rng.state = checkpoint
	var second: Array[int] = []
	for i in 5:
		second.append(rng.randi_range(1, 100))

	assert_eq(first, second, "restoring state must reproduce the continuation")

func test_state_survives_dictionary_round_trip() -> void:
	# The save file is JSON (DEC-005), so RNG state has to survive serialization
	# intact. This is the specific path a mid-battle save takes.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	rng.randi_range(1, 100)
	var saved := {"rng_state": rng.state}

	var expected: Array[int] = []
	for i in 3:
		expected.append(rng.randi_range(1, 100))

	var restored := RandomNumberGenerator.new()
	restored.state = saved["rng_state"]
	var actual: Array[int] = []
	for i in 3:
		actual.append(restored.randi_range(1, 100))

	assert_eq(actual, expected, "RNG state must survive a dictionary round trip")
