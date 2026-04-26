extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")

func test_card_rewards_are_deterministic_for_same_seed_and_context() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var first := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var second := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var passed: bool = first == second and first.get("card_ids", []).has("sword.strike")
	assert(passed)
	return passed

func test_card_rewards_use_character_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 77, "alchemy", "node_1")
	var ids: Array = reward.get("card_ids", [])
	var passed: bool = ids.has("alchemy.toxic_pill") and not ids.has("sword.strike")
	assert(passed)
	return passed

func test_card_rewards_respect_requested_count() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 77, "sword", "node_1", 0)
	var ids: Array = reward.get("card_ids", [])
	var passed: bool = ids.is_empty()
	assert(passed)
	return passed

func test_gold_rewards_are_deterministic_and_tiered() -> bool:
	var generator := RewardGenerator.new()
	var normal := generator.generate_gold_reward(77, "node_1", "normal")
	var normal_again := generator.generate_gold_reward(77, "node_1", "normal")
	var elite := generator.generate_gold_reward(77, "node_1", "elite")
	var passed: bool = normal == normal_again \
		and normal.get("amount", 0) >= 8 \
		and normal.get("amount", 0) <= 14 \
		and elite.get("amount", 0) >= 18 \
		and elite.get("amount", 0) <= 28
	assert(passed)
	return passed

func test_relic_rewards_are_deterministic() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var first := generator.generate_relic_reward(catalog, 99, "node_2", "common")
	var second := generator.generate_relic_reward(catalog, 99, "node_2", "common")
	var passed: bool = first == second and first.get("relic_id") == "jade_talisman"
	assert(passed)
	return passed

func test_relic_rewards_return_empty_id_for_empty_pool() -> bool:
	var catalog := _catalog()
	catalog.relics_by_id.clear()
	var generator := RewardGenerator.new()
	var reward := generator.generate_relic_reward(catalog, 99, "node_2", "common")
	var passed: bool = reward.get("type") == "relic" \
		and reward.get("tier") == "common" \
		and reward.get("relic_id") == ""
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog
