# CLAUDE.md — Operating Contract

**Read at the start of every session, before any other document.**
This is not documentation about the game. It is the rules of engagement.

---

## Rule 0 — Claude's output is never evidence that something works

Execution is evidence. Tests are evidence. Validator output is evidence. A human
playing it is evidence.

Claude saying "this should work," "I've implemented X," or "the milestone is
complete" is a **claim**, not a result. Every claim of working code carries the
command that was run and the output it produced, or is explicitly labelled
unverified.

This is the rule the others exist to serve. A language model will occasionally
invent an API that does not exist, misremember a signature, or reference
something renamed three sessions ago. That rate is not reducible to zero by
careful prompting. It is made *harmless* by verification that runs in seconds
and fails loudly.

**Corollary:** a milestone is complete because its exit criteria pass, not
because Claude says it is complete.

**Corollary:** when Claude cannot verify something, it says so in those words.
"I wrote this but could not run it" is a useful sentence. Silence implying
verification is not.

---

## Verification split

Claude's cloud session **can** run Godot headless (verified 2026-08-29, v4.3 and
v4.7) and therefore executes the validator, the test suite, the simulator, and
boot checks itself.

Claude **cannot** open the editor, see rendered output, judge timing or feel,
evaluate UI legibility at real size, determine whether the game is fun, or judge
cultural authenticity (DEC-008).

**Claude verifies logic, data, and determinism by execution. Ezra verifies
everything visual, experiential, and cultural.** Neither substitutes for the other.

---

## Session protocol

**Open.** Read this → `build-log.md` → `decisions.md` → whatever the task
touches. State the current milestone and the session's single objective before
acting.

**During.** One system or one content batch. Do not open a second front. Keep the
project booting. Never silently change a LOCKED decision — write a proposed
amendment in `decisions.md` and stop.

**Close.** Update `build-log.md`: what was built, what was verified and how, what
broke, what's next. New architectural choices become numbered records in
`decisions.md`.

---

## Document authority

```
decisions.md    BINDING — overrides everything below
CLAUDE.md       operating rules (this file)
game-bible.md   creative truth
systems-architecture.md   technical truth
content-schema.md         data truth
roadmap.md      sequence
build-log.md    current state
```

Generated artifacts — `validation_report.json`, `test_report.xml`,
`balance_report.json` — are **outputs, not documentation.** They live in
`reports/`, are git-ignored, and are never hand-edited or cited as design intent.

---

## Coding conventions

Typed GDScript everywhere. Signals up, calls down — a child never reaches into
its parent. Files and directories `snake_case`, classes `PascalCase`, constants
`SCREAMING_SNAKE`, private members `_leading_underscore`. Every content resource
carries a stable `id`, never reused after deletion. No magic numbers in the
combat domain — named constants only, because they are balance knobs and must be
findable.

**Hard prohibition:** no global `randi()`, `randf()`, `randi_range()`, or
`randf_range()` anywhere under `systems/combat/`. This is DEC-004, enforced by
`verify.sh` step 3, not by good intentions.

---

## Git

Small commits, one concern each. Never commit with `verify.sh` red. The engine
version is pinned in `project.godot` and stated in `build-log.md`.

---

## Milestone gate meta-rule

Every milestone gets exit criteria written **before** work starts, split into
machine-checkable (a script exits 0) and human-judgment (Ezra confirms).
Criteria that cannot be checked by running something are labelled as judgment
calls rather than dressed up as objective. A gate that quietly bottoms out in
Claude's assessment has failed at its one job.

## M0 exit gate — COMPLETE

Machine-checkable, all passing via `./verify.sh`:

1. Engine boots headless at pinned 4.7, zero errors
2. Walking skeleton: definition → `.tres` → runtime load → assertion
3. Determinism: same seed reproduces; restored RNG `state` resumes mid-sequence
4. RNG lint: zero global RNG under `systems/combat/`
5. GUT installed, 8 tests passing headless
6. Content validator: zero errors
7. Canonical directory structure matches `systems-architecture.md`

Gate confirmed to fail correctly against injected faults (exit 1).

Human-judgment, pending Ezra: project opens in the editor; conventions agreed;
no gameplay content prematurely built.
