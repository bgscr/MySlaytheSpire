extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_combat_node_generates_card_choice_and_gold_only() -> bool:
	var rewards := RewardResolver.new().resolve(_catalog(), _run_for_node("combat", 111))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var passed: bool = rewards.size() == 2 \
		and not card.is_empty() \
		and not gold.is_empty() \
		and relic.is_empty() \
		and _array_value_count(card.get("card_ids", [])) == 3 \
		and int(gold.get("amount", 0)) >= 8 \
		and int(gold.get("amount", 0)) <= 14
	assert(passed)
	return passed

func test_elite_node_generates_card_gold_and_deterministic_relic_chance() -> bool:
	var catalog := _catalog()
	var saw_relic := false
	var saw_no_relic := false
	var sampled_packages_valid := true
	for seed in range(1, 80):
		var rewards := RewardResolver.new().resolve(catalog, _run_for_node("elite", seed))
		var card := _find_reward(rewards, "card_choice")
		var gold := _find_reward(rewards, "gold")
		var relic := _find_reward(rewards, "relic")
		var card_ids: Array = card.get("card_ids", [])
		var gold_amount := int(gold.get("amount", 0))
		sampled_packages_valid = sampled_packages_valid \
			and not card.is_empty() \
			and card_ids.size() == 3 \
			and not gold.is_empty() \
			and gold_amount >= 18 \
			and gold_amount <= 28
		if relic.is_empty():
			saw_no_relic = true
			sampled_packages_valid = sampled_packages_valid and rewards.size() == 2
		else:
			var has_uncommon_relic := String(relic.get("tier", "")) == "uncommon" \
				and not String(relic.get("relic_id", "")).is_empty()
			saw_relic = saw_relic or has_uncommon_relic
			sampled_packages_valid = sampled_packages_valid \
				and rewards.size() == 3 \
				and has_uncommon_relic
		if not sampled_packages_valid or saw_relic and saw_no_relic:
			break
	var passed: bool = sampled_packages_valid and saw_relic and saw_no_relic
	assert(passed)
	return passed

func test_boss_node_generates_rare_preferred_card_gold_and_rare_relic() -> bool:
	var catalog := _catalog()
	var rewards := RewardResolver.new().resolve(catalog, _run_for_node("boss", 222))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var card_ids: Array = card.get("card_ids", [])
	var first_card := catalog.get_card(String(card_ids[0])) if card_ids.size() > 0 else null
	var passed: bool = rewards.size() == 3 \
		and card_ids.size() == 3 \
		and first_card != null \
		and first_card.rarity == "rare" \
		and int(gold.get("amount", 0)) >= 40 \
		and int(gold.get("amount", 0)) <= 60 \
		and String(relic.get("tier", "")) == "rare" \
		and not String(relic.get("relic_id", "")).is_empty()
	assert(passed)
	return passed

func test_missing_current_node_returns_empty_reward_package() -> bool:
	var run := _run_for_node("combat", 333)
	run.current_node_id = "missing_node"
	var rewards := RewardResolver.new().resolve(_catalog(), run)
	var passed := rewards.is_empty()
	assert(passed)
	return passed

func test_unsupported_node_type_returns_empty_reward_package() -> bool:
	var rewards := RewardResolver.new().resolve(_catalog(), _run_for_node("shop", 666))
	var passed := rewards.is_empty()
	assert(passed)
	return passed

func test_empty_relic_pool_omits_relic_reward_item() -> bool:
	var catalog := _catalog()
	catalog.relics_by_id.clear()
	var rewards := RewardResolver.new().resolve(catalog, _run_for_node("boss", 444))
	var card := _find_reward(rewards, "card_choice")
	var gold := _find_reward(rewards, "gold")
	var relic := _find_reward(rewards, "relic")
	var passed: bool = rewards.size() == 2 \
		and not card.is_empty() \
		and not gold.is_empty() \
		and relic.is_empty()
	assert(passed)
	return passed

func test_resolver_is_deterministic_for_same_run_context() -> bool:
	var catalog := _catalog()
	var run := _run_for_node("elite", 555)
	var first := RewardResolver.new().resolve(catalog, run)
	var second := RewardResolver.new().resolve(catalog, run)
	var passed := first == second
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_for_node(node_type: String, seed_value: int) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.character_id = "sword"
	run.current_node_id = "node_0"
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	var node := MapNodeState.new("node_0", 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run

func _find_reward(rewards: Array[Dictionary], reward_type: String) -> Dictionary:
	for reward in rewards:
		if String(reward.get("type", "")) == reward_type:
			return reward
	return {}

func _array_value_count(values: Array) -> int:
	return values.size()
