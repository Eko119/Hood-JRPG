extends RefCounted
class_name BattleState
## The authoritative combat state. DEC-014: the combat domain determines what
## happens; the presentation layer only displays it. Nothing here touches the
## scene tree (DEC-001).
##
## CONTRACT TRACE
##   TICKS_PER_WINDOW = 10        DEC-015 (approved), Q3
##   FIRST_TICK / LAST_TICK       DEC-015 "ticks are indexed 1 through 10"
##   INTENT_HORIZON_WINDOWS = 1   Q2
##   rng_state                    DEC-004, DEC-012, DEC-019
##   entities                     M1 definitions

## DEC-015: exactly 10 discrete ticks per execution window. There is no tick 11
## in the same window, and no sub-tick layer.
const TICKS_PER_WINDOW: int = 10
const FIRST_TICK: int = 1
const LAST_TICK: int = 10

## Q2: enemy intent is visible for exactly the immediately upcoming window.
const INTENT_HORIZON_WINDOWS: int = 1

enum Phase { PLANNING, EXECUTING }

var entities: Array = []          # Array[CombatEntity]
var rng_state: int = 0
var window_index: int = 0
var tick_index: int = 0           # 0 while planning; 1..10 during execution
var phase: Phase = Phase.PLANNING
var arena_half_extent_fx: PackedInt64Array = PackedInt64Array([0, 0])

## Deep copy — the tick-start snapshot Q1 requires.
func clone() -> BattleState:
	var s := BattleState.new()
	s.entities = []
	for e in entities:
		s.entities.append(e.clone())
	s.rng_state = rng_state
	s.window_index = window_index
	s.tick_index = tick_index
	s.phase = phase
	s.arena_half_extent_fx = PackedInt64Array([arena_half_extent_fx[0], arena_half_extent_fx[1]])
	return s

## Entities in canonical order. DEC-020: never sort StringName directly.
## This ordering exists for REPORTING and for mechanics that the contract says
## require ordering. Q1 forbids it from deciding whether a lethal outcome stands.
func entities_in_canonical_order() -> Array:
	return DetOrder.sort_by_id(entities)

func get_entity(entity_id: StringName) -> CombatEntity:
	for e in entities:
		if e.id == entity_id:
			return e
	return null

func living() -> Array:
	var out: Array = []
	for e in entities_in_canonical_order():
		if not e.defeated:
			out.append(e)
	return out

## Stable content hash for cross-process determinism checks. Built from the
## canonical serialization, so it is order-independent by construction.
func state_hash() -> String:
	return JSON.stringify(to_dict()).sha256_text()

func to_dict() -> Dictionary:
	var ents: Array = []
	for e in entities_in_canonical_order():
		ents.append(e.to_dict())
	return {
		"entities": ents,
		"rng_state": DetSerialize.enc_int(rng_state),   # DEC-019
		"window_index": window_index,
		"tick_index": tick_index,
		"phase": int(phase),
		"arena_half_extent_fx": DetSerialize.enc_vec(arena_half_extent_fx),
	}

static func from_dict(d: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.entities = []
	for e in (d["entities"] as Array):
		s.entities.append(CombatEntity.from_dict(e))
	s.rng_state = DetSerialize.dec_int(d["rng_state"])
	s.window_index = int(d["window_index"])
	s.tick_index = int(d["tick_index"])
	s.phase = d["phase"] as Phase
	s.arena_half_extent_fx = DetSerialize.dec_vec(d["arena_half_extent_fx"])
	return s

## DEC-004 / DEC-012: the RNG is carried in state, never global. Callers take a
## generator seeded from the stored state, use it, then write the state back.
func make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.state = rng_state
	return rng

func store_rng(rng: RandomNumberGenerator) -> void:
	rng_state = rng.state
