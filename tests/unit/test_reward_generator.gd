extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CardDef := preload("res://scripts/data/card_def.gd")
const RewardGenerator := preload("res://scripts/reward/reward_generator.gd")

func test_card_rewards_are_deterministic_for_same_seed_and_context() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var first := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var second := generator.generate_card_reward(catalog, 77, "sword", "node_1")
	var ids: Array = first.get("card_ids", [])
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = first == second \
		and ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool)
	assert(passed)
	return passed

func test_card_rewards_use_character_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 77, "alchemy", "node_1")
	var ids: Array = reward.get("card_ids", [])
	var alchemy_pool := _ids(catalog.get_cards_for_character("alchemy"))
	var passed: bool = ids.size() == 3 \
		and _all_values_in_pool(ids, alchemy_pool) \
		and not ids.has("sword.strike")
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

func test_relic_rewards_draw_from_each_populated_wave_c_tier() -> bool:
	var catalog := _catalog()
	var common := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_common", "common")
	var uncommon := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_uncommon", "uncommon")
	var rare := RewardGenerator.new().generate_relic_reward(catalog, 1, "wave_c_rare", "rare")
	var passed: bool = not String(common.get("relic_id", "")).is_empty() \
		and not String(uncommon.get("relic_id", "")).is_empty() \
		and not String(rare.get("relic_id", "")).is_empty()
	assert(passed)
	return passed

func test_sword_reward_draws_three_unique_cards_from_expanded_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 177, "sword", "expanded_pool", 3)
	var ids: Array = reward.get("card_ids", [])
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and not ids.has("alchemy.toxic_pill")
	assert(passed)
	return passed

func test_alchemy_reward_draws_three_unique_cards_from_expanded_pool() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward := generator.generate_card_reward(catalog, 177, "alchemy", "expanded_pool", 3)
	var ids: Array = reward.get("card_ids", [])
	var alchemy_pool := _ids(catalog.get_cards_for_character("alchemy"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, alchemy_pool) \
		and not ids.has("sword.strike")
	assert(passed)
	return passed

func test_weighted_card_rewards_are_deterministic_and_character_scoped() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var weights := {
		"common": 75,
		"uncommon": 20,
		"rare": 5,
	}
	var first: Dictionary = generator.generate_weighted_card_reward(catalog, 501, "sword", "weighted_node", weights, 3)
	var second: Dictionary = generator.generate_weighted_card_reward(catalog, 501, "sword", "weighted_node", weights, 3)
	var ids: Array = first.get("card_ids", [])
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = first == second \
		and ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and not ids.has("alchemy.toxic_pill")
	assert(passed)
	return passed

func test_weighted_card_rewards_ignore_rarity_weight_dictionary_insertion_order() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var canonical_weights := {}
	canonical_weights["common"] = 1
	canonical_weights["uncommon"] = 1
	canonical_weights["rare"] = 1
	var reordered_weights := {}
	reordered_weights["rare"] = 1
	reordered_weights["uncommon"] = 1
	reordered_weights["common"] = 1
	var passed := true
	for seed_value in range(520, 540):
		var canonical: Dictionary = generator.generate_weighted_card_reward(catalog, seed_value, "sword", "order_stable", canonical_weights, 3)
		var reordered: Dictionary = generator.generate_weighted_card_reward(catalog, seed_value, "sword", "order_stable", reordered_weights, 3)
		if canonical != reordered:
			passed = false
			break
	assert(passed)
	return passed

func test_weighted_card_rewards_honor_requested_rarity_when_available() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward: Dictionary = generator.generate_weighted_card_reward(catalog, 502, "sword", "rare_only", {
		"rare": 100,
	}, 1)
	var ids: Array = reward.get("card_ids", [])
	var card := catalog.get_card(String(ids[0])) if ids.size() > 0 else null
	var passed: bool = ids.size() == 1 \
		and card != null \
		and card.rarity == "rare"
	assert(passed)
	return passed

func test_rare_preferred_card_reward_uses_rare_first_and_fills_lower_rarities() -> bool:
	var catalog := _catalog()
	var generator := RewardGenerator.new()
	var reward: Dictionary = generator.generate_rare_preferred_card_reward(catalog, 503, "sword", "boss_node", 3)
	var ids: Array = reward.get("card_ids", [])
	var rarities := _rarities_for_ids(catalog, ids)
	var sword_pool := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = ids.size() == 3 \
		and _unique_count(ids) == 3 \
		and _all_values_in_pool(ids, sword_pool) \
		and rarities.size() == 3 \
		and rarities[0] == "rare" \
		and rarities.has("uncommon")
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids

func _rarities_for_ids(catalog: ContentCatalog, card_ids: Array) -> Array[String]:
	var rarities: Array[String] = []
	for card_id in card_ids:
		var card := catalog.get_card(String(card_id))
		if card != null:
			rarities.append(card.rarity)
	return rarities

func _unique_count(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()

func _all_values_in_pool(values: Array, pool: Array[String]) -> bool:
	for value in values:
		if not pool.has(value):
			return false
	return true
