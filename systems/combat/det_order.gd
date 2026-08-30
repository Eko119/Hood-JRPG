extends RefCounted
class_name DetOrder
## Deterministic ordering helpers (DEC-020).
##
## WHY THIS EXISTS — a verified bug, found by probing rather than reasoning.
## Godot's StringName comparison operators compare the INTERNAL POINTER, not the
## string content, because StringName exists to make equality checks cheap.
## Measured 2026-08-29 on Godot 4.7:
##
##   [&"zebra", &"alpha", &"mango", &"beta"].sort()
##     -> [&"beta", &"mango", &"alpha", &"zebra"]        NOT lexicographic
##   StringName("m_" + "one") < StringName("m_" + "two")
##     -> false                                          lexically should be true
##
## Pointer values depend on allocation order, which depends on load order, which
## is not stable across processes or machines. DEC-004 requires ties to break on
## stable id, and every id in this project is a StringName. Sorting them directly
## would produce a resolver that passes every test in one process and diverges on
## replay — the worst failure shape available.
##
## Note how the bug hides: &"alpha" < &"zebra" happens to return true, because
## literals are interned in source order. Small tests look fine.
##
## RULE: never compare or sort StringName for ordering. Convert with String()
## first, or use the helpers here.

## Lexicographic sort of ids. Always use this for deterministic iteration.
static func sorted_ids(ids: Array) -> Array:
	var as_strings: Array[String] = []
	for i in ids:
		as_strings.append(String(i))
	as_strings.sort()
	return as_strings

## Deterministic three-way comparison of two ids. The tie-break primitive the
## resolver uses wherever two entities would otherwise be interchangeable.
static func compare_ids(a: StringName, b: StringName) -> int:
	var sa := String(a)
	var sb := String(b)
	if sa < sb: return -1
	if sa > sb: return 1
	return 0

## Sorts objects carrying an `id` property into a stable, content-based order.
static func sort_by_id(items: Array) -> Array:
	var out := items.duplicate()
	out.sort_custom(func(x, y): return String(x.id) < String(y.id))
	return out
