extends RefCounted

const MapGenerator := preload("res://scripts/run/map_generator.gd")

func test_same_seed_generates_same_map() -> bool:
	var first := MapGenerator.new().generate(1234)
	var second := MapGenerator.new().generate(1234)
	var passed: bool = first.size() == second.size()
	for i in range(first.size()):
		passed = passed and first[i].node_type == second[i].node_type
		passed = passed and first[i].layer == second[i].layer
	assert(passed)
	return passed

func test_map_has_boss_at_end() -> bool:
	var nodes := MapGenerator.new().generate(9)
	var passed: bool = nodes[nodes.size() - 1].node_type == "boss"
	assert(passed)
	return passed
