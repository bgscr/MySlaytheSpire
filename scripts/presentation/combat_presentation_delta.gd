class_name CombatPresentationDelta
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func capture_state(state: CombatState) -> Dictionary:
	var result := {}
	if state == null:
		return result
	if state.player != null:
		result["player"] = _capture_combatant(state.player)
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		result[_enemy_target_id(enemy_index)] = _capture_combatant(enemy)
	return result

func events_between(before: Dictionary, state: CombatState) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if state == null:
		return events
	if state.player != null:
		_append_delta_events(events, "player", before.get("player", {}), state.player)
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		var target_id := _enemy_target_id(enemy_index)
		_append_delta_events(events, target_id, before.get(target_id, {}), enemy)
	return events

func events_from_initial_state(state: CombatState) -> Array[CombatPresentationEvent]:
	var before := {}
	if state == null:
		return []
	if state.player != null:
		before["player"] = {
			"id": state.player.id,
			"current_hp": state.player.current_hp,
			"block": 0,
			"statuses": {},
		}
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index] as CombatantState
		if enemy == null:
			continue
		before[_enemy_target_id(enemy_index)] = {
			"id": enemy.id,
			"current_hp": enemy.current_hp,
			"block": 0,
			"statuses": {},
		}
	return events_between(before, state)

func _capture_combatant(combatant: CombatantState) -> Dictionary:
	return {
		"id": combatant.id,
		"current_hp": combatant.current_hp,
		"block": combatant.block,
		"statuses": _positive_statuses(combatant),
	}

func _positive_statuses(combatant: CombatantState) -> Dictionary:
	var result := {}
	for key in combatant.statuses.keys():
		var status_id := String(key)
		var layers := int(combatant.statuses.get(status_id, 0))
		if layers > 0:
			result[status_id] = layers
	return result

func _append_delta_events(
	events: Array[CombatPresentationEvent],
	target_id: String,
	before_payload: Dictionary,
	after: CombatantState
) -> void:
	var hp_before := int(before_payload.get("current_hp", after.current_hp))
	var hp_lost := hp_before - after.current_hp
	if hp_lost > 0:
		events.append(_event("damage_number", target_id, hp_lost))
		events.append(_event("combatant_flash", target_id, 0))

	var block_before := int(before_payload.get("block", after.block))
	var block_gained := after.block - block_before
	if block_gained > 0:
		events.append(_event("block_number", target_id, block_gained))

	var before_statuses: Dictionary = before_payload.get("statuses", {})
	var after_statuses := _positive_statuses(after)
	var status_ids := _status_union(before_statuses, after_statuses)
	for status_id in status_ids:
		var delta := int(after_statuses.get(status_id, 0)) - int(before_statuses.get(status_id, 0))
		if delta == 0:
			continue
		var status_event := _event("status_number", target_id, delta)
		status_event.status_id = status_id
		status_event.text = _status_text(status_id, delta)
		events.append(status_event)
		var pulse := _event("status_badge_pulse", target_id, 0)
		pulse.status_id = status_id
		events.append(pulse)

func _status_union(before_statuses: Dictionary, after_statuses: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in before_statuses.keys():
		var status_id := String(key)
		if not ids.has(status_id):
			ids.append(status_id)
	for key in after_statuses.keys():
		var status_id := String(key)
		if not ids.has(status_id):
			ids.append(status_id)
	ids.sort()
	return ids

func _event(event_type: String, target_id: String, amount: int) -> CombatPresentationEvent:
	var event := CombatPresentationEvent.new(event_type)
	event.target_id = target_id
	event.amount = amount
	return event

func _status_text(status_id: String, amount: int) -> String:
	var prefix := "+" if amount > 0 else ""
	return "%s%s %s" % [prefix, amount, status_id]

func _enemy_target_id(enemy_index: int) -> String:
	return "enemy:%s" % enemy_index
