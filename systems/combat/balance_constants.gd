extends RefCounted
class_name BalanceConstants
## Named balance knobs for the combat domain. CLAUDE.md forbids magic numbers
## here: every number a designer might want to turn lives in this file with a
## name, so it is findable.
##
## UNIT DISCIPLINE (important, and derived rather than chosen):
##   DEC-014 locks the combat CYCLE — plan, execute, produce next state. Cycles
##   therefore exist and quantities may be denominated per cycle.
##   DEC-015 (the tick subdivision INSIDE the execution window) is only PROPOSED.
##   Ticks therefore do NOT exist yet, and no quantity here may be per-tick.
## Every constant below is per-cycle or per-distance. Nothing is per-tick.

## --- DEC-018: positional regeneration -------------------------------------
## DEC-018 locks that ability_resource regenerates "as a character moves or
## waits". Both channels are named in the decision, so both exist. The VALUES
## are unturned placeholders — balance, not design — and are expected to change
## once the simulator can exercise them.

## Fixed-point ability_resource restored per world unit of distance moved.
const RESOURCE_REGEN_PER_UNIT_MOVED: int = 3277          # ~0.05 in Q16.16

## Fixed-point ability_resource restored for a cycle spent waiting (not moving).
const RESOURCE_REGEN_PER_WAIT_CYCLE: int = 65536         # 1.0 in Q16.16

## Upper bound on regeneration in a single cycle, whatever the channel mix.
## Prevents a movement-maximising degenerate strategy from outpacing all costs.
const RESOURCE_REGEN_CYCLE_CAP: int = 196608             # 3.0 in Q16.16

## --- Spatial bounds (DEC-017) ---------------------------------------------
## Validation bounds, not gameplay tuning. Fixed.MUL_SAFE_LIMIT is the hard
## overflow ceiling; these keep authored content far inside it.

const MAX_WORLD_COORD: int = 655360000    # 10,000 units
const MAX_ABILITY_RANGE: int = 6553600    # 100 units
const MAX_COLLISION_RADIUS: int = 655360  # 10 units
const MIN_COLLISION_RADIUS: int = 6553    # ~0.1 units
