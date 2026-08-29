extends GutTest
## The walking skeleton: proves the content pipeline works end to end with
## almost no content. Definition script -> .tres instance -> runtime load ->
## typed field access. If this passes, the data layer is real.

func test_enemy_definition_loads() -> void:
	var res: Resource = load("res://data/enemies/test_dummy.tres")
	assert_not_null(res, "test_dummy.tres must load")

func test_enemy_definition_has_typed_fields() -> void:
	var res: EnemyDefinition = load("res://data/enemies/test_dummy.tres")
	assert_eq(String(res.id), "test_dummy")
	assert_eq(res.max_hp, 40)
	assert_true(res.max_hp > 0, "stats must be positive")

func test_autoloads_are_present() -> void:
	assert_not_null(EventBus, "EventBus autoload missing")
	assert_not_null(GameState, "GameState autoload missing")
	assert_not_null(SaveSystem, "SaveSystem autoload missing")

func test_game_state_round_trips_through_json() -> void:
	# DEC-005: the save file is GameState serialized. If this breaks, saves break.
	GameState.reset()
	GameState.money = 250
	GameState.flags["met_placeholder_npc"] = true
	var json := JSON.stringify(GameState.to_dict())

	GameState.reset()
	assert_eq(GameState.money, 0, "reset should clear state")

	GameState.from_dict(JSON.parse_string(json))
	assert_eq(GameState.money, 250)
	assert_true(GameState.flags.get("met_placeholder_npc", false))
	GameState.reset()
