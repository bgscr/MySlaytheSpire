class_name SaveService
extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

var save_path := "user://run_save.json"

func _init(path: String = "user://run_save.json") -> void:
	save_path = path

func save_run(run: RunState) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(run.to_dict()))

func load_run() -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return null

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	var parsed = json.data
	if not parsed is Dictionary:
		return null

	var payload: Dictionary = parsed
	if not _is_valid_run_payload(payload):
		return null

	var run := RunState.new()
	run.version = int(payload["version"])
	run.seed_value = int(payload["seed_value"])
	run.character_id = payload["character_id"]
	run.current_hp = int(payload["current_hp"])
	run.max_hp = int(payload["max_hp"])
	run.gold = int(payload["gold"])
	run.deck_ids.assign(payload["deck_ids"])
	run.relic_ids.assign(payload["relic_ids"])
	run.map_nodes = _load_map_nodes(payload["map_nodes"])
	run.current_node_id = payload["current_node_id"]
	var shop_state: Dictionary = payload.get("current_shop_state", {})
	run.current_shop_state = shop_state.duplicate(true)
	var reward_state: Dictionary = payload.get("current_reward_state", {})
	run.current_reward_state = reward_state.duplicate(true)
	run.completed = payload["completed"]
	run.failed = payload["failed"]
	return run

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _is_valid_run_payload(payload: Dictionary) -> bool:
	return _has_int(payload, "version") \
		and _has_int(payload, "seed_value") \
		and _has_string(payload, "character_id") \
		and _has_int(payload, "current_hp") \
		and _has_int(payload, "max_hp") \
		and _has_int(payload, "gold") \
		and _has_string_array(payload, "deck_ids") \
		and _has_string_array(payload, "relic_ids") \
		and _has_valid_map_nodes(payload, "map_nodes") \
		and _has_string(payload, "current_node_id") \
		and _has_optional_dictionary(payload, "current_shop_state") \
		and _has_optional_reward_state(payload, "current_reward_state") \
		and _has_bool(payload, "completed") \
		and _has_bool(payload, "failed")

func _has_int(payload: Dictionary, key: String) -> bool:
	return payload.has(key) and _is_int_value(payload[key])

func _has_string(payload: Dictionary, key: String) -> bool:
	return payload.has(key) and payload[key] is String

func _has_optional_dictionary(payload: Dictionary, key: String) -> bool:
	return not payload.has(key) or payload[key] is Dictionary

func _has_optional_reward_state(payload: Dictionary, key: String) -> bool:
	if not payload.has(key):
		return true
	if not payload[key] is Dictionary:
		return false
	var reward_state: Dictionary = payload[key]
	if reward_state.is_empty():
		return true
	return _has_string(reward_state, "source") \
		and _has_string(reward_state, "node_id") \
		and _has_string(reward_state, "event_id") \
		and _has_string(reward_state, "option_id") \
		and _has_valid_reward_list(reward_state, "rewards")

func _has_valid_reward_list(payload: Dictionary, key: String) -> bool:
	if not payload.has(key) or not payload[key] is Array:
		return false
	for reward in payload[key]:
		if not reward is Dictionary:
			return false
		var reward_payload: Dictionary = reward
		if not _has_string(reward_payload, "id") or not _has_string(reward_payload, "type"):
			return false
		match String(reward_payload["type"]):
			"card_choice":
				if not _has_string_array(reward_payload, "card_ids"):
					return false
			"gold":
				if not _has_int(reward_payload, "amount"):
					return false
			"relic":
				if not _has_string(reward_payload, "relic_id"):
					return false
			_:
				return false
	return true

func _has_bool(payload: Dictionary, key: String) -> bool:
	return payload.has(key) and payload[key] is bool

func _has_string_array(payload: Dictionary, key: String) -> bool:
	if not payload.has(key) or not payload[key] is Array:
		return false
	for item in payload[key]:
		if not item is String:
			return false
	return true

func _has_valid_map_nodes(payload: Dictionary, key: String) -> bool:
	if not payload.has(key) or not payload[key] is Array:
		return false
	for node_payload in payload[key]:
		if not node_payload is Dictionary:
			return false
		if not _has_string(node_payload, "id") \
			or not _has_int(node_payload, "layer") \
			or not _has_string(node_payload, "node_type") \
			or not _has_bool(node_payload, "visited") \
			or not _has_bool(node_payload, "unlocked"):
			return false
	return true

func _is_int_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return value == floor(value)
	return false

func _load_map_nodes(node_payloads: Array) -> Array:
	var nodes := []
	for node_payload in node_payloads:
		var payload: Dictionary = node_payload
		var node := MapNodeState.new(
			payload["id"],
			int(payload["layer"]),
			payload["node_type"]
		)
		node.visited = payload["visited"]
		node.unlocked = payload["unlocked"]
		nodes.append(node)
	return nodes
