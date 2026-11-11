extends GutTest
## M2 resolver tests. Each maps to a numbered requirement in the M2 contract.

const F := 65536   # Fixed.ONE

func _entity(eid: String, team: int, hp: int, x: int = 0, y: int = 0) -> CombatEntity:
	var e := CombatEntity.new()
	e.id = StringName(eid); e.team = team as CombatEntity.Team
	e.hp = hp; e.max_hp = hp
	e.ability_resource = 4 * F; e.ability_resource_max = 4 * F
	e.collision_radius_fx = F / 2
	e.move_range_per_cycle_fx = 3 * F
	e.position = FixedVec.make(x * F, y * F)
	return e

func _state(ents: Array) -> BattleState:
	var s := BattleState.new()
	s.entities = ents
	s.arena_half_extent_fx = FixedVec.from_ints(100, 100)
	s.rng_state = 0
	return s

func _noop() -> Callable:
	return func(_snap: BattleState, _tick: int) -> Array: return []

# --- (1)(2) exactly 10 ticks, correct ordering, termination ------------------

func test_window_runs_exactly_ten_ticks() -> void:
	var r: Dictionary = WindowResolver.execute_window(_state([_entity("a", 0, 10)]), _noop())
	assert_eq(r["ticks_run"].size(), 10, "DEC-015: exactly 10 ticks per window")

func test_ticks_are_indexed_one_through_ten_in_order() -> void:
	var r: Dictionary = WindowResolver.execute_window(_state([_entity("a", 0, 10)]), _noop())
	assert_eq(r["ticks_run"], [1,2,3,4,5,6,7,8,9,10], "ticks indexed 1..10 in order")

func test_no_tick_eleven() -> void:
	var seen: Array[int] = []
	var ev := func(snap: BattleState, tick: int) -> Array:
		seen.append(tick)
		return []
	WindowResolver.execute_window(_state([_entity("a", 0, 10)]), ev)
	assert_false(seen.has(11), "Q3: there is no tick 11 in the same window")
	assert_eq(seen.max(), 10)

func test_window_returns_to_planning_and_advances_index() -> void:
	var s := _state([_entity("a", 0, 10)])
	var r: Dictionary = WindowResolver.execute_window(s, _noop())
	var out: BattleState = r["state"]
	assert_eq(out.phase, BattleState.Phase.PLANNING, "returns to Planning after tick 10")
	assert_eq(out.tick_index, 0)
	assert_eq(out.window_index, s.window_index + 1)

# --- (3) simultaneous mutual lethal damage -----------------------------------

func test_mutual_lethal_damage_defeats_both() -> void:
	# Q1: both lethal outcomes are valid; neither cancels the other.
	var a := _entity("alpha", 0, 5)
	var b := _entity("bravo", 1, 5)
	var ev := func(snap: BattleState, tick: int) -> Array:
		if tick != 1: return []
		return [CombatOutcome.damage(&"alpha", &"bravo", 5),
				CombatOutcome.damage(&"bravo", &"alpha", 5)]
	var r: Dictionary = WindowResolver.execute_window(_state([a, b]), ev)
	var out: BattleState = r["state"]
	assert_true(out.get_entity(&"alpha").defeated, "alpha must be DEFEATED")
	assert_true(out.get_entity(&"bravo").defeated, "bravo must be DEFEATED")

func test_lethal_outcome_is_not_cancelled_by_dying_first() -> void:
	# The specific failure Q1 forbids: an entity processed second having its
	# already-valid outcome discarded because it "died first".
	var a := _entity("zzz_last", 0, 3)
	var b := _entity("aaa_first", 1, 3)
	var ev := func(snap: BattleState, tick: int) -> Array:
		if tick != 1: return []
		return [CombatOutcome.damage(&"zzz_last", &"aaa_first", 99),
				CombatOutcome.damage(&"aaa_first", &"zzz_last", 99)]
	var r: Dictionary = WindowResolver.execute_window(_state([a, b]), ev)
	assert_true(r["state"].get_entity(&"zzz_last").defeated)
	assert_true(r["state"].get_entity(&"aaa_first").defeated)

func test_damage_accumulates_from_multiple_sources_in_one_tick() -> void:
	var t := _entity("target", 1, 10)
	var ev := func(snap: BattleState, tick: int) -> Array:
		if tick != 1: return []
		return [CombatOutcome.damage(&"target", &"s1", 4),
				CombatOutcome.damage(&"target", &"s2", 4),
				CombatOutcome.damage(&"target", &"s3", 4)]
	var r: Dictionary = WindowResolver.execute_window(_state([t]), ev)
	assert_true(r["state"].get_entity(&"target").defeated, "12 damage vs 10 hp")

# --- (4) iteration order must not change the authoritative result ------------

func test_reversed_outcome_order_produces_identical_state() -> void:
	var mk := func(reversed: bool) -> String:
		var ents := [_entity("alpha", 0, 12), _entity("bravo", 1, 12), _entity("charlie", 1, 12)]
		if reversed: ents.reverse()
		var ev := func(snap: BattleState, tick: int) -> Array:
			if tick != 3: return []
			var o := [CombatOutcome.damage(&"alpha", &"bravo", 7),
					  CombatOutcome.damage(&"bravo", &"alpha", 7),
					  CombatOutcome.damage(&"charlie", &"alpha", 12),
					  CombatOutcome.damage(&"alpha", &"charlie", 6)]
			if reversed: o.reverse()
			return o
		var s := BattleState.new()
		s.entities = ents
		s.arena_half_extent_fx = FixedVec.from_ints(100, 100)
		return WindowResolver.execute_window(s, ev)["state"].state_hash()
	assert_eq(mk.call(false), mk.call(true),
		"Q1: internal iteration order must not change the authoritative result")

func test_reversed_entity_array_produces_identical_state() -> void:
	var run := func(rev: bool) -> String:
		var ents := [_entity("a", 0, 6), _entity("b", 1, 6)]
		if rev: ents.reverse()
		var ev := func(snap: BattleState, tick: int) -> Array:
			if tick != 1: return []
			return [CombatOutcome.damage(&"a", &"b", 6), CombatOutcome.damage(&"b", &"a", 6)]
		var s := BattleState.new()
		s.entities = ents
		s.arena_half_extent_fx = FixedVec.from_ints(100, 100)
		return WindowResolver.execute_window(s, ev)["state"].state_hash()
	assert_eq(run.call(false), run.call(true), "entity array order must not matter")

# --- (5)(6) intent horizon ---------------------------------------------------

func _horizon_setup() -> Array:
	var s := _state([_entity("player_one", 0, 10), _entity("enemy_one", 1, 10)])
	s.window_index = 4
	var h := IntentHorizon.new()
	var near := CombatIntent.new(); near.actor_id = &"enemy_one"; near.ability_id = &"test_strike"
	var far := CombatIntent.new();  far.actor_id = &"enemy_one";  far.ability_id = &"test_lob"
	h.commit(5, [near])   # upcoming window
	h.commit(6, [far])    # two ahead — must never be visible
	h.commit(7, [far])
	return [s, h]

func test_intent_visible_for_exactly_the_upcoming_window() -> void:
	var setup := _horizon_setup()
	var got: Array = (setup[1] as IntentHorizon).visible_enemy_intents(setup[0])
	assert_eq(got.size(), 1, "exactly the upcoming window's intents")
	assert_eq(String(got[0].ability_id), "test_strike")

func test_no_intent_exposed_beyond_horizon() -> void:
	var setup := _horizon_setup()
	var h: IntentHorizon = setup[1]
	var s: BattleState = setup[0]
	# The store genuinely holds later windows; they must remain unreachable.
	assert_true(h.has_stored_window(6), "fixture must actually store a later window")
	assert_true(h.has_stored_window(7))
	for i: CombatIntent in (h.visible_enemy_intents(s) as Array):
		assert_ne(String(i.ability_id), "test_lob", "window+2 intent must not leak")
	assert_false(IntentHorizon.is_visible(4, 6), "window+2 is beyond the horizon")
	assert_false(IntentHorizon.is_visible(4, 7))
	assert_true(IntentHorizon.is_visible(4, 5), "window+1 is the horizon")

func test_horizon_constant_is_one_window() -> void:
	assert_eq(BattleState.INTENT_HORIZON_WINDOWS, 1, "Q2: exactly one window ahead")

func test_defeated_enemies_expose_no_intent() -> void:
	var setup := _horizon_setup()
	var s: BattleState = setup[0]
	s.get_entity(&"enemy_one").defeated = true
	assert_eq((setup[1] as IntentHorizon).visible_enemy_intents(s).size(), 0)

# --- (7) deterministic fixed-point spatial execution -------------------------

func test_spatial_movement_is_deterministic_and_fixed_point() -> void:
	var run := func() -> PackedInt64Array:
		var e := _entity("mover", 0, 10, 0, 0)
		var ev := func(snap: BattleState, tick: int) -> Array:
			var cur: CombatEntity = snap.get_entity(&"mover")
			var dest := FixedVec.from_ints(37, 91)
			var step: int = Fixed.div(cur.move_range_per_cycle_fx, Fixed.from_int(BattleState.TICKS_PER_WINDOW))
			return [CombatOutcome.set_position(&"mover", FixedVec.move_toward(cur.position, dest, step))]
		return WindowResolver.execute_window(_state([e]), ev)["state"].get_entity(&"mover").position
	var a: PackedInt64Array = run.call()
	var b: PackedInt64Array = run.call()
	assert_true(FixedVec.equals(a, b), "spatial execution must reproduce exactly")
	assert_eq(typeof(a), TYPE_PACKED_INT64_ARRAY, "positions stay integer fixed-point")

func test_conflicting_position_writes_are_reported_not_ordered() -> void:
	# Q1: order must never decide. Two destinations in one tick is a conflict.
	var ev := func(snap: BattleState, tick: int) -> Array:
		if tick != 1: return []
		return [CombatOutcome.set_position(&"m", FixedVec.from_ints(1, 1)),
				CombatOutcome.set_position(&"m", FixedVec.from_ints(9, 9))]
	var r: Dictionary = WindowResolver.execute_window(_state([_entity("m", 0, 10)]), ev)
	assert_gt((r["conflicts"] as Array).size(), 0, "conflicting writes must be reported")

# --- (8) identical inputs produce identical results --------------------------

func test_identical_inputs_produce_identical_state_hash() -> void:
	var run := func() -> String:
		var ev := func(snap: BattleState, tick: int) -> Array:
			return [CombatOutcome.damage(&"b", &"a", tick),
					CombatOutcome.regen(&"a", tick * 100)]
		return WindowResolver.execute_window(
			_state([_entity("a", 0, 200), _entity("b", 1, 200)]), ev)["state"].state_hash()
	assert_eq(run.call(), run.call(), "same inputs must give the same state hash")

func test_event_timeline_is_tick_stamped_and_ordered() -> void:
	var ev := func(snap: BattleState, tick: int) -> Array: return [CombatOutcome.damage(&"b", &"a", 1)]
	var r: Dictionary = WindowResolver.execute_window(
		_state([_entity("a", 0, 50), _entity("b", 1, 50)]), ev)
	var ticks: Array = []
	for e: Dictionary in (r["events"] as Array):
		if e["type"] == "damage": ticks.append(e["tick"])
	assert_eq(ticks, [1,2,3,4,5,6,7,8,9,10], "DEC-014: tick-stamped event timeline")

# --- (9) save/load preserves RNG state exactly -------------------------------

func test_battle_state_survives_json_round_trip_with_exact_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 847293
	rng.randi()
	var s := _state([_entity("a", 0, 10, 3, -7), _entity("b", 1, 8, -2, 5)])
	s.rng_state = rng.state
	s.window_index = 3

	var back := BattleState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.rng_state, s.rng_state, "DEC-019: RNG state must survive JSON exactly")
	assert_eq(back.state_hash(), s.state_hash(), "full state must round-trip")

	# And the restored generator must continue the same sequence.
	var expect: Array[int] = []
	var r1 := s.make_rng()
	for i in 4: expect.append(r1.randi_range(1, 100))
	var got: Array[int] = []
	var r2 := back.make_rng()
	for i in 4: got.append(r2.randi_range(1, 100))
	assert_eq(got, expect, "restored RNG must continue identically")

func test_state_hash_is_independent_of_entity_array_order() -> void:
	var a := _entity("alpha", 0, 10, 1, 2)
	var b := _entity("bravo", 1, 20, 3, 4)
	var s1 := _state([a, b])
	var s2 := _state([b.clone(), a.clone()])
	assert_eq(s1.state_hash(), s2.state_hash(), "hash must be order-independent")

# --- guards ------------------------------------------------------------------

func test_no_float_leaks_into_serialized_state() -> void:
	var s := _state([_entity("a", 0, 10, 5, -3)])
	s.rng_state = -5973960184894437042
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	assert_eq(typeof(parsed["rng_state"]), TYPE_STRING, "rng_state must serialize as string")
	var pos: Array = parsed["entities"][0]["position"]
	assert_eq(typeof(pos[0]), TYPE_STRING, "positions must serialize as strings")
	assert_eq(BattleState.from_dict(parsed).rng_state, s.rng_state)

func test_snapshot_is_not_aliased_by_live_state() -> void:
	# If evaluation could see mutations from earlier in the same tick, Q1's
	# guarantee would be gone. Prove the snapshot is a genuine copy.
	var observed: Array[int] = []
	var ev := func(snap: BattleState, tick: int) -> Array:
		observed.append(snap.get_entity(&"a").hp)
		return [CombatOutcome.damage(&"a", &"a", 1)]
	WindowResolver.execute_window(_state([_entity("a", 0, 100)]), ev)
	assert_eq(observed, [100, 99, 98, 97, 96, 95, 94, 93, 92, 91],
		"each tick must see the state as of that tick's start, not mid-tick")

func test_status_reapplication_is_reported_not_silently_stacked() -> void:
	# OPEN-6: no locked contract determines non-stacking re-application.
	var ev := func(snap: BattleState, tick: int) -> Array:
		if tick > 2: return []
		return [CombatOutcome.apply_status(&"a", &"test_slowed", 2)]
	var r: Dictionary = WindowResolver.execute_window(_state([_entity("a", 0, 10)]), ev)
	var found := false
	for c: String in (r["conflicts"] as Array):
		if String(c).findn("OPEN-6") != -1: found = true
	assert_true(found, "re-application must be reported as undetermined")
	assert_eq((r["state"].get_entity(&"a").statuses as Array).size(), 1,
		"exactly one application landed; the second was not silently stacked")
