class_name MapGenerator
extends RefCounted

const RngService := preload("res://scripts/core/rng_service.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")

func generate(seed_value: int) -> Array:
	var rng = RngService.new(seed_value).fork("map")
	var nodes: Array = []
	var node_types := ["combat", "combat", "event", "shop", "elite"]
	for layer in range(0, 6):
		var node_type = "combat" if layer == 0 else rng.pick(node_types)
		var node := MapNodeState.new("node_%s" % layer, layer, node_type)
		node.unlocked = layer == 0
		nodes.append(node)
	nodes.append(MapNodeState.new("boss_0", 6, "boss"))
	return nodes
