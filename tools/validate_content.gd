extends SceneTree
## CLI wrapper. Runs ContentValidator over res://data and exits non-zero on any
## error. All rule logic lives in ContentValidator so the test suite can drive
## the same code against deliberately-invalid fixtures.
func _init() -> void:
	var v := ContentValidator.new()
	var r: Dictionary = v.validate("res://data")
	print("[validator] checked %d resource(s)" % r["checked"])
	print("[validator] %d BLOCKED rule group(s) — cannot be written until decided:" % r["blocked"].size())
	for id: String in r["blocked"]:
		var e: Dictionary = PendingDecisions.REGISTRY[id]
		print("  BLOCKED %s  %s" % [id, e["question"]])
		for b: String in e["blocks"]:
			print("            - %s" % b)
	for w: String in r["warnings"]: print("  WARN  %s" % w)
	for e: String in r["errors"]:   print("  ERROR %s" % e)
	print("[validator] %d error(s), %d warning(s), %d blocked group(s)" % [
		r["errors"].size(), r["warnings"].size(), r["blocked"].size()])
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/validation_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(r, "\t")); f.close()
	quit(1 if r["errors"].size() > 0 else 0)
