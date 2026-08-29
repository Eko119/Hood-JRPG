extends Node
## Global signal hub. Systems emit here; systems listen here.
##
## This exists so the combat system never needs a direct reference to the UI,
## the audio manager, or anything else. The alternative — every system holding
## a pointer to every other system — is how a scene tree becomes impossible to
## refactor. Declarations only at M0; emitters arrive with their systems.

signal battle_started(encounter_id: StringName)
signal battle_ended(victory: bool)
signal damage_dealt(target_id: StringName, amount: int)
signal character_died(character_id: StringName)
signal level_gained(character_id: StringName, new_level: int)
signal item_acquired(item_id: StringName, quantity: int)
signal flag_changed(flag: StringName, value: Variant)
