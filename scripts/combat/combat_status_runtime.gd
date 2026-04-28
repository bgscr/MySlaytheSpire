class_name CombatStatusRuntime
extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

const STATUS_POISON := "poison"
const STATUS_SWORD_FOCUS := "sword_focus"
const STATUS_BROKEN_STANCE := "broken_stance"
const STATUS_DISPLAY_ORDER: Array[String] = [
	STATUS_POISON,
	STATUS_SWORD_FOCUS,
	STATUS_BROKEN_STANCE,
]

const STATUS_METADATA := {
	STATUS_POISON: {
		"name_key": "status.poison.name",
		"description_key": "status.poison.desc",
	},
	STATUS_SWORD_FOCUS: {
		"name_key": "status.sword_focus.name",
		"description_key": "status.sword_focus.desc",
	},
	STATUS_BROKEN_STANCE: {
		"name_key": "status.broken_stance.name",
		"description_key": "status.broken_stance.desc",
	},
}

func modify_damage(state: CombatState, source: CombatantState, target: CombatantState, base_amount: int) -> int:
	if state == null or source == null or target == null:
		return max(0, base_amount)
	if base_amount <= 0:
		return 0
	var amount := base_amount
	if source == state.player:
		amount += _layers(source, STATUS_SWORD_FOCUS)
	amount += _layers(target, STATUS_BROKEN_STANCE)
	return max(0, amount)

func after_damage(state: CombatState, source: CombatantState, target: CombatantState, final_amount: int, _hp_lost: int) -> void:
	if state == null or source == null or target == null or final_amount <= 0:
		return
	if source == state.player and _layers(source, STATUS_SWORD_FOCUS) > 0:
		_decay(source, STATUS_SWORD_FOCUS)
	if _layers(target, STATUS_BROKEN_STANCE) > 0:
		_decay(target, STATUS_BROKEN_STANCE)

func on_turn_started(combatant: CombatantState, _state: CombatState) -> void:
	if combatant == null:
		return
	var poison := _layers(combatant, STATUS_POISON)
	if poison <= 0:
		return
	combatant.current_hp = max(0, combatant.current_hp - poison)
	_decay(combatant, STATUS_POISON)

func status_text(combatant: CombatantState) -> String:
	if combatant == null:
		return ""
	var keys := combatant.statuses.keys()
	keys.sort()
	var result := ""
	for key in keys:
		var status_id := String(key)
		var layers := int(combatant.statuses.get(status_id, 0))
		if layers <= 0:
			continue
		if not result.is_empty():
			result += " "
		result += "%s:%s" % [status_id, layers]
	return result

func status_display_text(combatant: CombatantState) -> String:
	if combatant == null:
		return ""
	var parts: Array[String] = []
	for status_id in STATUS_DISPLAY_ORDER:
		var layers := _layers(combatant, status_id)
		if layers > 0:
			parts.append("%s %s" % [_status_display_name(status_id), layers])
	var unknown_ids := _unknown_positive_status_ids(combatant)
	for status_id in unknown_ids:
		parts.append("%s %s" % [status_id, _layers(combatant, status_id)])
	return " | ".join(parts)

func _status_display_name(status_id: String) -> String:
	var metadata: Dictionary = STATUS_METADATA.get(status_id, {})
	var name_key := String(metadata.get("name_key", status_id))
	var translated := tr(name_key)
	return translated if not translated.is_empty() else status_id

func _unknown_positive_status_ids(combatant: CombatantState) -> Array[String]:
	var result: Array[String] = []
	for key in combatant.statuses.keys():
		var status_id := String(key)
		if STATUS_METADATA.has(status_id):
			continue
		if _layers(combatant, status_id) > 0:
			result.append(status_id)
	result.sort()
	return result

func _layers(combatant: CombatantState, status_id: String) -> int:
	if combatant == null:
		return 0
	return max(0, int(combatant.statuses.get(status_id, 0)))

func _decay(combatant: CombatantState, status_id: String) -> void:
	var remaining := _layers(combatant, status_id) - 1
	if remaining <= 0:
		combatant.statuses.erase(status_id)
	else:
		combatant.statuses[status_id] = remaining
