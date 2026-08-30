extends RefCounted
class_name ContentValidator
## Content validator (content-schema.md, M1 execution contract).
##
## Reports EVERY failure rather than stopping at the first, and exits non-zero on
## any error. Rejects invalid content — it never normalises, repairs, or invents.
##
## Three outcomes:
##   ERROR   content violates a rule derived from a LOCKED decision. Build fails.
##   WARN    suspicious but legal. Deliberate outliers are valid design.
##   BLOCKED a rule that CANNOT yet be written because its governing decision is
##           unresolved. Reported explicitly so the gap is visible rather than
##           silently absent. Does not fail the build; content that TOUCHES a
##           blocked field does.

const PLACEHOLDER_PREFIXES: Array[String] = ["test_", "placeholder_", "fixture_"]

var errors: Array[String] = []
var warnings: Array[String] = []
var by_type: Dictionary = {}          # dir name -> Array[{path, res}]
var all_ids: Dictionary = {}          # "type:id" -> path
var referenced_abilities: Dictionary = {}

const DIRS: Array[String] = ["abilities", "characters", "enemies", "equipment",
	"relationships", "status", "encounters"]

## Validates every resource under `root`. Returns {errors, warnings, blocked}.
## Pure: no quit(), no printing. The CLI wrapper and the test suite both call it,
## which is what lets deliberately-invalid fixtures be tested for FAILURE.
func validate(root: String) -> Dictionary:
	errors.clear(); warnings.clear(); all_ids.clear(); referenced_abilities.clear()
	for d in DIRS:
		by_type[d] = []
		for path in _find("%s/%s" % [root, d]):
			var r: Resource = load(path)
			if r == null:
				errors.append("%s: failed to load" % path)
				continue
			by_type[d].append({"path": path, "res": r})

	_check_types()
	for e in by_type["abilities"]:      _ability(e.path, e.res)
	for e in by_type["characters"]:     _character(e.path, e.res)
	for e in by_type["enemies"]:        _enemy(e.path, e.res)
	for e in by_type["equipment"]:      _equipment(e.path, e.res)
	for e in by_type["status"]:         _status(e.path, e.res)
	for e in by_type["relationships"]:  _relationship(e.path, e.res)
	for e in by_type["encounters"]:     _encounter(e.path, e.res)
	_cross_definition()
	_reachability()
	warnings.sort(); errors.sort()   # deterministic ordering (DEC-004)
	return {"errors": errors.duplicate(), "warnings": warnings.duplicate(),
			"blocked": PendingDecisions.blocked_ids(),
			"checked": _count()}

func _count() -> int:
	var t := 0
	for d in DIRS: t += by_type[d].size()
	return t

# --- (1) schema/type validity -------------------------------------------------
func _check_types() -> void:
	var expect := {
		"abilities": "AbilityDefinition", "characters": "CharacterDefinition",
		"enemies": "EnemyDefinition", "equipment": "EquipmentDefinition",
		"relationships": "RelationshipDefinition", "status": "StatusEffectDefinition",
		"encounters": "EncounterDefinition",
	}
	for d in DIRS:
		for e in by_type[d]:
			var ok := false
			match d:
				"abilities": ok = e.res is AbilityDefinition
				"characters": ok = e.res is CharacterDefinition
				"enemies": ok = e.res is EnemyDefinition
				"equipment": ok = e.res is EquipmentDefinition
				"relationships": ok = e.res is RelationshipDefinition
				"status": ok = e.res is StatusEffectDefinition
				"encounters": ok = e.res is EncounterDefinition
			if not ok:
				errors.append("%s: wrong type for data/%s/ (expected %s)" % [e.path, d, expect[d]])

# --- (2,3) required fields, identifier validity and uniqueness ----------------
func _identity(path: String, r: Resource, kind: String) -> void:
	var s := String(r.id)
	if s.is_empty():
		errors.append("%s: empty id" % path)
	elif not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(s):
		errors.append("%s: id '%s' must match ^[a-z][a-z0-9_]*$" % [path, s])
	else:
		var key := "%s:%s" % [kind, s]
		if all_ids.has(key):
			errors.append("%s: duplicate id '%s' (also %s)" % [path, s, all_ids[key]])
		else:
			all_ids[key] = path
	if "display_name" in r and String(r.display_name).is_empty():
		errors.append("%s: empty display_name" % path)

# --- (10) DEC-015 dependency blocking ----------------------------------------
func _blocked_fields(path: String, r: Resource) -> void:
	for prop in r.get_property_list():
		var n: String = prop["name"]
		if not n.begins_with(PendingDecisions.BLOCKED_FIELD_PREFIX):
			continue
		if r.get(n) != -1:
			errors.append("%s: '%s' is set to %s but its governing decision is unresolved. Leave it at -1." % [path, n, r.get(n)])

# --- (8,9) deterministic serialization + fixed-point representation ----------
func _fx(path: String, field: String, v: int, lo: int, hi: int, allow_zero: bool = true) -> void:
	if not allow_zero and v == 0:
		errors.append("%s: %s must be non-zero" % [path, field])
		return
	if v < lo or v > hi:
		errors.append("%s: %s = %d out of range [%d, %d]" % [path, field, v, lo, hi])
	if not DetSerialize.is_json_safe(v):
		errors.append("%s: %s = %d exceeds 2^53 and cannot survive JSON exactly (DEC-019)" % [path, field, v])
	if absi(v) >= Fixed.MUL_SAFE_LIMIT:
		errors.append("%s: %s = %d risks int64 overflow in Fixed.mul (DEC-017)" % [path, field, v])

func _ref(path: String, field: String, v: Variant, want: String) -> bool:
	if v == null:
		errors.append("%s: %s reference is null" % [path, field])
		return false
	var ok := false
	match want:
		"AbilityDefinition": ok = v is AbilityDefinition
		"StatusEffectDefinition": ok = v is StatusEffectDefinition
		"EnemyDefinition": ok = v is EnemyDefinition
	if not ok:
		errors.append("%s: %s must reference a %s" % [path, field, want])
	return ok

# --- per-type rules -----------------------------------------------------------
func _ability(p: String, r: AbilityDefinition) -> void:
	_identity(p, r, "ability"); _blocked_fields(p, r)
	_fx(p, "ability_resource_cost", r.ability_resource_cost, 0, BalanceConstants.RESOURCE_REGEN_CYCLE_CAP * 20)
	_fx(p, "range_fx", r.range_fx, 0, BalanceConstants.MAX_ABILITY_RANGE)
	_fx(p, "area_radius_fx", r.area_radius_fx, 0, BalanceConstants.MAX_ABILITY_RANGE)
	if r.target_kind < 0 or r.target_kind > AbilityDefinition.TargetKind.DIRECTION:
		errors.append("%s: target_kind out of enum range" % p)
	if r.flight_cycles < 0:
		errors.append("%s: flight_cycles must be >= 0" % p)
	if r.flight_cycles > 0 and not r.is_projectile:
		errors.append("%s: flight_cycles > 0 requires is_projectile" % p)
	if r.is_projectile and r.range_fx == 0:
		errors.append("%s: a projectile with range_fx 0 can never reach anything" % p)
	if r.target_kind == AbilityDefinition.TargetKind.SELF and r.range_fx != 0:
		errors.append("%s: SELF target must have range_fx 0" % p)
	if r.applies_status != null:
		_ref(p, "applies_status", r.applies_status, "StatusEffectDefinition")
	if r.base_power_fx == 0 and r.applies_status == null:
		errors.append("%s: ability does nothing (no power, no status)" % p)

func _character(p: String, r: CharacterDefinition) -> void:
	_identity(p, r, "character"); _blocked_fields(p, r)
	if r.max_hp <= 0: errors.append("%s: max_hp must be > 0" % p)
	_fx(p, "ability_resource_max", r.ability_resource_max, 0, 1 << 40)
	_fx(p, "move_range_per_cycle_fx", r.move_range_per_cycle_fx, 0, BalanceConstants.MAX_ABILITY_RANGE)
	_fx(p, "collision_radius_fx", r.collision_radius_fx,
		BalanceConstants.MIN_COLLISION_RADIUS, BalanceConstants.MAX_COLLISION_RADIUS)
	if r.max_level < 1: errors.append("%s: max_level must be >= 1" % p)
	if r.hp_per_level < 0: errors.append("%s: hp_per_level must be >= 0" % p)
	var seen: Dictionary = {}
	for s in r.equipment_slots:
		if seen.has(s): errors.append("%s: duplicate equipment slot '%s'" % [p, s])
		seen[s] = true
	for i in r.starting_abilities.size():
		if _ref(p, "starting_abilities[%d]" % i, r.starting_abilities[i], "AbilityDefinition"):
			referenced_abilities[String(r.starting_abilities[i].id)] = true

func _enemy(p: String, r: EnemyDefinition) -> void:
	_identity(p, r, "enemy"); _blocked_fields(p, r)
	if r.max_hp <= 0: errors.append("%s: max_hp must be > 0" % p)
	_fx(p, "ability_resource_max", r.ability_resource_max, 0, 1 << 40)
	_fx(p, "move_range_per_cycle_fx", r.move_range_per_cycle_fx, 0, BalanceConstants.MAX_ABILITY_RANGE)
	_fx(p, "collision_radius_fx", r.collision_radius_fx,
		BalanceConstants.MIN_COLLISION_RADIUS, BalanceConstants.MAX_COLLISION_RADIUS)
	if r.xp_reward < 0 or r.money_reward < 0: errors.append("%s: rewards must be >= 0" % p)
	if r.encounter_tier < 1: errors.append("%s: encounter_tier must be >= 1" % p)
	for i in r.abilities.size():
		if _ref(p, "abilities[%d]" % i, r.abilities[i], "AbilityDefinition"):
			var a: AbilityDefinition = r.abilities[i]
			referenced_abilities[String(a.id)] = true
			# An enemy that can never afford its own ability is a bug playtesting
			# rarely surfaces, because the enemy simply never uses it.
			if a.ability_resource_cost > r.ability_resource_max:
				errors.append("%s: ability '%s' costs %d but max resource is %d — unusable" % [
					p, a.id, a.ability_resource_cost, r.ability_resource_max])

func _equipment(p: String, r: EquipmentDefinition) -> void:
	_identity(p, r, "equipment"); _blocked_fields(p, r)
	if r.price < 0: errors.append("%s: price must be >= 0" % p)
	if not r.sellable and r.price > 0:
		warnings.append("%s: unsellable item has a price" % p)
	if r.tier < 1: errors.append("%s: tier must be >= 1" % p)
	if String(r.slot).is_empty(): errors.append("%s: empty slot" % p)
	for i in r.granted_abilities.size():
		if _ref(p, "granted_abilities[%d]" % i, r.granted_abilities[i], "AbilityDefinition"):
			referenced_abilities[String(r.granted_abilities[i].id)] = true

func _status(p: String, r: StatusEffectDefinition) -> void:
	_identity(p, r, "status"); _blocked_fields(p, r)
	if r.duration_cycles == 0:
		errors.append("%s: duration_cycles 0 is a no-op; use -1 for permanent" % p)
	if r.duration_cycles < -1:
		errors.append("%s: duration_cycles must be -1 or > 0" % p)
	if r.prevents_action and r.duration_cycles == -1 and r.removed_by.is_empty():
		errors.append("%s: permanent action-preventing status with no cure is a soft-lock" % p)
	for i in r.removed_by.size():
		if r.removed_by[i] == null:
			errors.append("%s: removed_by[%d] is null" % [p, i])

func _relationship(p: String, r: RelationshipDefinition) -> void:
	_identity(p, r, "relationship"); _blocked_fields(p, r)
	# DEC-014 locks the party at exactly two.
	if r.between.size() != 2:
		errors.append("%s: 'between' must name exactly 2 characters (DEC-014), got %d" % [p, r.between.size()])
	elif r.between[0] == r.between[1]:
		errors.append("%s: 'between' names the same character twice" % p)
	var prev := -1
	for i in r.tiers.size():
		var t: RelationshipTier = r.tiers[i]
		if t == null:
			errors.append("%s: tiers[%d] is null" % [p, i]); continue
		# Unordered tiers would make progression checks order-dependent (DEC-004).
		if t.threshold <= prev:
			errors.append("%s: tiers[%d] threshold %d not strictly ascending (prev %d)" % [p, i, t.threshold, prev])
		prev = t.threshold
		for j in t.unlocked_abilities.size():
			if _ref(p, "tiers[%d].unlocked_abilities[%d]" % [i, j], t.unlocked_abilities[j], "AbilityDefinition"):
				referenced_abilities[String(t.unlocked_abilities[j].id)] = true

func _encounter(p: String, r: EncounterDefinition) -> void:
	_identity(p, r, "encounter"); _blocked_fields(p, r)
	if r.enemies.size() != r.spawn_positions.size():
		errors.append("%s: %d enemies but %d spawn positions" % [p, r.enemies.size(), r.spawn_positions.size()])
		return
	if r.enemies.is_empty():
		errors.append("%s: encounter has no enemies" % p)
	var half: PackedInt64Array = r.arena_half_extent_fx
	if half.size() != 2 or half[0] <= 0 or half[1] <= 0:
		errors.append("%s: arena_half_extent_fx must be two positive fixed values" % p)
		return
	for i in r.enemies.size():
		_ref(p, "enemies[%d]" % i, r.enemies[i], "EnemyDefinition")
		var pos: PackedInt64Array = r.spawn_positions[i]
		if pos.size() != 2:
			errors.append("%s: spawn_positions[%d] must have 2 components" % [p, i]); continue
		for axis in 2:
			_fx(p, "spawn_positions[%d][%d]" % [i, axis], pos[axis],
				-BalanceConstants.MAX_WORLD_COORD, BalanceConstants.MAX_WORLD_COORD)
			if absi(pos[axis]) > half[axis]:
				errors.append("%s: spawn_positions[%d] axis %d is outside the arena" % [p, i, axis])
		# Overlapping spawns would make the first execution tick's collision
		# resolution decide the layout, which is not authored intent.
		for j in range(i + 1, r.enemies.size()):
			var q: PackedInt64Array = r.spawn_positions[j]
			if q.size() == 2 and FixedVec.equals(pos, q):
				errors.append("%s: enemies %d and %d spawn on the same point" % [p, i, j])

# --- (7) cross-definition invariants -----------------------------------------
func _cross_definition() -> void:
	# Constitution §6 / DEC-016: relationships must NOT be the sole source of
	# numeric progression. If every character has flat growth while relationships
	# hand out modifiers, that principle is violated.
	var any_char_grows := false
	for e in by_type["characters"]:
		var c: CharacterDefinition = e.res
		if c.hp_per_level > 0 or c.ability_resource_per_level_fx > 0:
			any_char_grows = true
	var rel_gives_numbers := false
	for e in by_type["relationships"]:
		for t in (e.res as RelationshipDefinition).tiers:
			if t != null and not t.passive_modifiers.is_empty():
				rel_gives_numbers = true
	if rel_gives_numbers and not any_char_grows and not by_type["characters"].is_empty():
		errors.append("cross: relationships supply numeric modifiers but no character has level growth — violates DEC-016 (relationships must not be the sole numeric source)")

	# (11) forbidden/invented content detection.
	# The two characters, their bond, and the world are unresolved creative design
	# (design-constitution.md §9, DEC-008). Any non-placeholder content of those
	# types would mean someone invented them.
	for d in ["characters", "relationships"]:
		for e in by_type[d]:
			var s := String(e.res.id)
			var is_placeholder := false
			for pre in PLACEHOLDER_PREFIXES:
				if s.begins_with(pre): is_placeholder = true
			if not is_placeholder:
				errors.append("%s: '%s' is non-placeholder %s content, but the characters and their bond are unresolved creative design (DEC-008). Prefix with test_/placeholder_/fixture_ or remove." % [e.path, s, d])

# --- reachability -------------------------------------------------------------
func _reachability() -> void:
	for e in by_type["abilities"]:
		var a: AbilityDefinition = e.res
		if not referenced_abilities.has(String(a.id)):
			warnings.append("%s: ability '%s' is not reachable — no character, enemy, equipment, or relationship tier grants it" % [e.path, a.id])
		if a.is_cooperative:
			var via_rel := false
			for re in by_type["relationships"]:
				for t in (re.res as RelationshipDefinition).tiers:
					if t == null: continue
					for ab in t.unlocked_abilities:
						if ab != null and ab.id == a.id: via_rel = true
			if not via_rel:
				warnings.append("%s: cooperative ability '%s' is not unlocked by any relationship tier (Constitution §5)" % [e.path, a.id])

# --- reporting ----------------------------------------------------------------
func _find(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null: return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		var full := dir_path.path_join(n)
		if dir.current_is_dir(): out.append_array(_find(full))
		elif n.ends_with(".tres"): out.append(full)
		n = dir.get_next()
	dir.list_dir_end()
	out.sort()   # deterministic report ordering (DEC-004)
	return out
