class_name RewardResolver
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

const NORMAL_CARD_WEIGHTS := {
	"common": 75,
	"uncommon": 20,
	"rare": 5,
}
const ELITE_CARD_WEIGHTS := {
	"common": 45,
	"uncommon": 40,
	"rare": 15,
}
const ELITE_RELIC_CHANCE := 0.5

var generator := RewardGenerator.new()

func resolve(catalog: ContentCatalog, run: RunState) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if catalog == null or run == null:
		return rewards
	var node := _current_node(run)
	if node == null:
		return rewards
	match node.node_type:
		"elite":
			_append_weighted_card_choice(rewards, catalog, run, node, ELITE_CARD_WEIGHTS)
			_append_gold(rewards, run, node, "elite")
			if _should_offer_elite_relic(run, node):
				_append_relic(rewards, catalog, run, node, "uncommon")
		"boss":
			_append_boss_card_choice(rewards, catalog, run, node)
			_append_gold(rewards, run, node, "boss")
			_append_relic(rewards, catalog, run, node, "rare")
		"combat":
			_append_weighted_card_choice(rewards, catalog, run, node, NORMAL_CARD_WEIGHTS)
			_append_gold(rewards, run, node, "normal")
	return rewards

func _append_weighted_card_choice(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState,
	rarity_weights: Dictionary
) -> void:
	var reward := generator.generate_weighted_card_reward(
		catalog,
		run.seed_value,
		run.character_id,
		"%s:%s" % [node.id, node.node_type],
		rarity_weights,
		3
	)
	_append_card_choice_from_reward(rewards, node, reward)

func _append_boss_card_choice(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState
) -> void:
	var reward := generator.generate_rare_preferred_card_reward(
		catalog,
		run.seed_value,
		run.character_id,
		"%s:%s" % [node.id, node.node_type],
		3
	)
	_append_card_choice_from_reward(rewards, node, reward)

func _append_card_choice_from_reward(
	rewards: Array[Dictionary],
	node: MapNodeState,
	reward: Dictionary
) -> void:
	var card_ids: Array = reward.get("card_ids", [])
	if card_ids.is_empty():
		return
	rewards.append({
		"id": "card:%s" % node.id,
		"type": "card_choice",
		"card_ids": card_ids,
	})

func _append_gold(rewards: Array[Dictionary], run: RunState, node: MapNodeState, tier: String) -> void:
	var reward := generator.generate_gold_reward(run.seed_value, node.id, tier)
	rewards.append({
		"id": "gold:%s" % node.id,
		"type": "gold",
		"amount": int(reward.get("amount", 0)),
		"tier": tier,
	})

func _append_relic(
	rewards: Array[Dictionary],
	catalog: ContentCatalog,
	run: RunState,
	node: MapNodeState,
	tier: String
) -> void:
	var reward := generator.generate_relic_reward(catalog, run.seed_value, node.id, tier)
	var relic_id := String(reward.get("relic_id", ""))
	if relic_id.is_empty():
		return
	rewards.append({
		"id": "relic:%s" % node.id,
		"type": "relic",
		"relic_id": relic_id,
		"tier": tier,
	})

func _should_offer_elite_relic(run: RunState, node: MapNodeState) -> bool:
	var rng := RngService.new(run.seed_value).fork("reward:elite_relic:%s" % node.id)
	return rng.next_float() < ELITE_RELIC_CHANCE

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
