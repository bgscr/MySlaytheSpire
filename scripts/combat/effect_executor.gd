class_name EffectExecutor
extends RefCounted

const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func execute(effect: EffectDef, source: CombatantState, target: CombatantState) -> void:
	match effect.effect_type:
		"damage":
			target.take_damage(effect.amount)
		"block":
			source.gain_block(effect.amount)
		"heal":
			source.current_hp = min(source.max_hp, source.current_hp + effect.amount)
		_:
			push_error("Unknown effect type: %s" % effect.effect_type)
