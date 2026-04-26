extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const SaveService := preload("res://scripts/save/save_service.gd")
const LocalPlatformService := preload("res://scripts/platform/local_platform_service.gd")

func test_save_round_trip_preserves_run_state() -> bool:
	var run := RunState.new()
	run.seed_value = 42
	run.character_id = "sword"
	run.current_hp = 55
	run.max_hp = 72
	run.gold = 99
	run.deck_ids = ["sword.strike"]
	var service := SaveService.new("user://test_run_save.json")
	service.save_run(run)

	var loaded := service.load_run()
	var passed: bool = loaded != null \
		and loaded.seed_value == 42 \
		and loaded.character_id == "sword" \
		and loaded.current_hp == 55 \
		and loaded.max_hp == 72 \
		and loaded.gold == 99 \
		and loaded.deck_ids.size() == 1 \
		and loaded.deck_ids[0] == "sword.strike"
	assert(passed)
	service.delete_save()
	return passed

func test_save_round_trip_preserves_map_progress() -> bool:
	var run := RunState.new()
	run.current_node_id = "node_1"

	var first_node := MapNodeState.new("node_0", 0, "combat")
	first_node.visited = true
	first_node.unlocked = true
	var second_node := MapNodeState.new("node_1", 1, "shop")
	second_node.visited = false
	second_node.unlocked = true
	run.map_nodes = [first_node, second_node]

	var service := SaveService.new("user://test_run_map_save.json")
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

func test_local_platform_service_records_achievements_and_stats() -> bool:
	var service := LocalPlatformService.new()
	service.unlock_achievement("first_victory")
	service.set_stat("runs_started", 3)
	var passed: bool = service.achievements.get("first_victory", false) == true \
		and service.stats.get("runs_started", 0) == 3 \
		and service.get_platform_language() == "zh_CN"
	assert(passed)
	return passed
