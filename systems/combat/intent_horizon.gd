extends RefCounted
class_name IntentHorizon
## Enforces Q2: enemy intent is visible for EXACTLY the immediately upcoming
## execution window, and nothing beyond it.
##
## The restriction is structural rather than a convention someone must remember.
## Intents for later windows may exist in this store — an enemy planner may run
## ahead internally — but `visible_enemy_intents` cannot return them, and
## `is_visible` answers false for any horizon beyond one window.
##
## Q2 explicitly excludes: future enemy decisions beyond the horizon, future
## random outcomes, hidden state, future reactions to player actions, unresolved
## future interactions, and intent two or more windows ahead. This class exposes
## only committed intents for window_index + 1, which contains none of those.

var _by_window: Dictionary = {}   # int window_index -> Array[CombatIntent]

func commit(window_index: int, intents: Array) -> void:
	var sorted: Array = intents.duplicate()
	# DEC-020: canonical order by actor id, never StringName comparison.
	sorted.sort_custom(func(a: CombatIntent, b: CombatIntent) -> bool: return String(a.actor_id) < String(b.actor_id))
	_by_window[window_index] = sorted

## Q2: true only for the single upcoming window.
static func is_visible(current_window: int, requested_window: int) -> bool:
	return requested_window == current_window + BattleState.INTENT_HORIZON_WINDOWS

## Enemy intents for the upcoming window only. Returns [] for any other window,
## even when this store holds intents for it.
func visible_enemy_intents(state: BattleState) -> Array:
	var target_window: int = state.window_index + BattleState.INTENT_HORIZON_WINDOWS
	if not _by_window.has(target_window):
		return []
	var out: Array = []
	for i: CombatIntent in _by_window[target_window]:
		var e: CombatEntity = state.get_entity(i.actor_id)
		if e != null and e.team == CombatEntity.Team.ENEMY and not e.defeated:
			out.append(i)
	return out

## Explicit accessor used by tests to prove intents beyond the horizon exist in
## the store yet remain unreachable through the visible path.
func has_stored_window(window_index: int) -> bool:
	return _by_window.has(window_index)

func stored_window_count() -> int:
	return _by_window.size()
