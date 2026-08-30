extends RefCounted
class_name WindowResolver
## Executes one full execution window.
##
## CONTRACT TRACE
##   DEC-015 / Q3: exactly 10 ticks, indexed 1..10, no tick 11, no sub-tick layer.
##   DEC-015: "After tick 10 fully resolves, the execution window ends and the
##             game returns to Planning."
##   DEC-014: the domain produces what happened; presentation replays the events.
##   Q1:      every tick evaluates against an immutable tick-start snapshot.
##
## THE SEAM, STATED PLAINLY. `evaluator` is a Callable
##     (snapshot: BattleState, tick: int) -> Array[CombatOutcome]
## that maps committed intents to outcomes for one tick. **That mapping is not
## determined by any locked contract** — see docs/m2-open-semantics.md. This
## resolver deliberately does not contain one. Supplying it is a design decision,
## not an implementation detail, so the seam is explicit rather than filled in
## with a plausible default.

## Runs ticks 1..10. Returns the final state, the tick-stamped event timeline,
## and any Q1 conflicts encountered.
static func execute_window(state: BattleState, evaluator: Callable) -> Dictionary:
	var s := state.clone()
	s.phase = BattleState.Phase.EXECUTING
	var events: Array = []
	var conflicts: Array = []
	var ticks_run: Array[int] = []

	for tick in range(BattleState.FIRST_TICK, BattleState.LAST_TICK + 1):
		s.tick_index = tick
		ticks_run.append(tick)

		# Q1: the authoritative state at the beginning of this tick. Evaluation
		# reads ONLY this. It is never mutated during evaluation, so no entity's
		# outcome can be affected by another entity having been processed first.
		var snapshot: BattleState = s.clone()

		var outcomes: Array = evaluator.call(snapshot, tick)
		var r: Dictionary = TickResolver.apply_tick(s, outcomes, tick)
		events.append_array(r["events"])
		conflicts.append_array(r["conflicts"])

	# DEC-015: the window ends after tick 10 fully resolves; return to Planning.
	s.phase = BattleState.Phase.PLANNING
	s.tick_index = 0
	s.window_index += 1

	return {
		"state": s,
		"events": events,
		"conflicts": conflicts,
		"ticks_run": ticks_run,
	}
