extends SceneTree
## Content validator (claude/content-schema.md). Runs headless, reports EVERY
## failure rather than stopping at the first, and exits non-zero on any error.
##
## This is the tool that makes bulk AI-generated content safe. A model writing
## 500 items will produce some that are subtly wrong — a dangling reference, a
## duplicate id, an enemy that can never afford its own skill. No amount of
## careful prompting drives that to zero. A validator that runs in seconds and
## fails loudly makes the cost of it near zero instead.
##
## M0 scope: EnemyDefinition only. Each new type adds its rules HERE BEFORE any
## content of that type is authored (content-schema.md, "Adding a new type").

var errors: Array[String] = []
var warnings: Array[String] = []

func _init() -> void:
	var seen_ids: Dictionary = {}
	var count := 0

	for path in _find_resources("res://data/enemies"):
		count += 1
		var res: Resource = load(path)
		if res == null:
			errors.append("%s: failed to load" % path)
			continue
		_validate_enemy(res, path, seen_ids)

	_report(count)
	quit(1 if errors.size() > 0 else 0)

func _validate_enemy(res: Resource, path: String, seen_ids: Dictionary) -> void:
	# --- Structural: identity must be present, well-formed, and unique. ---
	var id_str := String(res.id)
	if id_str.is_empty():
		errors.append("%s: empty id" % path)
	elif not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(id_str):
		errors.append("%s: id '%s' must match ^[a-z][a-z0-9_]*$" % [path, id_str])
	elif seen_ids.has(id_str):
		errors.append("%s: duplicate id '%s' (also in %s)" % [path, id_str, seen_ids[id_str]])
	else:
		seen_ids[id_str] = path

	if res.display_name.is_empty():
		errors.append("%s: empty display_name" % path)

	# --- Semantic: values that parse fine but mean something impossible. ---
	for stat in ["max_hp", "attack", "defense", "speed"]:
		if res.get(stat) <= 0:
			errors.append("%s: %s must be > 0 (got %d)" % [path, stat, res.get(stat)])
	if res.max_mp < 0:
		errors.append("%s: max_mp must be >= 0" % path)
	if res.xp_reward < 0 or res.money_reward < 0:
		errors.append("%s: rewards must be >= 0" % path)
	if res.encounter_tier < 1:
		errors.append("%s: encounter_tier must be >= 1" % path)

	# --- Balance sanity: warn, never fail. Deliberate outliers are valid design,
	# but they should be deliberate rather than accidental. ---
	if res.encounter_tier == 1 and res.max_hp > 200:
		warnings.append("%s: tier 1 enemy with %d HP looks out of band" % [path, res.max_hp])

func _find_resources(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_find_resources(full))
		elif name.ends_with(".tres"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out

func _report(count: int) -> void:
	print("[validator] checked %d resource(s)" % count)
	for w in warnings:
		print("  WARN  %s" % w)
	for e in errors:
		print("  ERROR %s" % e)
	print("[validator] %d error(s), %d warning(s)" % [errors.size(), warnings.size()])

	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/validation_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"checked": count, "errors": errors, "warnings": warnings,
		}, "\t"))
		f.close()
