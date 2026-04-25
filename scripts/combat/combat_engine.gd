class_name CombatEngine
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const EffectExecutor := preload("res://scripts/combat/effect_executor.gd")

var executor := EffectExecutor.new()

func play_card(card: CardDef, source: CombatantState, target: CombatantState) -> void:
	for effect in card.effects:
		executor.execute(effect, source, target)

func end_turn(state: CombatState) -> void:
	state.turn += 1
	state.energy = 3
	state.player.block = 0
