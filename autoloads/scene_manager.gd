extends Node
## Scene transitions, and preserving field state across a push into battle
## and a pop back out. M0: stub.
var _field_return_state: Dictionary = {}

func push_battle(encounter_id: StringName) -> void:
	_field_return_state = {"map": GameState.current_map}
	EventBus.battle_started.emit(encounter_id)

func pop_to_field() -> void:
	pass
