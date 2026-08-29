extends Node
## Serializes GameState to JSON in user:// (DEC-005 — never ResourceSaver,
## because loading a .tres can resolve embedded script paths, which makes a
## hand-edited save file an execution vector).
##
## Migration exists from day one on purpose. Retrofitting it after players have
## saves means either breaking their saves or writing the migration anyway
## under worse conditions.

const SAVE_PATH_TEMPLATE: String = "user://save_%02d.json"

func save_game(slot: int) -> bool:
	var f := FileAccess.open(SAVE_PATH_TEMPLATE % slot, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot open slot %d for writing" % slot)
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	return true

func load_game(slot: int) -> bool:
	var path := SAVE_PATH_TEMPLATE % slot
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: slot %d is not valid JSON" % slot)
		return false
	GameState.from_dict(_migrate(parsed))
	return true

## Applies migrations in sequence until the save matches SAVE_VERSION.
func _migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("save_version", 0))
	while v < GameState.SAVE_VERSION:
		match v:
			_: break
		v += 1
	return d
