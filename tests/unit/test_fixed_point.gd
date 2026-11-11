extends GutTest
## Proves the fixed-point foundation (DEC-017) actually holds. Everything spatial
## in the combat domain rests on this, so it gets tested harder than anything else.

func test_int_round_trip_is_exact() -> void:
	for i: int in [-1000, -1, 0, 1, 7, 100, 46000]:
		assert_eq(Fixed.to_float(Fixed.from_int(i)), float(i),
			"integer %d must round-trip exactly" % i)

func test_one_is_unity_under_multiplication() -> void:
	var v := Fixed.from_int(7)
	assert_eq(Fixed.mul(v, Fixed.ONE), v, "x * 1 must equal x")

func test_division_inverts_multiplication_for_exact_values() -> void:
	var a := Fixed.from_int(100)
	var b := Fixed.from_int(4)
	assert_eq(Fixed.div(a, b), Fixed.from_int(25))
	assert_eq(Fixed.mul(Fixed.from_int(25), b), a)

func test_half_is_exact() -> void:
	# Powers of two are exactly representable; this is why the scale is 2^16
	# rather than a decimal power. No rounding on the most common fractions.
	assert_eq(Fixed.div(Fixed.ONE, Fixed.from_int(2)), Fixed.HALF)
	assert_eq(Fixed.to_float(Fixed.HALF), 0.5)

func test_operations_are_bit_identical_across_repeats() -> void:
	# The property that actually matters: same inputs, same bits, every time.
	var results: Array[int] = []
	for run in 3:
		var acc: int = 0
		var step: int = Fixed.from_float(0.1)
		for i in 1000:
			acc = Fixed.mul(acc + step, Fixed.from_float(1.001))
		results.append(acc)
	assert_eq(results[0], results[1], "run 1 and 2 must be bit-identical")
	assert_eq(results[1], results[2], "run 2 and 3 must be bit-identical")

func test_sqrt_is_correct_within_one_unit() -> void:
	for n: int in [1, 2, 4, 9, 16, 100, 144, 1000]:
		var r := Fixed.sqrt_fx(Fixed.from_int(n))
		var expected := sqrt(float(n))
		assert_almost_eq(Fixed.to_float(r), expected, 0.001,
			"sqrt(%d) should be ~%f" % [n, expected])

func test_sqrt_of_perfect_squares_is_exact() -> void:
	for n: int in [1, 4, 9, 16, 25, 100, 10000]:
		assert_eq(Fixed.sqrt_fx(Fixed.from_int(n * n)), Fixed.from_int(n),
			"sqrt of perfect square %d must be exact" % (n * n))

func test_sqrt_handles_zero_and_negative() -> void:
	assert_eq(Fixed.sqrt_fx(0), 0)
	assert_eq(Fixed.sqrt_fx(Fixed.from_int(-5)), 0, "negative must not hang or error")

func test_mul_stays_within_safe_range_for_battlefield_scale() -> void:
	# Guards the overflow bound documented on Fixed.MUL_SAFE_LIMIT.
	var big := Fixed.from_int(46000)
	assert_lt(absi(big), Fixed.MUL_SAFE_LIMIT, "battlefield extent must be in safe range")
	var r := Fixed.mul(big, Fixed.from_int(2))
	assert_eq(Fixed.to_float(r), 92000.0)


# --- Vectors -----------------------------------------------------------------

func test_vector_arithmetic() -> void:
	var a := FixedVec.from_ints(3, 4)
	var b := FixedVec.from_ints(1, 2)
	assert_true(FixedVec.equals(FixedVec.add(a, b), FixedVec.from_ints(4, 6)))
	assert_true(FixedVec.equals(FixedVec.sub(a, b), FixedVec.from_ints(2, 2)))

func test_length_of_3_4_5_triangle_is_exact() -> void:
	var v := FixedVec.from_ints(3, 4)
	assert_eq(FixedVec.length(v), Fixed.from_int(5), "3-4-5 must be exactly 5")

func test_distance_is_symmetric() -> void:
	# Asymmetry here would make "did the projectile hit" depend on argument order,
	# which is precisely how a replay silently diverges.
	var a := FixedVec.from_ints(10, 20)
	var b := FixedVec.from_ints(-5, 7)
	assert_eq(FixedVec.distance(a, b), FixedVec.distance(b, a))

func test_within_uses_squared_comparison_at_the_boundary() -> void:
	var a := FixedVec.from_ints(0, 0)
	var b := FixedVec.from_ints(3, 4)   # distance exactly 5
	assert_true(FixedVec.within(a, b, Fixed.from_int(5)), "exactly at radius counts as within")
	assert_false(FixedVec.within(a, b, Fixed.from_int(4)), "beyond radius must not count")

func test_move_toward_lands_exactly_on_target() -> void:
	# Overshoot must clamp to the destination, not oscillate around it.
	var from := FixedVec.from_ints(0, 0)
	var to := FixedVec.from_ints(3, 4)
	var result := FixedVec.move_toward(from, to, Fixed.from_int(100))
	assert_true(FixedVec.equals(result, to), "a large step must land exactly on target")

func test_move_toward_partial_step_stays_on_the_line() -> void:
	var from := FixedVec.from_ints(0, 0)
	var to := FixedVec.from_ints(3, 4)
	var mid := FixedVec.move_toward(from, to, Fixed.HALF * 5)  # half of distance 5
	var d := FixedVec.length(FixedVec.sub(mid, from))
	assert_almost_eq(Fixed.to_float(d), 2.5, 0.01, "should travel ~half the distance")

func test_repeated_movement_is_reproducible() -> void:
	# The real scenario: many small steps accumulated over an execution window.
	# Float accumulation here is where cross-platform replay divergence lives.
	var runs: Array = []
	for run in 3:
		var pos := FixedVec.from_ints(0, 0)
		var target := FixedVec.from_ints(37, 91)
		for tick in 240:
			pos = FixedVec.move_toward(pos, target, Fixed.from_float(0.137))
		runs.append([pos[0], pos[1]])
	assert_eq(runs[0], runs[1], "240 ticks of movement must reproduce exactly")
	assert_eq(runs[1], runs[2], "and again")

func test_normalized_vector_has_unit_length() -> void:
	var n := FixedVec.normalized(FixedVec.from_ints(3, 4))
	assert_almost_eq(Fixed.to_float(FixedVec.length(n)), 1.0, 0.001)

func test_normalized_zero_vector_does_not_divide_by_zero() -> void:
	assert_true(FixedVec.equals(FixedVec.normalized(FixedVec.zero()), FixedVec.zero()))
