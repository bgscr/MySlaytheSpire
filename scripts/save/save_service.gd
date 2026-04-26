class_name SaveService
extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

var save_path := "user://run_save.json"

func _init(path: String = "user://run_save.json") -> void:
	save_path = path

func save_run(run: RunState) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(run.to_dict()))

func load_run() -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return null

	var payload: Dictionary = parsed
	var run := RunState.new()
	run.version = payload.get("version", 1)
	run.seed_value = payload.get("seed_value", 1)
	run.character_id = payload.get("character_id", "")
	run.current_hp = payload.get("current_hp", 1)
	run.max_hp = payload.get("max_hp", 1)
	run.gold = payload.get("gold", 0)
	run.deck_ids.assign(payload.get("deck_ids", []))
	run.relic_ids.assign(payload.get("relic_ids", []))
	run.map_nodes = _load_map_nodes(payload.get("map_nodes", []))
	run.current_node_id = payload.get("current_node_id", "")
	run.completed = payload.get("completed", false)
	run.failed = payload.get("failed", false)
	return run

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _load_map_nodes(node_payloads: Array) -> Array:
	var nodes := []
	for node_payload in node_payloads:
		if not node_payload is Dictionary:
			continue
		var payload: Dictionary = node_payload
		var node := MapNodeState.new(
			payload.get("id", ""),
			payload.get("layer", 0),
			payload.get("node_type", "combat")
		)
		node.visited = payload.get("visited", false)
		node.unlocked = payload.get("unlocked", false)
		nodes.append(node)
	return nodes
