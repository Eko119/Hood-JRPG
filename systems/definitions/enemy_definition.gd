extends Resource
class_name EnemyDefinition
## Walking-skeleton content type. One definition at M0 by design (CLAUDE.md
## exit criterion 11) — the remaining types arrive at M1 with their validator
## rules written first.
##
## `id` is the stable key that saves and cross-references point at. It is never
## reused after deletion, and renaming one is a migration rather than an edit.
## `display_name` is player-facing and may change freely — which is exactly why
## it is never used as a key.

@export var id: StringName = &""
@export var display_name: String = ""
@export var authored: bool = false  ## Hand-tuned; skipped by CSV numeric import (DEC-002)

@export_group("Stats")
@export var max_hp: int = 1
@export var max_mp: int = 0
@export var attack: int = 1
@export var defense: int = 1
@export var speed: int = 1

@export_group("Rewards")
@export var xp_reward: int = 0
@export var money_reward: int = 0
@export var encounter_tier: int = 1
