extends RefCounted

const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunProgression := preload("res://scripts/run/run_progression.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_progression_marks_current_visited_and_unlocks_next_node() -> bool:
	var run := _run_with_nodes(0)
	var advanced := RunProgression.new().advance_current_node(run)
	var passed: bool = advanced \
		and run.map_nodes[0].visited \
		and run.map_nodes[1].unlocked \
		and not run.completed
	assert(passed)
	return passed

func test_progression_completes_run_on_final_node() -> bool:
	var run := _run_with_nodes(1)
	var advanced := RunProgression.new().advance_current_node(run)
	var passed: bool = advanced \
		and run.map_nodes[1].visited \
		and run.completed
	assert(passed)
	return passed

func test_progression_returns_false_for_missing_current_node() -> bool:
	var run := _run_with_nodes(0)
	run.current_node_id = "missing"
	var advanced := RunProgression.new().advance_current_node(run)
	var passed: bool = not advanced and not run.map_nodes[0].visited
	assert(passed)
	return passed

func _run_with_nodes(current_index: int) -> RunState:
	var run := RunState.new()
	var first := MapNodeState.new("node_0", 0, "event")
	first.unlocked = true
	var second := MapNodeState.new("node_1", 1, "combat")
	run.map_nodes = [first, second]
	run.current_node_id = run.map_nodes[current_index].id
	return run
