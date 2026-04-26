extends RefCounted

const MapGenerator := preload("res://scripts/run/map_generator.gd")

func test_same_seed_generates_same_map() -> bool:
	var first := MapGenerator.new().generate(1234)
	var second := MapGenerator.new().generate(1234)
	var passed: bool = first.size() == second.size()
	for i in range(min(first.size(), second.size())):
		passed = passed and first[i].id == second[i].id
		passed = passed and first[i].node_type == second[i].node_type
		passed = passed and first[i].layer == second[i].layer
		passed = passed and first[i].visited == second[i].visited
		passed = passed and first[i].unlocked == second[i].unlocked
	assert(passed)
	return passed

func test_map_has_boss_at_end() -> bool:
	var nodes := MapGenerator.new().generate(9)
	var passed: bool = nodes.size() == 7
	if nodes.size() == 7:
		var first_node = nodes[0]
		var boss_node = nodes[nodes.size() - 1]
		passed = passed \
			and first_node.id == "node_0" \
			and first_node.layer == 0 \
			and first_node.node_type == "combat" \
			and first_node.unlocked == true \
			and first_node.visited == false \
			and boss_node.id == "boss_0" \
			and boss_node.layer == 6 \
			and boss_node.node_type == "boss" \
			and boss_node.unlocked == false
	assert(passed)
	return passed

func test_different_seeds_change_non_fixed_node_types() -> bool:
	var first := MapGenerator.new().generate(1)
	var second := MapGenerator.new().generate(2)
	var type_differs := false
	for i in range(1, min(first.size(), second.size()) - 1):
		if first[i].node_type != second[i].node_type:
			type_differs = true
			break
	var passed := type_differs
	assert(passed)
	return passed
