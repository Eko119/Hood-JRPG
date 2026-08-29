# Design Constitution — Hood JRPG

**Status:** Core mechanical identity LOCKED by Ezra 2026-08-29. Creative nouns still open.
**Authority:** This document defines what the game *is*. Implementation conforms to it (DEC-013).

Scope note: this is a compact constitution, not a lore bible. It contains only decisions that constrain architecture and content schemas. Town names, NPC biographies, kingdom history, enemy concepts, and soundtrack belong later and are deliberately excluded.

---

## 1. World

**Real neighborhood + mythic reinterpretation.**

The game takes place in a recognizable real-world neighborhood/environment, but its mythology, supernatural events, and hidden history are reinterpreted through the game's fictional narrative.

- The real-world setting provides **environmental specificity and cultural grounding.**
- The mythic layer provides **the scale and fantasy necessary for the JRPG structure.**
- The goal is **not documentary realism.** Real places provide the foundation; the game's fictional mythology determines what is actually happening.

---

## 2. Party — two characters

The player controls **two characters simultaneously during combat.**

They are designed as a **cooperative combat pair**, not four party members compressed into two slots. Their relationship is mechanically significant. Combat abilities should create opportunities for one character's planned action to complement, protect, enable, reposition, or amplify the other's.

**The bond between the characters is part of the combat system itself.**

### Scope rule
Do not expand the core combat party to three or four playable combatants unless a later production review demonstrates that the existing two-character system is already complete, stable, and the additional complexity is justified.

---

## 3. Combat — deterministic simultaneous tactical

An **Arco-inspired simultaneous planning/resolution structure.** Not a speed-sorted turn queue. Not ATB.

### Planning phase
Time is paused. The player can inspect character positions, enemy positions, enemy intentions/telegraphs, available abilities, resources, and relevant battlefield conditions. The player then assigns actions to both characters.

### Execution phase
Time resumes. Committed actions resolve through the combat simulation. **Both player characters and enemies execute their planned actions during the same resolution window.** Movement, attacks, projectiles, abilities, collisions, and positioning are resolved by the deterministic combat system.

### Resolution
The resulting combat state becomes the starting state for the next planning phase.

```
COMBAT STATE
    ↓
PLANNING
    ↓
PLAYER + ENEMY INTENTIONS
    ↓
EXECUTION
    ↓
DETERMINISTIC RESOLUTION
    ↓
NEW COMBAT STATE
    ↓
PLANNING
```

### Space — continuous
Combat space is **continuous, not gridded** (DEC-017). Free positioning, natural projectile arcs, shots that visibly graze past. This is the closer reading of Arco and was chosen knowing it costs fixed-point math throughout the domain layer.

### Ability resource — positional regeneration
The ability resource **regenerates as a character moves or waits** (DEC-018), following Arco's shape. Where you end the window determines what you can afford there. Waiting is a tactical choice, not a wasted cycle. *Name pending — see §9.*

### Architecture rule
**The combat domain determines what happens. The presentation layer displays what happened.** Animation, VFX, audio, camera movement, and timing presentation must not become the source of combat truth. The resolver is deterministic from its defined inputs.

---

## 4. Timing — an execution modifier, not the core system

The game may use limited timing inputs during execution to reward skilled play. Timing modifies the **quality/effectiveness of an already-planned action.** It must not replace the primary tactical planning decision.

The hierarchy is:

> **Strategy → Position → Planned Action → Execution Quality**

not:

> ~~Reflexes → Strategy~~

Timing must remain small enough that the game is fundamentally understandable and playable as a tactical planning game.

---

## 5. Bond / cooperative combat

The two characters have cooperative actions emerging from their relationship and complementary abilities. Design patterns include: one character creates an opening the other exploits; one protects another's planned movement; one repositions an enemy for the other's attack; synchronized actions produce enhanced effects; relationship progression unlocks new cooperative possibilities.

**The system favors interacting verbs over a large list of scripted "combo attacks."** The objective is for players to discover tactical combinations through planning.

---

## 6. Progression — three layers

**A. Levels.** Simple, readable baseline growth. Predictable increases to core capability.

**B. Equipment.** Weapons, clothing/armor, accessories provide customization and numerical or tactical modifiers. Kept understandable and relatively limited in complexity.

**C. Relationships.** The game's identity layer. Relationship progression can unlock new abilities, cooperative actions, passive effects, special interactions, narrative scenes, and unique equipment or techniques where appropriate. **Relationships must not become the sole source of numerical progression.**

### Core principle
- Levels answer: *"Am I stronger?"*
- Equipment answers: *"How am I equipped?"*
- Relationships answer: *"What can I do that I could not do before, and who have I become?"*

---

## 7. Explicitly excluded from initial scope

**Jobs / classes.** Not part of the initial core system. Depth comes from character identity, positioning, enemy intent, ability interactions, cooperative planning, relationships, and equipment. Reconsider only after the core game is complete and stable.

**Large skill trees.** No branching skill-tree system. Abilities are introduced through controlled progression and relationships. Depth comes from **new tactical verbs and interactions**, not hundreds of upgrade nodes.

---

## 8. Non-negotiables

Derived from the above. Implementation may not quietly change these:

1. Two playable characters in combat. Not three, not four.
2. Simultaneous planning/execution. Not a turn queue, not ATB.
3. The combat domain is the source of truth; presentation only displays.
4. The resolver is deterministic from its defined inputs.
5. Timing modifies planned actions; it never replaces planning.
6. The bond is mechanical, not just narrative.
7. Relationships unlock capability; they are not the primary numeric ramp.
8. No jobs, no large skill trees, in initial scope.

---

## 9. Still open — [NEEDS EZRA]

Per DEC-008, Claude does not fill these with plausible defaults. None of them block M1 architecture; all of them block content.

- **The place.** Which neighborhood, real or composed from real ones. The specific geography the setting is built on.
- **The two characters.** Who they are, what they want, what they fear, and how each one fights — the fighting style is how the player learns who they are before either speaks.
- **Their relationship.** What the bond actually is. This is the game's mechanical and emotional center and cannot be derived from anything above.
- **The mythic layer.** What is actually happening supernaturally, and which traditions the mythology draws on.
- **What an enemy represents.** Structurally load-bearing — it determines whether enemies are people, spirits, manifestations, or something else, which changes both content and tone.
- **Core nouns.** The game's vocabulary: the resource spent on abilities, currency, factions, combat terminology, what the mythic layer is called.
- **Tone boundaries.** What subjects are deliberately in, and what is deliberately out.
