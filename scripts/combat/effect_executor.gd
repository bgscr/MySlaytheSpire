class_name EffectExecutor
extends RefCounted

const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

var status_runtime := CombatStatusRuntime.new()

func execute(effect: EffectDef, source: CombatantState, target: CombatantState) -> void:
	_execute_effect(effect, null, source, target)

func execute_in_state(effect: EffectDef, state: CombatState, source: CombatantState, target: CombatantState) -> void:
	_execute_effect(effect, state, source, target)

func _execute_effect(effect: EffectDef, state: CombatState, source: CombatantState, target: CombatantState) -> void:
	var recipient := _resolve_recipient(effect.target, source, target)
	var amount: int = max(0, effect.amount)
	match effect.effect_type:
		"damage":
			var damage_amount := amount
			if state != null:
				damage_amount = status_runtime.modify_damage(state, source, recipient, amount)
			var hp_lost := recipient.take_damage(damage_amount)
			if state != null:
				status_runtime.after_damage(state, source, recipient, damage_amount, hp_lost)
		"block":
			recipient.gain_block(amount)
		"heal":
			recipient.current_hp = min(recipient.max_hp, recipient.current_hp + amount)
		"draw_card":
			if state != null:
				state.pending_draw_count += amount
		"gain_energy":
			if state != null:
				state.energy += amount
		"apply_status":
			if amount > 0 and not effect.status_id.is_empty():
				recipient.statuses[effect.status_id] = recipient.statuses.get(effect.status_id, 0) + amount
		"gain_gold":
			if state != null:
				state.gold_delta += amount
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
