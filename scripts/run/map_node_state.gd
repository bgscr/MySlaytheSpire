class_name MapNodeState
extends RefCounted

var id: String
var layer: int
var node_type: String
var visited := false
var unlocked := false

func _init(node_id: String = "", node_layer: int = 0, type: String = "combat") -> void:
	id = node_id
	layer = node_layer
	node_type = type
