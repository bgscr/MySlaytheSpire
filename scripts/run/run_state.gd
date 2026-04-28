class_name RunState
extends RefCounted

var version := 1
var seed_value := 1
var character_id := ""
var current_hp := 1
var max_hp := 1
var gold := 0
var deck_ids: Array[String] = []
var relic_ids: Array[String] = []
var map_nodes: Array = []
var current_node_id := ""
var current_shop_state: Dictionary = {}
var current_reward_state: Dictionary = {}
var completed := false
var failed := false

func to_dict() -> Dictionary:
	var node_payload := []
	for node in map_nodes:
		node_payload.append({
			"id": node.id,
			"layer": node.layer,
			"node_type": node.node_type,
			"visited": node.visited,
			"unlocked": node.unlocked,
		})
	return {
		"version": version,
		"seed_value": seed_value,
		"character_id": character_id,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck_ids": deck_ids.duplicate(),
		"relic_ids": relic_ids.duplicate(),
		"map_nodes": node_payload,
		"current_node_id": current_node_id,
		"current_shop_state": current_shop_state.duplicate(true),
		"current_reward_state": current_reward_state.duplicate(true),
		"completed": completed,
		"failed": failed,
	}
