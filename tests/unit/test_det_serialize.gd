extends GutTest
## Regression tests for DEC-019. The bug these guard against was found by probing
## the real API, not by reasoning about it, and it silently corrupted replay.

func test_plain_json_actually_loses_large_ints() -> void:
	# Documents the defect itself. If Godot ever fixes this, this test fails and
	# tells us the workaround can be revisited — that is intentional.
	var big: int = -5973960184894437042
	var back = JSON.parse_string(JSON.stringify({"v": big}))["v"]
	assert_ne(int(back), big, "plain JSON is expected to be lossy above 2^53")
	assert_eq(typeof(back), TYPE_FLOAT, "JSON numbers parse back as float")

func test_string_encoding_survives_json_exactly() -> void:
	for v in [-5973960184894437042, 9223372036854775806, -9223372036854775807, 0, 1, -1]:
		var json := JSON.stringify({"v": DetSerialize.enc_int(v)})
		var back := DetSerialize.dec_int(JSON.parse_string(json)["v"])
		assert_eq(back, v, "int %d must survive JSON exactly" % v)

func test_rng_state_survives_a_full_json_round_trip() -> void:
	# The actual failure scenario: save mid-battle, reload, keep rolling.
	var rng := RandomNumberGenerator.new()
	rng.seed = 847293
	for i in 5:
		rng.randi_range(1, 100)
	var expected: Array[int] = []
	var checkpoint := rng.state
	for i in 4:
		expected.append(rng.randi_range(1, 100))

	var json := JSON.stringify({"rng_state": DetSerialize.enc_int(checkpoint)})
	var restored := RandomNumberGenerator.new()
	restored.state = DetSerialize.dec_int(JSON.parse_string(json)["rng_state"])
	var actual: Array[int] = []
	for i in 4:
		actual.append(restored.randi_range(1, 100))

	assert_eq(actual, expected, "rolls after a JSON save/load must match exactly")

func test_fixed_point_vectors_survive_json() -> void:
	var v := FixedVec.make(Fixed.from_int(-46000), Fixed.from_float(123.456))
	var back := DetSerialize.dec_vec(JSON.parse_string(JSON.stringify(DetSerialize.enc_vec(v)))) 
	assert_true(FixedVec.equals(back, v), "fixed-point position must survive JSON exactly")

func test_is_json_safe_boundary() -> void:
	assert_true(DetSerialize.is_json_safe(DetSerialize.SAFE_JSON_INT_MAX))
	assert_false(DetSerialize.is_json_safe(DetSerialize.SAFE_JSON_INT_MAX + 2))
	assert_true(DetSerialize.is_json_safe(-DetSerialize.SAFE_JSON_INT_MAX))
