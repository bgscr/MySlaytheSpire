class_name EnemyIntentDisplayResolver
extends RefCounted

const UNKNOWN_DISPLAY_ID := "unknown"

func resolve(intent: String, catalog: Object) -> Dictionary:
	var parsed := _parse(intent)
	var display_id := String(parsed.get("display_id", UNKNOWN_DISPLAY_ID))
	var display = _display_for(catalog, display_id)
	var is_known := display != null and display_id != UNKNOWN_DISPLAY_ID
	if display == null:
		display = _display_for(catalog, UNKNOWN_DISPLAY_ID)
		display_id = UNKNOWN_DISPLAY_ID
		is_known = false
	if display == null:
		return _fallback_without_resource(intent)
	return {
		"raw_intent": intent,
		"kind": String(parsed.get("kind", display.intent_kind)),
		"display_id": display_id,
		"icon_key": display.icon_key,
		"label": display.label,
		"amount": int(parsed.get("amount", 0)),
		"status_id": String(parsed.get("status_id", "")),
		"target": String(parsed.get("target", "")),
		"color": display.color,
		"show_amount": display.show_amount,
		"show_target": display.show_target,
		"is_known": is_known,
	}

func _parse(intent: String) -> Dictionary:
	if intent.begins_with("attack_"):
		var amount := _parse_positive_int(intent.trim_prefix("attack_"))
		if amount > 0:
			return {
				"kind": "attack",
				"display_id": "attack",
				"amount": amount,
				"status_id": "",
				"target": "player",
			}
	elif intent.begins_with("block_"):
		var amount := _parse_positive_int(intent.trim_prefix("block_"))
		if amount > 0:
			return {
				"kind": "block",
				"display_id": "block",
				"amount": amount,
				"status_id": "",
				"target": "self",
			}
	elif intent.begins_with("apply_status_"):
		var payload := intent.trim_prefix("apply_status_")
		if payload.ends_with("_player"):
			var parsed := _parse_status_payload(payload.trim_suffix("_player"))
			if not parsed.is_empty():
				parsed["kind"] = "apply_status"
				parsed["target"] = "player"
				return parsed
	elif intent.begins_with("self_status_"):
		var parsed := _parse_status_payload(intent.trim_prefix("self_status_"))
		if not parsed.is_empty():
			parsed["kind"] = "self_status"
			parsed["target"] = "self"
			return parsed
	return {
		"kind": "unknown",
		"display_id": UNKNOWN_DISPLAY_ID,
		"amount": 0,
		"status_id": "",
		"target": "",
	}

func _parse_status_payload(payload: String) -> Dictionary:
	var amount_separator := payload.rfind("_")
	if amount_separator <= 0 or amount_separator >= payload.length() - 1:
		return {}
	var status_id := payload.substr(0, amount_separator)
	var amount := _parse_positive_int(payload.substr(amount_separator + 1))
	if status_id.is_empty() or amount <= 0:
		return {}
	return {
		"display_id": "status.%s" % status_id,
		"amount": amount,
		"status_id": status_id,
	}

func _parse_positive_int(text: String) -> int:
	if not text.is_valid_int():
		return -1
	return int(text)

func _display_for(catalog: Object, display_id: String):
	if catalog == null or not catalog.has_method("get_enemy_intent_display"):
		return null
	return catalog.get_enemy_intent_display(display_id)

func _fallback_without_resource(intent: String) -> Dictionary:
	return {
		"raw_intent": intent,
		"kind": "unknown",
		"display_id": UNKNOWN_DISPLAY_ID,
		"icon_key": "unknown",
		"label": "Unknown",
		"amount": 0,
		"status_id": "",
		"target": "",
		"color": Color(0.72, 0.72, 0.72, 1),
		"show_amount": false,
		"show_target": false,
		"is_known": false,
	}
