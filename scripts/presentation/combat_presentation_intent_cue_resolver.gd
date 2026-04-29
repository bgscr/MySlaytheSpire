class_name CombatPresentationIntentCueResolver
extends RefCounted

const CombatPresentationEvent := preload("res://scripts/presentation/combat_presentation_event.gd")

const ATTACK_CUE_ID := "enemy.attack"
const BLOCK_CUE_ID := "enemy.block"

func resolve_enemy_turn(
	intent_snapshots: Array[Dictionary],
	delta_events: Array[CombatPresentationEvent]
) -> Array[CombatPresentationEvent]:
	var events: Array[CombatPresentationEvent] = []
	if intent_snapshots.is_empty():
		return events
	var max_player_damage := _max_player_damage(delta_events)
	for snapshot in intent_snapshots:
		var source_id := String(snapshot.get("source_id", ""))
		var intent := String(snapshot.get("intent", ""))
		if source_id.is_empty() or intent.is_empty():
			continue
		if intent.begins_with("attack_"):
			_append_attack_events(events, source_id, intent, max_player_damage)
		elif intent.begins_with("block_"):
			_append_block_event(events, source_id, intent)
		elif intent.begins_with("apply_status_"):
			_append_player_status_event(events, source_id, intent.trim_prefix("apply_status_"))
		elif intent.begins_with("self_status_"):
			_append_self_status_event(events, source_id, intent.trim_prefix("self_status_"))
	return events

func _append_attack_events(
	events: Array[CombatPresentationEvent],
	source_id: String,
	intent: String,
	max_player_damage: int
) -> void:
	var amount := _parse_positive_int(intent.trim_prefix("attack_"))
	if amount <= 0:
		return
	var slash := CombatPresentationEvent.new("cinematic_slash")
	slash.source_id = source_id
	slash.target_id = "player"
	slash.amount = amount
	slash.intensity = clampf(float(amount) / 8.0, 0.75, 1.8)
	slash.tags = ["enemy_intent", "cinematic"]
	slash.payload = {"cue_id": ATTACK_CUE_ID}
	events.append(slash)
	if max_player_damage > 0:
		var impulse := CombatPresentationEvent.new("camera_impulse")
		impulse.source_id = source_id
		impulse.amount = max_player_damage
		impulse.intensity = clampf(float(max_player_damage) / 8.0, 0.5, 2.0)
		impulse.tags = ["enemy_intent"]
		impulse.payload = {"cue_id": ATTACK_CUE_ID}
		events.append(impulse)

func _append_block_event(events: Array[CombatPresentationEvent], source_id: String, intent: String) -> void:
	var amount := _parse_positive_int(intent.trim_prefix("block_"))
	if amount <= 0:
		return
	var burst := CombatPresentationEvent.new("particle_burst")
	burst.source_id = source_id
	burst.target_id = source_id
	burst.amount = amount
	burst.intensity = clampf(float(amount) / 8.0, 0.6, 1.5)
	burst.tags = ["enemy_intent", "block"]
	burst.payload = {"cue_id": BLOCK_CUE_ID}
	events.append(burst)

func _append_player_status_event(
	events: Array[CombatPresentationEvent],
	source_id: String,
	payload: String
) -> void:
	if not payload.ends_with("_player"):
		return
	var parsed := _parse_status_payload(payload.trim_suffix("_player"))
	if parsed.is_empty():
		return
	events.append(_status_burst(source_id, "player", parsed))

func _append_self_status_event(
	events: Array[CombatPresentationEvent],
	source_id: String,
	payload: String
) -> void:
	var parsed := _parse_status_payload(payload)
	if parsed.is_empty():
		return
	var burst := _status_burst(source_id, source_id, parsed)
	burst.tags.append("self")
	events.append(burst)

func _status_burst(source_id: String, target_id: String, parsed: Dictionary) -> CombatPresentationEvent:
	var status_id := String(parsed.get("status_id", ""))
	var amount := int(parsed.get("amount", 0))
	var burst := CombatPresentationEvent.new("particle_burst")
	burst.source_id = source_id
	burst.target_id = target_id
	burst.amount = amount
	burst.status_id = status_id
	burst.intensity = clampf(float(amount) / 3.0, 0.7, 1.5)
	burst.tags = ["enemy_intent", "status"]
	burst.payload = {"cue_id": "enemy.status.%s" % status_id}
	return burst

func _parse_status_payload(payload: String) -> Dictionary:
	var amount_separator := payload.rfind("_")
	if amount_separator <= 0 or amount_separator >= payload.length() - 1:
		return {}
	var status_id := payload.substr(0, amount_separator)
	var amount := _parse_positive_int(payload.substr(amount_separator + 1))
	if status_id.is_empty() or amount <= 0:
		return {}
	return {
		"status_id": status_id,
		"amount": amount,
	}

func _parse_positive_int(text: String) -> int:
	if not text.is_valid_int():
		return -1
	return int(text)

func _max_player_damage(delta_events: Array[CombatPresentationEvent]) -> int:
	var max_damage := 0
	for event in delta_events:
		if event == null:
			continue
		if event.event_type == "damage_number" and event.target_id == "player":
			max_damage = max(max_damage, int(event.amount))
	return max_damage
