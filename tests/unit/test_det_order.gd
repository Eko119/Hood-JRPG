extends GutTest
## Regression tests for DEC-020. Guards the tie-break primitive the resolver
## will depend on for every simultaneous-resolution ordering decision.

func test_stringname_comparison_is_not_lexicographic() -> void:
	# Documents the defect. If Godot ever changes this, this test fails and tells
	# us the workaround can be revisited — intentional.
	var a := StringName("m_" + "one")
	var b := StringName("m_" + "two")
	assert_false(a < b, "StringName '<' is expected to be pointer-based, not lexical")
	assert_true(String(a) < String(b), "String comparison is lexical")

func test_sorted_ids_is_lexicographic() -> void:
	var got := DetOrder.sorted_ids([&"zebra", &"alpha", &"mango", &"beta"])
	assert_eq(got, ["alpha", "beta", "mango", "zebra"])

func test_sorted_ids_is_stable_across_construction_order() -> void:
	# The real hazard: same ids, built in different orders, must sort identically.
	var forward := DetOrder.sorted_ids([
		StringName("e_" + "003"), StringName("e_" + "001"), StringName("e_" + "002")])
	var backward := DetOrder.sorted_ids([
		StringName("e_" + "002"), StringName("e_" + "001"), StringName("e_" + "003")])
	assert_eq(forward, backward, "construction order must not affect sort result")
	assert_eq(forward, ["e_001", "e_002", "e_003"])

func test_compare_ids_three_way() -> void:
	assert_eq(DetOrder.compare_ids(StringName("a_" + "x"), StringName("b_" + "y")), -1)
	assert_eq(DetOrder.compare_ids(StringName("b_" + "y"), StringName("a_" + "x")), 1)
	assert_eq(DetOrder.compare_ids(&"same", &"same"), 0)

func test_sort_by_id_orders_objects_deterministically() -> void:
	var a := AbilityDefinition.new(); a.id = StringName("z_" + "last")
	var b := AbilityDefinition.new(); b.id = StringName("a_" + "first")
	var c := AbilityDefinition.new(); c.id = StringName("m_" + "mid")
	var sorted := DetOrder.sort_by_id([a, b, c])
	assert_eq(String(sorted[0].id), "a_first")
	assert_eq(String(sorted[1].id), "m_mid")
	assert_eq(String(sorted[2].id), "z_last")

func test_pending_decision_report_order_is_lexicographic() -> void:
	var ids := PendingDecisions.blocked_ids()
	var copy := ids.duplicate(); copy.sort()
	assert_eq(ids, copy, "blocked decision reporting must be deterministically ordered")
