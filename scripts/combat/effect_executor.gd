class_name EffectExecutor
extends RefCounted

const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func execute(effect: EffectDef, source: CombatantState, target: CombatantState) -> void:
	var recipient := _resolve_recipient(effect.target, source, target)
	var amount: int = max(0, effect.amount)
	match effect.effect_type:
		"damage":
			recipient.take_damage(amount)
		"block":
			recipient.gain_block(amount)
		"heal":
			recipient.current_hp = min(recipient.max_hp, recipient.current_hp + amount)
		_:
			push_error("Unknown effect type: %s" % effect.effect_type)

func _resolve_recipient(effect_target: String, source: CombatantState, target: CombatantState) -> CombatantState:
	match effect_target.to_lower():
		"enemy", "target":
			return target
		"player", "self", "source":
			return source
		_:
			push_error("Unknown effect target: %s" % effect_target)
			return target
