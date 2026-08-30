extends SceneTree
## Cross-process determinism probe (M2 test requirement 10).
##
## Unit tests prove reproducibility WITHIN one process, where pointer values,
## allocation order, and dictionary layout all happen to be stable. That is
## exactly the condition under which DEC-020's StringName bug stayed invisible.
## This probe runs the same scenario in a FRESH process and prints a state hash,
## so verify.sh can compare two independent runs.
##
## Prints one line: DETERMINISM_HASH=<sha256>

const F := 65536

func _init() -> void:
	var s := BattleState.new()
	s.arena_half_extent_fx = FixedVec.from_ints(100, 100)
	# Ids chosen so lexical and insertion order DISAGREE — a pointer-ordered
	# sort would produce a different hash here than a lexical one.
	for spec in [["zulu", 1, 40, 12, -5], ["alpha", 0, 35, -8, 3],
				 ["mike", 1, 50, 4, 9], ["bravo", 0, 45, -2, -11]]:
		var e := CombatEntity.new()
		e.id = StringName(spec[0])
		e.team = spec[1] as CombatEntity.Team
		e.hp = spec[2]; e.max_hp = spec[2]
		e.ability_resource = 4 * F; e.ability_resource_max = 4 * F
		e.collision_radius_fx = F / 2
		e.move_range_per_cycle_fx = 3 * F
		e.position = FixedVec.make(spec[3] * F, spec[4] * F)
		s.entities.append(e)

	var rng := RandomNumberGenerator.new()
	rng.seed = 847293
	s.rng_state = rng.state

	var ev := func(snap: BattleState, tick: int) -> Array:
		var out: Array = []
		var r := snap.make_rng()
		# Deterministic per-tick behaviour exercising damage, movement, resource
		# and RNG, all against the tick-start snapshot.
		for e in snap.entities_in_canonical_order():
			if e.defeated: continue
			var roll: int = r.randi_range(1, 6)
			var foes: Array = []
			for other in snap.entities_in_canonical_order():
				if other.team != e.team and not other.defeated:
					foes.append(other)
			if foes.size() > 0:
				out.append(CombatOutcome.damage(foes[0].id, e.id, roll))
			var dest := FixedVec.make(-e.position[0], -e.position[1])
			var step: int = Fixed.div(e.move_range_per_cycle_fx, Fixed.from_int(10))
			out.append(CombatOutcome.set_position(e.id, FixedVec.move_toward(e.position, dest, step)))
			out.append(CombatOutcome.regen(e.id, BalanceConstants.RESOURCE_REGEN_PER_UNIT_MOVED))
		return out

	var state := s
	for w in 4:
		var res: Dictionary = WindowResolver.execute_window(state, ev)
		state = res["state"]
		if (res["conflicts"] as Array).size() > 0:
			print("CONFLICTS=", res["conflicts"])
	print("DETERMINISM_HASH=", state.state_hash())
	quit(0)
