extends RefCounted
class_name Fixed
## Q16.16 fixed-point scalar math for the combat domain (DEC-017).
##
## WHY THIS EXISTS. Continuous space (design-constitution.md §3) means positions
## are fractional. Floats cannot carry that job here: IEEE-754 results depend on
## compiler flags, SIMD paths, x87 extended precision, and fused multiply-add
## availability, so the same battle can resolve differently on two machines. The
## simulator's replay guarantee (DEC-012) and any future networked play both die
## on that. Integers do not have the problem — the same integer ops give the same
## answer everywhere, always.
##
## HONEST FRAMING. Fixed-point is not more *accurate* than float. 0.1 is not
## exactly representable here either (0.1 * 65536 = 6553.6, stored as 6554). What
## it is, is *exactly reproducible*: identical inputs give bit-identical outputs
## on every platform, every run, forever. Reproducibility is the property the
## determinism contract needs. Accuracy is not.
##
## A value is stored as an int equal to real_value * 65536.
## GDScript ints are 64-bit, which leaves ample headroom — see mul() for the
## overflow bound.

const SHIFT: int = 16
const ONE: int = 1 << SHIFT      # 65536
const HALF: int = ONE >> 1

## Largest magnitude safe for mul(): sqrt(2^63) ≈ 3.04e9 in raw units,
## i.e. roughly ±46,000 world units. Battlefields are ~100 units, so this is
## about three orders of magnitude of headroom.
const MUL_SAFE_LIMIT: int = 3_037_000_499

static func from_int(i: int) -> int:
	return i << SHIFT

## Authoring and presentation only. NEVER call this inside the resolver — a float
## entering the domain layer is the exact hazard this class exists to prevent.
static func from_float(f: float) -> int:
	return int(round(f * ONE))

## Presentation only. The renderer converts at the boundary; the domain never does.
static func to_float(x: int) -> float:
	return float(x) / float(ONE)

static func mul(a: int, b: int) -> int:
	# Shift is arithmetic, so negatives floor rather than truncate. That is
	# asymmetric around zero but perfectly deterministic, which is what matters.
	return (a * b) >> SHIFT

static func div(a: int, b: int) -> int:
	assert(b != 0, "Fixed.div by zero")
	return (a << SHIFT) / b

## Integer square root by Newton's method — deterministic, no float anywhere.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x: int = n
	var y: int = (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x

## sqrt of a fixed value. real_sqrt(x/ONE) * ONE == isqrt(x * ONE).
static func sqrt_fx(x: int) -> int:
	if x <= 0:
		return 0
	return isqrt(x << SHIFT)

static func abs_fx(x: int) -> int:
	return -x if x < 0 else x

static func min_fx(a: int, b: int) -> int:
	return a if a < b else b

static func max_fx(a: int, b: int) -> int:
	return a if a > b else b

static func clamp_fx(x: int, lo: int, hi: int) -> int:
	return min_fx(max_fx(x, lo), hi)

## Human-readable for logs and failure reports. Presentation, not domain.
static func to_string_fx(x: int, decimals: int = 3) -> String:
	return String.num(to_float(x), decimals)
