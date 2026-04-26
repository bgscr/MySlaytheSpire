extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_to_dict_serializes_run_and_map_nodes() -> bool:
	var run := RunState.new()
	run.seed_value = 12345
	run.character_id = "ironclad"
	run.current_hp = 37
	run.max_hp = 80
	run.gold = 99
	run.deck_ids = ["strike", "defend", "bash"]
	run.relic_ids = ["burning_blood", "vajra"]
	run.current_node_id = "node_1"
	run.completed = true
	run.failed = false

	var first_node := MapNodeState.new("node_0", 0, "combat")
	first_node.visited = true
	first_node.unlocked = true
	var second_node := MapNodeState.new("node_1", 1, "shop")
	second_node.visited = false
	second_node.unlocked = true
	run.map_nodes = [first_node, second_node]

	var payload := run.to_dict()
	var nodes: Array = payload.get("map_nodes", [])
	var passed: bool = payload.get("version") == 1 \
		and payload.get("seed_value") == 12345 \
		and payload.get("character_id") == "ironclad" \
		and payload.get("current_hp") == 37 \
		and payload.get("max_hp") == 80 \
		and payload.get("gold") == 99 \
		and payload.get("deck_ids") == ["strike", "defend", "bash"] \
		and payload.get("relic_ids") == ["burning_blood", "vajra"] \
		and payload.get("current_node_id") == "node_1" \
		and payload.get("completed") == true \
		and payload.get("failed") == false \
		and nodes.size() == 2
	if nodes.size() == 2:
		var first_payload: Dictionary = nodes[0]
		var second_payload: Dictionary = nodes[1]
		passed = passed \
			and first_payload.get("id") == "node_0" \
			and first_payload.get("layer") == 0 \
			and first_payload.get("node_type") == "combat" \
			and first_payload.get("visited") == true \
			and first_payload.get("unlocked") == true \
			and second_payload.get("id") == "node_1" \
			and second_payload.get("layer") == 1 \
			and second_payload.get("node_type") == "shop" \
			and second_payload.get("visited") == false \
			and second_payload.get("unlocked") == true
	assert(passed)
	return passed

func test_to_dict_does_not_alias_deck_or_relic_arrays() -> bool:
	var run := RunState.new()
	run.deck_ids = ["strike", "defend"]
	run.relic_ids = ["burning_blood"]

	var payload := run.to_dict()
	payload["deck_ids"].append("bash")
	payload["relic_ids"].clear()

	var passed: bool = run.deck_ids == ["strike", "defend"] \
		and run.relic_ids == ["burning_blood"]
	assert(passed)
	return passed
