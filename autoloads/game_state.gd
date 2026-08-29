extends Node
## The entire save-worthy state of the game. Nothing else stores persistent data.
##
## Keeping this as the single owner of persistent state is what makes DEC-005
## workable: the save file is literally this object serialized. If party data
## also lived in a battle scene and inventory data in a menu, "what goes in the
## save?" would become a judgement call made freshly every time — which is how
## save bugs get in.

const SAVE_VERSION: int = 1

var party: Array[Dictionary] = []
var inventory: Dictionary = {}
var money: int = 0
var flags: Dictionary = {}
var current_map: StringName = &""
var spawn_point: StringName = &""
var playtime_seconds: float = 0.0

func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"party": party,
		"inventory": inventory,
		"money": money,
		"flags": flags,
		"current_map": String(current_map),
		"spawn_point": String(spawn_point),
		"playtime_seconds": playtime_seconds,
	}

func from_dict(d: Dictionary) -> void:
	party.assign(d.get("party", []))
	inventory = d.get("inventory", {})
	money = int(d.get("money", 0))
	flags = d.get("flags", {})
	current_map = StringName(d.get("current_map", ""))
	spawn_point = StringName(d.get("spawn_point", ""))
	playtime_seconds = float(d.get("playtime_seconds", 0.0))

func reset() -> void:
	party.clear()
	inventory.clear()
	money = 0
	flags.clear()
	current_map = &""
	spawn_point = &""
	playtime_seconds = 0.0
