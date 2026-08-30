# M2 Open Semantics — Unresolved Combat Questions

**Status:** blocking completion of the resolver. Raised 2026-08-29 during M2 implementation.

DEC-015's approval text says: *"If behavior required by the resolver cannot be derived from those existing contracts plus the 10-tick model, stop and report the ambiguity instead of choosing a default."* This document is that report.

Each entry gives: the exact ambiguity, the contract clauses consulted that fail to determine it, the smallest decision required, and what would otherwise have been guessed.

**What was built anyway.** Everything determined by locked contracts is implemented and tested — state model, serialization, the 10-tick window loop, tick-start snapshot discipline, simultaneous mutual destruction, order-independence, intent horizon, event timeline, and cross-process determinism. The gap is specifically the mapping from committed intents to per-tick outcomes. `WindowResolver.execute_window` takes that mapping as an explicit `Callable` seam rather than containing a guessed one.

---

## OPEN-1 — Which tick does a planned non-projectile ability resolve on?

**Ambiguity.** A player commits "use Strike on the enemy" during Planning. The window is ticks 1–10. Nothing states which tick the strike lands on.

**Clauses consulted, and why each fails.** DEC-014 establishes plan-then-execute but says nothing about intra-window placement. DEC-015 fixes the window at 10 ticks and forbids inventing a physics or interpolation model; it does not place actions. Q1 defines *how* a tick resolves, not *which* tick an action occupies. Q3 gives window length only. `AbilityDefinition` carries no timing field — `blocked_windup_ticks` and `blocked_recovery_ticks` exist precisely as markers for this gap and hold no authorized value.

**Smallest decision.** Either one fixed resolution tick for all abilities, or a per-ability authored tick with a stated legal range.

**Would have been guessed.** Tick 1 versus tick 10 versus something in between. Not cosmetic: it decides whether a target who moves during the window can escape a melee attack aimed at where they stood during Planning — which is the central tension of the whole combat model.

---

## OPEN-2 — How is per-cycle movement distributed across the 10 ticks?

**Ambiguity.** `move_range_per_cycle_fx` is a distance per cycle. With 10 ticks, the per-tick motion is undefined.

**Clauses consulted.** DEC-015 explicitly does not authorize inventing a velocity or interpolation model. DEC-017 fixes the arithmetic but not the schedule. M1 denominated movement per cycle precisely because ticks were unapproved at that time.

**Smallest decision.** Constant rate (`range / 10` per tick), all movement on tick 1, arrival on tick 10, or an authored profile.

**Would have been guessed.** Constant rate is the most defensible — any other distribution requires specifying a curve, which is the forbidden interpolation model — but it is still a choice, and it determines where every entity is at every tick, and therefore the outcome of every range and area check. **Disclosure:** constant rate appears in `test_m2_resolver.gd` and `determinism_probe.gd` as *test scaffolding only*. It is not present in the resolver and is not a game rule.

---

## OPEN-3 — Where is a projectile during flight, and does it interact en route?

**Ambiguity.** `is_projectile` and `flight_cycles` are locked. A projectile with `flight_cycles = 1` impacts one cycle later. Whether it occupies intermediate positions, and whether it can hit something it passes through, is undefined.

**Clauses consulted.** `arco-combat-analysis.md` records that in Arco projectiles travel visibly and can narrowly miss — but that document describes the reference game, and adopting a behaviour from it is a design decision, not a derivation. DEC-015 forbids inventing a collision model. `blocked_projectile_speed_per_tick` holds no authorized value.

**Smallest decision.** Is a projectile (a) abstract until impact, or (b) a positioned entity that can collide before reaching its destination? If (b), the collision rule is needed too.

**Would have been guessed.** Whether "threading a shot between two enemies" exists as a tactical verb at all.

---

## OPEN-4 — Do a defeated entity's later outcomes in the same window still resolve?

**Ambiguity.** Q1 resolves simultaneous lethality *within one tick*. It does not address an entity defeated at tick 3 whose plan also included action at tick 7.

**Clauses consulted.** Q1's scope is explicitly same-tick. Nothing elsewhere addresses cross-tick cancellation.

**Smallest decision.** On defeat, are that entity's remaining outcomes for the current window cancelled, or do already-committed actions still resolve?

**Would have been guessed.** The sharpest case is a projectile already in flight from a caster who has since been defeated — cancelling it and letting it land are both coherent, and they feel very different to play.

---

## OPEN-5 — What happens when two entities overlap during movement?

**Ambiguity.** `collision_radius_fx` exists on both character and enemy definitions but is never consumed by any locked rule.

**Clauses consulted.** DEC-015 explicitly does not authorize inventing a collision model. DEC-017 supplies the geometry (`FixedVec.within` compares squared distance exactly) but no rule about what overlap *means*.

**Smallest decision.** Does overlap block movement, push, do nothing, or something else?

**Would have been guessed.** Whether body-blocking is a tactical verb — significant for a two-character pair whose bond is meant to be mechanical, since "one character protects another's movement" is named in Constitution §5.

---

## OPEN-6 — Re-applying a non-stacking status

**Ambiguity.** `StatusEffectDefinition.stacks` exists. Nothing says what happens when a status is applied to an entity that already carries it and `stacks` is false.

**Smallest decision.** Refresh the duration, ignore the new application, or take the maximum remaining.

**Current behaviour.** `TickResolver` records a CONFLICT and applies nothing on re-application, rather than silently appending. An earlier draft of this file appended unconditionally, which would have silently chosen "always stack" — caught and corrected before commit.

---

## OPEN-7 — What counts as "waiting" for positional regeneration?

**Ambiguity.** DEC-018 locks that `ability_resource` regenerates "as a character moves or waits", and `BalanceConstants` names both channels. Whether an entity that moves a very small distance counts as moving, waiting, or both is undefined, as is whether the two channels are exclusive.

**Smallest decision.** Define "waiting" — zero committed movement, or movement below a threshold — and state whether the channels are exclusive or additive under the existing cycle cap.

---

## Minor derivations made, flagged for confirmation

Not ambiguities, but places the implementation extended slightly past literal text:

1. **`ability_resource` is clamped to `[0, ability_resource_max]`.** `ability_resource_max` is defined by the M1 contract; negative or over-max values are not meaningful. Clamping is treated as implied.
2. **Defeat is `hp <= 0`.** Q1 speaks of "lethal outcomes" without defining lethality; hp reaching zero is the only available reading given the M1 stat block.
3. **Status lists are sorted by id on write.** Required for stable serialization under DEC-004; no gameplay effect.
