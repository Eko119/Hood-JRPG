# Decision Record — Hood JRPG

Architecture Decision Records. This file is **binding**. Where it contradicts any other document, this file wins.

> **Canonical location:** this git repository (DEC-013). The Claude project copy is the workspace where decisions are proposed and argued; the committed copy governs.

## How this file works

- **LOCKED** — settled. Claude may not silently reverse, refactor around, or "improve" it. A session that believes one is wrong writes a **proposed amendment** at the bottom and stops. Ezra accepts or rejects. Only then does it change.
- **PROPOSED** — awaiting Ezra's call. Not yet binding. No implementation may depend on it.
- **PROVISIONAL** — working assumption, revisited at a named milestone.
- **SUPERSEDED** — replaced. The record stays, with a pointer forward. **Never delete a decision record.** The reasoning behind a rejected alternative is what stops a future session from re-proposing it.

The build log says *what is true now*. This says *what was chosen, why, and what was rejected*.

---

## DEC-001 — Combat resolution is independent of the SceneTree
**Status:** LOCKED · 2026-08-29

Combat rules live in pure functions: state in, new state plus event data out. No `get_node`, no signals, no `await`, no autoload access.

**Reason.** Enables unit testing and headless simulation; keeps presentation changes from touching rules. *Strengthened by DEC-014 — under simultaneous spatial combat, in-flight projectiles are persistent state; without this decision they would live in the scene tree and be neither simulatable nor saveable.*

**Alternatives.** (A) Node-based combat — untestable, unsimulatable. (B) Autoload `CombatManager` — global state breaks test isolation and parallel simulation. (C) Pure domain layer. **Selected: C.**

---

## DEC-002 — Godot Resources are the authoritative content format
**Status:** LOCKED · 2026-08-29 · **Supersedes:** DEC-002-a

`.tres` files are authoritative. CSV exists only for bulk numeric tuning round-trips, importing as a non-destructive upsert that updates only fields named in the CSV, matched on stable `id`, never deleting resources or touching references and text.

**Reason.** Typed Inspector editing and editor-resolved cross-references are the main practical advantage of Godot here; a generate-from-CSV pipeline discards them and adds a step that silently destroys hand-tuned values.

**Alternatives.** (A) CSV authoritative — rejected, see below. (B) `.tres` only, no CSV — rejected; bulk numeric comparison is better in a spreadsheet. (C) Resources authoritative, scoped CSV round-trip. **Selected: C.**

### DEC-002-a — CSV as source of truth *(SUPERSEDED)*
Chosen on the assumption that bulk generation requires a non-native intermediate. **False:** `.tres` is plain text with stable syntax and can be generated directly. Recorded so it is not re-proposed.

---

## DEC-003 — Testing uses GUT
**Status:** LOCKED · 2026-08-29

GUT 9.6.1, bundled in `addons/gut/`. Do not hand-roll a test framework.

**Reason.** Godot's integrated `doctest` tests target engine development in C++, not project GDScript. GUT installed cleanly, runs headless, and returns correct exit codes — verified at M0 across passing and deliberately failing runs.

**Operational note.** GUT requires `godot --headless --import` before its `class_name`s resolve. `verify.sh` step 5 handles this.

---

## DEC-004 — The determinism contract
**Status:** LOCKED · 2026-08-29 · **Extended by:** DEC-012, DEC-015

Seeded `RandomNumberGenerator` carried in `BattleState` — never global `randi()`/`randf()`. No outcome-affecting iteration over unordered collections. Ties break on stable `id`. Integer math for reproducible values. No wall-clock, frame delta, or `Engine` state reads.

**Reason.** Purity does not imply determinism. A pure function calling global RNG is structurally pure and practically irreproducible; a balance report you cannot reproduce is one you cannot act on.

**Enforcement.** `verify.sh` step 3 greps for global RNG under `systems/combat/` and fails the build. Verified to fire correctly against an injected violation.

---

## DEC-005 — Saves are JSON, never `ResourceSaver`
**Status:** LOCKED · 2026-08-29

`GameState` serializes to a Dictionary and out to JSON in `user://`, with a `save_version` integer and sequential migrations from M1.

**Reason.** Loading a `.tres` can resolve embedded script paths, making a hand-edited save an execution vector. Resource format drift breaks old saves painfully after release.

---

## DEC-006 — Engine is Godot 4 / GDScript
**Status:** LOCKED · 2026-08-29

**Alternatives.** (A) TypeScript/web — closer to Ezra's existing skills, weaker genre fit. (B) RPG Maker MZ — fastest to playable, fights any custom system. (C) Godot 4. **Selected: C.**

---

## DEC-007 — Target is a vertical slice
**Status:** LOCKED · 2026-08-29 · **Amendment proposed — see AMD-001**

15–30 minutes covering the full loop, with real art, music, and dialogue in what the player sees.

**Reason.** The question being answered is "would someone want to play this," not "can the architecture support a JRPG."

---

## DEC-008 — Cultural authority rests with Ezra
**Status:** LOCKED · 2026-08-29

**Claude may:** research, organize, synthesize, draft from material Ezra supplies, flag inconsistencies, propose alternatives, and ask questions that draw out specificity.

**Claude may not establish:** authentic community voice; what is culturally respectful; which real people, places, or practices are represented and how; what a cultural reference means to the creator.

**Operational rule.** Where cultural specificity is missing, Claude leaves an explicit `[NEEDS EZRA]` marker rather than inventing filler.

**Extension.** This applies to any third party, not only Claude. An external reviewer can validate process, architecture, and internal consistency — none of which require knowing what this game is about. **Architecture claims have external verifiers; creative identity does not.** Consensus process applied to creative identity produces competent generic output, which is the exact failure this decision exists to prevent.

---

## DEC-009 — Gray-box systems, art spec locked early
**Status:** LOCKED · 2026-08-29 · **Amendment proposed — see AMD-003**

Placeholder visuals through M4, but sprite dimensions, tile grid size, animation frame budget, palette constraints, and UI text capacity decided and written by M2.

**Reason.** Building *art* early is waste. But art *constraints* shape systems, and discovering them at M9 means rework.

---

## DEC-010 — Claude's output is never evidence
**Status:** LOCKED · 2026-08-29

Execution, validator output, test results, and human verification are evidence. Claude's assertion that something works is a claim. Every claim of working code carries the command and its output, or is labelled unverified. A milestone completes because its exit criteria pass.

**Verification split.** Claude runs Godot headless and executes the validator, tests, simulator, and boot checks. Claude cannot open the editor, see rendered output, judge feel, or judge cultural authenticity. **Claude verifies logic, data, and determinism; Ezra verifies everything visual, experiential, and cultural.**

---

## DEC-011 — Engine version is pinned and stated
**Status:** LOCKED · 2026-08-29

Godot **4.7**, pinned in `project.godot`, restated in `build-log.md`. `verify.sh` step 1 fails on mismatch. Upgrades are a deliberate task with a full verify run.

---

## DEC-012 — Serialize RNG `state`, not just `seed`
**Status:** LOCKED · 2026-08-29 · **Extends:** DEC-004

`BattleState` serializes the RNG's `state` property. Per Godot's docs, `state` is only ever set to a value that came from `state`; arbitrary initialization uses `seed`.

**Reason.** Seed-only reproduction replays from turn zero. Needed for **replayable failures** (re-enter the exact failing turn) and **mid-battle save/load** (seed-only storage silently changes a reloading player's rolls).

**Verified.** Round-trips correctly including through JSON — tested headless on 4.3 and 4.7, covered by `test_determinism.gd`.

---

## DEC-013 — The repository is canonical for project documentation
**Status:** LOCKED · 2026-08-29

Git is the source of truth for all project documentation. The Claude project is the workspace where decisions are proposed and developed; once accepted, a decision is committed, and the committed version governs.

1. Design decisions live in version-controlled documents.
2. An accepted design change requires a commit. Discussed-but-uncommitted is not decided.
3. Session notes, conversation history, and generated reports are never authoritative.
4. Claude's context and memory never override the repository. On conflict, the repository is right.
5. Implementation conforms to the committed design, not to conversational history.

**Reason.** Otherwise the project depends on "what we talked about three Tuesdays ago" — unreconstructable by a fresh session, another developer, or Ezra after six months away.

---

## DEC-014 — Combat is simultaneous planning/execution with a two-character pair
**Status:** LOCKED · 2026-08-29 *(Ezra's design decision — see `design-constitution.md` §2–§5)*

Combat uses an Arco-inspired structure: planning under freeze, then simultaneous execution of all player and enemy intents, producing the next combat state. **Not** a speed-sorted turn queue. **Not** ATB. The player controls exactly two characters, designed as a cooperative pair whose relationship is mechanically load-bearing. Timing inputs may modify the quality of an already-planned action but never replace planning.

**Architecture rule.** The combat domain determines what happens; the presentation layer displays what happened. Animation, VFX, audio, camera, and timing presentation must never become the source of combat truth.

**Consequences.** Combat state becomes spatial and persistent, including entities in flight across planning phases. The resolver signature becomes `execute(state, intents, seed) -> (final_state, tick_stamped_event_timeline)`. Full analysis in `arco-combat-analysis.md`.

---

## DEC-015 — Execution is a fixed-timestep, phase-ordered tick simulation
**Status:** PROPOSED — awaiting Ezra · 2026-08-29 · **Would extend:** DEC-004

**Proposal.** The execution window resolves as N discrete fixed-duration ticks. Within each tick, resolution proceeds in fixed phases **across all entities**, never entity-by-entity:

```
1. intents -> velocities        5. damage COMPUTED from tick-start state
2. movement applied             6. damage APPLIED simultaneously
3. collision resolution         7. status ticks, death checks
4. projectile advancement
```

Plus: integer or fixed-point positions (never float, which diverges across platforms); stable-`id` ordering for every tie in every phase; timing inputs recorded as **tick indices**, never wall-clock, making the replay record `(state, seed, intents, timing_inputs[tick])`.

**Reason.** Resolving entity-by-entity reintroduces turn order through the back door and produces asymmetries players experience as unfairness. Computing damage from tick-start state and applying at tick end is what makes resolution genuinely simultaneous. Recording timing inputs as ticks is what stops the Constitution §4 timing modifier from silently destroying reproducibility.

**Open questions Ezra must answer before this can lock** *(all in `arco-combat-analysis.md`)*: grid vs. continuous space; whether mutual destruction is permitted; how far ahead enemy intent is visible; ticks per execution window; the ability resource and whether it regenerates positionally.

---

## DEC-016 — Three-layer progression; no jobs, no large skill trees
**Status:** LOCKED · 2026-08-29 *(Ezra's design decision — see `design-constitution.md` §6–§7)*

Levels give readable baseline growth. Equipment gives customization, kept limited in complexity. Relationships are the identity layer, unlocking abilities, cooperative actions, passives, scenes, and select equipment — but never the sole source of numerical progression.

Jobs/classes and large branching skill trees are excluded from initial scope. Depth comes from new tactical verbs and interactions, not upgrade nodes.

---

## Proposed amendments

### AMD-001 — DEC-007's slice definition assumes menu-driven combat
**Raised:** 2026-08-29 by Claude · **Targets:** DEC-007

DEC-007 currently specifies "battle with all four command types" (attack / skill / item / run). That vocabulary belongs to a menu-driven JRPG and is incoherent under DEC-014, where a battle is a planning phase and a simultaneous execution window.

**Proposed replacement for the combat portion of the slice definition:** *at least two full plan-execute cycles against a telegraphing enemy, exercising movement, an ability with a resource cost, a multi-tick projectile, and at least one cooperative action between the pair.*

Rest of DEC-007 (title, intro, town with NPC/shop/save, field, encounter, victory, XP, level-up, dungeon, boss, story scene, save, load, real art and music) unchanged.

### AMD-002 — DEC-004 needs spatial determinism clauses
**Raised:** 2026-08-29 by Claude · **Targets:** DEC-004

DEC-004 was written for a speed-sorted turn queue. Under DEC-014 it does not cover: simultaneous movement into contested space, projectile/mover crossing, or float position drift across platforms. **Proposal: adopt DEC-015, which supplies these clauses.** No change to DEC-004's existing text.

### AMD-003 — DEC-009's art spec list is missing spatial items
**Raised:** 2026-08-29 by Claude · **Targets:** DEC-009

Under DEC-014 the M2 art spec must also fix: grid cell size (or world unit scale), sprite footprint versus collision footprint, projectile sprite scale and travel readability, enemy telegraph visual language, and planning-phase UI overlay budget. All of these constrain the resolver and the planning UI, which is why they belong at M2 rather than M9.
