extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const SaveService := preload("res://scripts/save/save_service.gd")
const LocalPlatformService := preload("res://scripts/platform/local_platform_service.gd")

func test_save_round_trip_preserves_run_state() -> bool:
	var save_path := "user://test_run_save.json"
	_delete_test_save(save_path)
	var run := RunState.new()
	run.version = 2
	run.seed_value = 42
	run.character_id = "sword"
	run.current_hp = 55
	run.max_hp = 72
	run.gold = 99
	run.deck_ids = ["sword.strike"]
	run.relic_ids = ["burning_blood"]
	run.completed = true
	run.failed = false
	var service := SaveService.new(save_path)
	service.save_run(run)

	var loaded := service.load_run()
	var passed: bool = loaded != null \
		and loaded.version == 2 \
		and loaded.seed_value == 42 \
		and loaded.character_id == "sword" \
		and loaded.current_hp == 55 \
		and loaded.max_hp == 72 \
		and loaded.gold == 99 \
		and loaded.deck_ids.size() == 1 \
		and loaded.deck_ids[0] == "sword.strike" \
		and loaded.relic_ids.size() == 1 \
		and loaded.relic_ids[0] == "burning_blood" \
		and loaded.completed == true \
		and loaded.failed == false

	run.completed = false
	run.failed = true
	service.save_run(run)
	loaded = service.load_run()
	passed = passed \
		and loaded != null \
		and loaded.version == 2 \
		and loaded.relic_ids.size() == 1 \
		and loaded.relic_ids[0] == "burning_blood" \
		and loaded.completed == false \
		and loaded.failed == true
	assert(passed)
	service.delete_save()
	return passed

func test_save_round_trip_preserves_map_progress() -> bool:
	var save_path := "user://test_run_map_save.json"
	_delete_test_save(save_path)
	var run := RunState.new()
	run.current_node_id = "node_1"

	var first_node := MapNodeState.new("node_0", 0, "combat")
	first_node.visited = true
	first_node.unlocked = true
	var second_node := MapNodeState.new("node_1", 1, "shop")
	second_node.visited = false
	second_node.unlocked = true
	run.map_nodes = [first_node, second_node]

	var service := SaveService.new(save_path)
	service.save_run(run)

	var loaded := service.load_run()
	var passed: bool = loaded != null \
		and loaded.current_node_id == "node_1" \
		and loaded.map_nodes.size() == 2
	if loaded != null and loaded.map_nodes.size() == 2:
		var loaded_first = loaded.map_nodes[0]
		var loaded_second = loaded.map_nodes[1]
		passed = passed \
			and loaded_first.id == "node_0" \
			and loaded_first.layer == 0 \
			and loaded_first.node_type == "combat" \
			and loaded_first.visited == true \
			and loaded_first.unlocked == true \
			and loaded_second.id == "node_1" \
			and loaded_second.layer == 1 \
			and loaded_second.node_type == "shop" \
			and loaded_second.visited == false \
			and loaded_second.unlocked == true
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_when_save_missing() -> bool:
	var save_path := "user://test_missing_run_save.json"
	_delete_test_save(save_path)
	var service := SaveService.new(save_path)

	var passed: bool = service.load_run() == null
	assert(passed)
	return passed

func test_load_run_returns_null_for_invalid_json() -> bool:
	var save_path := "user://test_invalid_json_run_save.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, "{"):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_field_types() -> bool:
	var save_path := "user://test_invalid_field_types_run_save.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": "bad",
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_map_nodes_type() -> bool:
	var save_path := "user://test_invalid_map_nodes_run_save.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": "bad",
		"current_node_id": "",
		"completed": false,
		"failed": false,
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed

func test_has_save_reports_save_presence() -> bool:
	var save_path := "user://test_has_run_save.json"
	_delete_test_save(save_path)
	var service := SaveService.new(save_path)
	var absent_before_save := service.has_save() == false

	var run := RunState.new()
	service.save_run(run)
	var present_after_save := service.has_save() == true

	var passed: bool = absent_before_save and present_after_save
	assert(passed)
	service.delete_save()
	return passed

func test_delete_save_removes_saved_run() -> bool:
	var save_path := "user://test_delete_run_save.json"
	_delete_test_save(save_path)
	var service := SaveService.new(save_path)
	var run := RunState.new()
	service.save_run(run)
	service.delete_save()

	var passed: bool = service.has_save() == false and service.load_run() == null
	assert(passed)
	return passed

func test_local_platform_service_records_achievements_and_stats() -> bool:
	var service := LocalPlatformService.new()
	service.unlock_achievement("first_victory")
	service.set_stat("runs_started", 3)
	var passed: bool = service.achievements.get("first_victory", false) == true \
		and service.stats.get("runs_started", 0) == 3 \
		and service.get_platform_language() == "zh_CN"
	assert(passed)
	return passed

func test_save_round_trip_preserves_current_shop_state() -> bool:
	var save_path := "user://test_shop_state_save.json"
	_delete_test_save(save_path)
	var run := RunState.new()
	run.current_shop_state = {
		"node_id": "node_shop",
		"refresh_used": true,
		"offers": [
			{
				"id": "relic_0",
				"type": "relic",
				"item_id": "jade_talisman",
				"price": 120,
				"sold": true,
			},
		],
	}
	var service := SaveService.new(save_path)
	service.save_run(run)

	var loaded := service.load_run()
	var loaded_shop_state: Dictionary = loaded.current_shop_state if loaded != null else {}
	var offers: Array = loaded_shop_state.get("offers", [])
	var passed: bool = loaded != null \
		and loaded_shop_state.get("node_id") == "node_shop" \
		and loaded_shop_state.get("refresh_used") == true \
		and offers.size() == 1 \
		and (offers[0] as Dictionary).get("id") == "relic_0" \
		and (offers[0] as Dictionary).get("sold") == true
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_accepts_legacy_save_without_shop_state() -> bool:
	var save_path := "user://test_legacy_without_shop_state.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var loaded := service.load_run()
	var passed: bool = loaded != null and loaded.current_shop_state.is_empty()
	assert(passed)
	service.delete_save()
	return passed

func test_load_run_returns_null_for_invalid_shop_state_type() -> bool:
	var save_path := "user://test_invalid_shop_state_type.json"
	_delete_test_save(save_path)
	if not _write_test_save(save_path, JSON.stringify({
		"version": 1,
		"seed_value": 42,
		"character_id": "sword",
		"current_hp": 55,
		"max_hp": 72,
		"gold": 99,
		"deck_ids": [],
		"relic_ids": [],
		"map_nodes": [],
		"current_node_id": "",
		"completed": false,
		"failed": false,
		"current_shop_state": "bad",
	})):
		assert(false)
		return false

	var service := SaveService.new(save_path)
	var passed: bool = service.load_run() == null
	assert(passed)
	service.delete_save()
	return passed

func _delete_test_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_test_save(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true
