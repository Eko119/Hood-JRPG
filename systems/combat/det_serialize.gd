extends RefCounted
class_name DetSerialize
## Deterministic serialization for 64-bit integers (DEC-019).
##
## WHY THIS EXISTS — a verified bug, not a theoretical concern.
## Godot's JSON.parse_string returns every number as a float (TYPE_FLOAT).
## Doubles carry 53 bits of mantissa, so any int64 above 2^53 is silently
## rounded on the way back. Measured 2026-08-29:
##
##   RNG state written:  -5973960184894437042
##   after JSON:         -5973960184894437376     off by 334
##
## DEC-005 makes JSON the save format and DEC-012 requires RNG state to survive
## it exactly. Those two are in direct conflict for any value above 2^53, and a
## corrupted RNG state means a reloaded battle diverges from the one that was
## saved — silently, with no error.
##
## Fix: deterministic integers are written as STRINGS in JSON and parsed back
## with int(). Strings survive JSON exactly at any magnitude.
##
## SCOPE: use for any value where exactness is load-bearing — RNG state,
## fixed-point spatial values, deterministic counters. Ordinary display numbers
## (gold, level) may use plain JSON numbers; they are small and not replay-critical.

## Largest int a double represents exactly. Beyond this, plain JSON is lossy.
const SAFE_JSON_INT_MAX: int = 9007199254740992  # 2^53

static func enc_int(v: int) -> String:
	return str(v)

static func dec_int(v: Variant) -> int:
	# Accepts a String (correct path) or a number (legacy/hand-edited saves).
	# Numbers are still coerced so old data loads, but exactness is only
	# guaranteed for the string form.
	if v is String:
		return int(v)
	return int(v)

static func enc_vec(v: PackedInt64Array) -> Array:
	return [str(v[0]), str(v[1])]

static func dec_vec(a: Variant) -> PackedInt64Array:
	var arr: Array = a as Array
	return PackedInt64Array([dec_int(arr[0]), dec_int(arr[1])])

## True when a value would survive plain JSON without loss. Used by tests and by
## the validator to catch anyone reintroducing the bug.
static func is_json_safe(v: int) -> bool:
	return absi(v) <= SAFE_JSON_INT_MAX

## Encodes an ordered array of int64. Order is preserved exactly; callers that
## need deterministic iteration must sort BEFORE calling (DEC-004).
static func enc_int_array(a: Array) -> Array:
	var out: Array = []
	for v: Variant in a:
		out.append(str(v))
	return out

static func dec_int_array(a: Variant) -> Array:
	var out: Array = []
	for v: Variant in (a as Array):
		out.append(dec_int(v))
	return out
