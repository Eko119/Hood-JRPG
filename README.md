# Hood JRPG

A Final Fantasy-scale JRPG built as a celebration of Black American culture.
Godot 4.7 · GDScript · solo development with Claude as implementer.

## Quick start

```bash
# Point verify.sh at your Godot 4.7 binary (or drop it at ./bin/godot)
export GODOT=/path/to/godot
./verify.sh
```

`verify.sh` is the single command that decides whether the project is green.
Never commit with it red.

## Where things live

| Path | What |
|---|---|
| `data/` | Authoritative `.tres` content (DEC-002) |
| `tuning/` | CSV exports for bulk numeric passes — **not** authoritative |
| `systems/combat/` | Pure domain layer: no nodes, no autoloads, no global RNG |
| `systems/definitions/` | `Resource` subclasses defining content types |
| `autoloads/` | GameState, EventBus, SceneManager, AudioManager, SaveSystem |
| `tools/` | Content validator, CSV round-trip, balance simulator |
| `tests/` | GUT suites, run headless |
| `reports/` | Generated output. Git-ignored. Never hand-edited, never cited as intent |

## Read before contributing

`CLAUDE.md` — operating contract. Rule 0: **output is never evidence that
something works.** Execution, tests, validator results, and human verification
are evidence.

Full design documents live in the "Hood-jrpg" Claude project: game bible,
systems architecture, content schema, roadmap, build log, and the binding
decision record.

## Status

**M0 complete** — production machine built and verified. No gameplay content.
Next: M1 (data definitions + validator coverage for all content types).
