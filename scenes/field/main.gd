extends Node2D
## M0 boot scene. Gray-box only — no gameplay (DEC-009, exit criterion 11).
func _ready() -> void:
	print("[boot] Hood JRPG — engine %s" % Engine.get_version_info().string)
	print("[boot] autoloads: EventBus=%s GameState=%s SaveSystem=%s" % [
		EventBus != null, GameState != null, SaveSystem != null])
