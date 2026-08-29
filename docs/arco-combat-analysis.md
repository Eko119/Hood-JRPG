# Combat Model Analysis — Arco's Structure and What We Take From It

**Purpose:** ground the reference. The Design Constitution names Arco as the model for combat; this document records what Arco actually does (verified, not recalled), what we adopt, what we change, and — most importantly — what it costs architecturally.

---

## What Arco actually does

Verified against the designers' own account and hands-on reporting, 2026-08-29. Recorded because "Arco-inspired" is only useful if it points at something specific.

**Planning under freeze.** Combat pauses; the player selects an action while time is frozen. Enemies choose simultaneously. Enemy intentions are visible during planning.

**Simultaneous resolution.** Player and enemy actions resolve at the same time. The designers describe the result as "a system of action, consequence, and reaction that becomes unpredictable."

**Movement plus a regenerating resource.** The player selects movement distance and abilities; abilities cost Magia, which regenerates as you move or wait. This forces a positional economy: *where* you end your turn determines what you can afford to do there.

**Multi-turn projectile flight — the structurally important one.** Some abilities take more than one turn to land, while the player can only see enemy intent for the *next* turn. You aim at where a target will be once flight time is factored in, not where it is. Projectiles travel visibly and can narrowly miss.

**Emergent chains, not scripted combos.** Interacting verbs — throw a gas cloud, shoot an arrow through it, apply poison on hit. The designers explicitly frame this as "fuck around and find out" rather than an Into the Breach-style solvable puzzle.

**No action timeline.** A timeline UI showing resolution order was prototyped and scrapped.

**Not reflex-driven.** The system deliberately avoids rewarding twitch input.

---

## What we take, and what differs

| | Arco | Hood JRPG |
|---|---|---|
| Planning under freeze | ✓ | ✓ adopt |
| Simultaneous resolution | ✓ | ✓ adopt |
| Visible enemy intent | ✓ | ✓ adopt |
| Multi-tick projectiles | ✓ | ✓ adopt — see cost below |
| Emergent verb interaction | ✓ | ✓ adopt |
| Timing input | minimal | limited execution modifier (Constitution §4) |
| Characters controlled | varies, largely single-focus | **exactly two, as a cooperative pair** |
| Bond as mechanic | no | **yes — the central differentiator** |
| Progression | Arco's own | levels + equipment + **relationships** |

**The differentiator is the pair.** Arco is a tactical planning game. This is a tactical planning game where the unit of play is a *relationship* — every plan is two plans that have to fit together, and the interesting decisions live in the seam between them. That is not a reskin of Arco; it is a different game that borrows Arco's resolution structure.

---

## What this costs architecturally

Honest accounting. This is a materially larger combat engine than menu-driven JRPG combat.

### 1. Combat state becomes spatial and persistent

`BattleState` is no longer a party list and an enemy list. It holds positions, facings, movement, terrain/cover, hazards, enemy intents, and — because projectiles take multiple turns to land — **entities in flight that persist across planning phases.** An arrow mid-flight is state, not animation.

This is closer to a small deterministic simulation than to a JRPG battle. It also makes DEC-001 (pure domain layer, no scene tree) far more valuable than it was under a turn queue: without it, in-flight projectiles would live in the scene tree and become unsimulatable and unsaveable.

### 2. Execution must be a fixed-timestep tick simulation

Simultaneous resolution with movement and projectiles has no meaningful notion of "whose turn." Execution is N discrete ticks. This is not optional if determinism is required, and determinism *is* required (Constitution §3, DEC-004).

### 3. The resolver signature changes

Not `resolve(state, command) -> state`. Instead:

```
execute(state, intents, seed) -> (final_state, tick_stamped_event_timeline)
```

The presentation layer plays back the timeline. This is strictly better for DEC-001 — the domain never waits on animation, and the same timeline can be replayed, fast-forwarded, or skipped entirely by the simulator.

### 4. Simultaneity has to be defined precisely, or it leaks turn order back in

The naive implementation — loop over entities, resolve each one's tick — reintroduces turn order through the back door and creates asymmetries the player will feel as unfairness. The correct structure resolves each tick in **fixed phases across all entities**:

```
per tick:
  1. intents -> velocities            (all entities)
  2. movement applied                 (all simultaneously)
  3. collision / overlap resolution   (stable id order for ties)
  4. projectile advancement
  5. damage COMPUTED from tick-start state
  6. damage APPLIED                   (all simultaneously)
  7. status ticks, death checks
```

Computing damage from tick-start state and applying it at tick end is what makes resolution genuinely simultaneous. **Consequence: two combatants can kill each other in the same tick.** That is a design decision, not an implementation detail — see open questions.

### 5. Determinism gets harder, and DEC-004 needs extending

New hazards that a turn queue did not have: two entities entering the same space in the same tick; a projectile and a mover crossing paths; float position drift across platforms. Requirements:

- **Fixed timestep**, never frame delta.
- **Integer or fixed-point positions.** Float positions can diverge across platforms and break replay.
- **Stable-id ordering** for every tie, in every phase.
- **Timing inputs recorded as tick indices**, never wall-clock. The replay record becomes `(state, seed, intents, timing_inputs[tick])`. Without this, the timing modifier from Constitution §4 silently destroys reproducibility.

### 6. The balance simulator gets weaker — say so plainly

Under a turn queue, "run 10,000 battles" produces a clean win-rate oracle, because a scripted AI plays roughly as well as a person. Under tactical spatial combat it does not. Simulation now requires a **planner** — an AI that chooses positions and actions — and a scripted planner is worse than a human at exactly the thing the game is about.

The simulator remains genuinely useful for what it *can* answer: unwinnable encounters, degenerate dominant strategies, resource-economy sanity, ability outliers, crash and assertion coverage across thousands of states. It cannot answer "is this fight tuned correctly for a good player." That answer comes from playtesting, and no amount of simulation substitutes for it.

---

## The scope trade, honestly

The engine got harder. The content got lighter.

**Harder:** spatial state, tick simulation, projectile flight, collision, enemy intent planning AI, planning-phase UI, replay infrastructure.

**Lighter:** two characters instead of four (half the kits, half the art, half the balance surface); no jobs; no skill trees; no large item economy; relationships replace breadth with depth.

For a solo developer with Claude implementing, this trade is favorable. Engine complexity is verifiable by execution — it is exactly where machine-checkable gates apply and where Claude is most useful. Content volume is the grind that kills solo JRPGs, and this design cut it substantially.

The risk is different rather than absent: **the combat has to be good, because there is much less else to hide behind.** A generic JRPG with 300 items can coast on content. This design cannot. That raises the value of getting the simulator and the playtest loop running early, and it is the strongest argument yet for M3 before M4.

---

## Open design questions — needed before M2, not before M1

Mechanical, not creative. These change the resolver's structure.

1. **Grid or continuous space?** A grid makes collision, targeting, and integer determinism straightforward and reads clearly to the player. Continuous space allows finer positioning and more natural projectile arcs at the cost of fixed-point math everywhere. *Recommendation: grid, until playtesting proves it insufficient.*
2. **Is mutual destruction allowed?** Simultaneous damage means both combatants can die in the same tick. Permitting it is more honest to the model; forbidding it requires an explicit priority rule.
3. **How far ahead is enemy intent visible?** Arco shows the next turn only, which is what makes multi-turn projectiles interesting. Confirm we want that same tension.
4. **How many ticks is one execution window?** Determines how much can happen per plan, and therefore the pace of the entire game.
5. **What is the ability resource, and does it regenerate positionally?** Arco's Magia regenerates by moving or waiting, creating a positional economy. Whether we adopt that shape is a real fork — and naming it is Ezra's call (Constitution §9).
