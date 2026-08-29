extends RefCounted
class_name FixedVec
## 2D vectors in Q16.16 fixed point (DEC-017).
##
## Represented as a two-element PackedInt64Array rather than a class instance:
## value semantics, cheap to copy, trivially serializable into the save file
## (DEC-005), and no reference aliasing bugs where two entities accidentally
## share one position object.

static func make(x: int, y: int) -> PackedInt64Array:
	return PackedInt64Array([x, y])

static func from_ints(x: int, y: int) -> PackedInt64Array:
	return PackedInt64Array([Fixed.from_int(x), Fixed.from_int(y)])

static func zero() -> PackedInt64Array:
	return PackedInt64Array([0, 0])

static func add(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	return PackedInt64Array([a[0] + b[0], a[1] + b[1]])

static func sub(a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	return PackedInt64Array([a[0] - b[0], a[1] - b[1]])

static func scale(v: PackedInt64Array, s: int) -> PackedInt64Array:
	return PackedInt64Array([Fixed.mul(v[0], s), Fixed.mul(v[1], s)])

static func dot(a: PackedInt64Array, b: PackedInt64Array) -> int:
	return Fixed.mul(a[0], b[0]) + Fixed.mul(a[1], b[1])

## Squared length. Prefer this for comparisons — it avoids sqrt entirely, which
## is both faster and sidesteps sqrt's rounding on every call.
static func length_sq(v: PackedInt64Array) -> int:
	return Fixed.mul(v[0], v[0]) + Fixed.mul(v[1], v[1])

static func length(v: PackedInt64Array) -> int:
	return Fixed.sqrt_fx(length_sq(v))

static func distance(a: PackedInt64Array, b: PackedInt64Array) -> int:
	return length(sub(a, b))

static func distance_sq(a: PackedInt64Array, b: PackedInt64Array) -> int:
	return length_sq(sub(a, b))

## True when a and b are within `radius`. Uses squared comparison so no sqrt
## rounding can flip a borderline hit — the kind of one-unit discrepancy that
## makes a replay diverge.
static func within(a: PackedInt64Array, b: PackedInt64Array, radius: int) -> bool:
	return distance_sq(a, b) <= Fixed.mul(radius, radius)

static func normalized(v: PackedInt64Array) -> PackedInt64Array:
	var len_fx: int = length(v)
	if len_fx == 0:
		return zero()
	return PackedInt64Array([Fixed.div(v[0], len_fx), Fixed.div(v[1], len_fx)])

## Moves `from` toward `to` by at most `max_step`, stopping exactly on arrival.
## The movement primitive the resolver's tick phase 2 is built on.
static func move_toward(from: PackedInt64Array, to: PackedInt64Array, max_step: int) -> PackedInt64Array:
	var delta: PackedInt64Array = sub(to, from)
	var dist: int = length(delta)
	if dist <= max_step or dist == 0:
		return PackedInt64Array([to[0], to[1]])
	return add(from, scale(normalized(delta), max_step))

static func equals(a: PackedInt64Array, b: PackedInt64Array) -> bool:
	return a[0] == b[0] and a[1] == b[1]

static func to_string_v(v: PackedInt64Array) -> String:
	return "(%s, %s)" % [Fixed.to_string_fx(v[0]), Fixed.to_string_fx(v[1])]
