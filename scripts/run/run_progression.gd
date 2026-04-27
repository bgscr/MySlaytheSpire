class_name RunProgression
extends RefCounted

const RunState := preload("res://scripts/run/run_state.gd")

func advance_current_node(run: RunState) -> bool:
	if run == null:
		return false
	var current_index := -1
	for i in range(run.map_nodes.size()):
		if run.map_nodes[i].id == run.current_node_id:
			current_index = i
			run.map_nodes[i].visited = true
			break
	if current_index == -1:
		return false
	if current_index + 1 < run.map_nodes.size():
		run.map_nodes[current_index + 1].unlocked = true
	else:
		run.completed = true
	return true
