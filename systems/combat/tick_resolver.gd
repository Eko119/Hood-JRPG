extends RefCounted
class_name TickResolver
## Applies one tick's outcomes to the authoritative state.
##
## Q1 IS THE ENTIRE DESIGN OF THIS FILE.
##
##   "tick outcomes must be evaluated from the authoritative state at the
##    beginning of that tick before the resulting state transitions are applied"
##   "Do not use entity ID, speed, iteration order, array order, or another
##    arbitrary tie-breaker to cancel one of those outcomes"
##   "Internal iteration order must not change the authoritative result"
##
## HOW THAT IS GUARANTEED, structurally rather than by discipline:
##
## 1. Outcomes are computed elsewhere, against an immutable snapshot. This file
##    never reads the live state to decide anything — it only accumulates.
## 2. Every accumulation is integer addition, which is exactly associative and
##    commutative (DEC-017 gives us integers precisely so this holds). Summing
##    damage in any order yields the same total.
## 3. Defeat is evaluated ONCE, after all accumulation, by comparing final hp to
##    zero. An entity is never removed mid-accumulation, so it can never have
##    its own outcome cancelled by being processed second.
## 4. Any transition that is inherently NOT commutative — two outcomes writing
##    different positions to one entity — is reported as a CONFLICT rather than
##    resolved by order. Silently taking the last write would make array order a
##    gameplay rule, which Q1 forbids.

## Applies `outcomes` to `state` in place. Returns tick events and any conflicts.
static func apply_tick(state: BattleState, outcomes: Array, tick: int) -> Dictionary:
	var damage_by: Dictionary = {}      # String(id) -> summed fixed-point damage
	var resource_delta: Dictionary = {} # String(id) -> summed fixed-point delta
	var position_writes: Dictionary = {}# String(id) -> Array[PackedInt64Array]
	var status_writes: Dictionary = {}  # String(id) -> Array[{id, cycles}]
	var conflicts: Array = []

	# --- Accumulate. Order-independent by construction (integer addition). ---
	for o: CombatOutcome in outcomes:
		var t := String(o.target_id)
		match o.kind:
			CombatOutcome.Kind.DAMAGE:
				damage_by[t] = int(damage_by.get(t, 0)) + o.amount
			CombatOutcome.Kind.SPEND_RESOURCE:
				resource_delta[t] = int(resource_delta.get(t, 0)) - o.amount
			CombatOutcome.Kind.REGEN_RESOURCE:
				resource_delta[t] = int(resource_delta.get(t, 0)) + o.amount
			CombatOutcome.Kind.SET_POSITION:
				if not position_writes.has(t):
					position_writes[t] = []
				position_writes[t].append(o.position)
			CombatOutcome.Kind.APPLY_STATUS:
				if not status_writes.has(t):
					status_writes[t] = []
				status_writes[t].append({"id": o.status_id, "cycles": o.status_cycles})

	var events: Array = []

	# --- Apply, iterating in canonical order for REPORTING only. The values
	# applied were fixed during accumulation, so this order cannot change them.
	for key: String in DetOrder.sorted_ids(damage_by.keys()):
		var e: CombatEntity = state.get_entity(StringName(key))
		if e == null: continue
		var dmg: int = damage_by[key]
		e.hp -= dmg
		events.append({"tick": tick, "type": "damage", "target": key, "amount": dmg, "hp_after": e.hp})

	for key: String in DetOrder.sorted_ids(resource_delta.keys()):
		var e: CombatEntity = state.get_entity(StringName(key))
		if e == null: continue
		e.ability_resource = Fixed.clamp_fx(e.ability_resource + int(resource_delta[key]), 0, e.ability_resource_max)
		events.append({"tick": tick, "type": "resource", "target": key, "value_after": e.ability_resource})

	for key: String in DetOrder.sorted_ids(position_writes.keys()):
		var writes: Array = position_writes[key]
		# Two different destinations for one entity in one tick is not resolvable
		# without letting order decide. Q1 forbids that, so it is an error.
		var distinct: Array = []
		for w: PackedInt64Array in writes:
			var dup := false
			for d: PackedInt64Array in distinct:
				if FixedVec.equals(w, d): dup = true
			if not dup: distinct.append(w)
		if distinct.size() > 1:
			conflicts.append("tick %d: %d conflicting SET_POSITION writes for '%s' — order must not decide (Q1)" % [tick, distinct.size(), key])
			continue
		var e: CombatEntity = state.get_entity(StringName(key))
		if e == null: continue
		e.position = PackedInt64Array([distinct[0][0], distinct[0][1]])
		events.append({"tick": tick, "type": "move", "target": key,
			"to": [str(e.position[0]), str(e.position[1])]})

	for key: String in DetOrder.sorted_ids(status_writes.keys()):
		var e: CombatEntity = state.get_entity(StringName(key))
		if e == null: continue
		for w: Dictionary in status_writes[key]:
			# StatusEffectDefinition.stacks exists, but NO locked contract says
			# what happens when a non-stacking status is applied to an entity
			# that already carries it — refresh, ignore, or take the max
			# (OPEN-6). Appending unconditionally would silently choose "stack
			# always", so re-application is reported instead of resolved.
			var already := false
			for existing: Dictionary in e.statuses:
				if existing["id"] == w["id"]: already = true
			if already:
				conflicts.append("tick %d: status '%s' re-applied to '%s' — stacking semantics undetermined (OPEN-6)" % [tick, String(w["id"]), key])
				continue
			e.statuses.append({"id": w["id"], "remaining_cycles": w["cycles"]})
			events.append({"tick": tick, "type": "status", "target": key, "status": String(w["id"])})
		# Keep the list canonically ordered so serialization is stable (DEC-004).
		e.statuses.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return String(x["id"]) < String(y["id"]))

	# --- Defeat evaluation: ONCE, after all accumulation. This is what makes
	# simultaneous mutual destruction work (Q1). Both entities reach hp <= 0
	# from outcomes computed against the same tick-start snapshot, and both are
	# marked DEFEATED. Neither cancels the other.
	for e: CombatEntity in state.entities_in_canonical_order():
		if not e.defeated and e.hp <= 0:
			e.defeated = true
			e.hp = 0
			events.append({"tick": tick, "type": "defeated", "target": String(e.id)})

	return {"events": events, "conflicts": conflicts}
