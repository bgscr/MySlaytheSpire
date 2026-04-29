extends RefCounted

const DevToolsScreen := preload("res://scripts/ui/dev_tools_screen.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")

func test_dev_tools_card_browser_loads_all_cards_with_all_filters() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	var cards := screen.filtered_cards()
	var passed: bool = cards.size() == 40 \
		and cards[0].id == "alchemy.bitter_extract"
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_card_browser_filters_with_and_semantics() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("sword", "common", "attack")
	var cards := screen.filtered_cards()
	var ids := _ids(cards)
	var passed: bool = ids.has("sword.strike") \
		and cards.size() == 6 \
		and cards[0].id == "sword.flash_cut" \
		and _all_cards_match(cards, "sword", "common", "attack")
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_card_browser_keeps_matching_selection_after_filter_change() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	screen.select_card("sword.strike")
	screen.set_filters("sword", "common", "attack")
	var passed: bool = screen.selected_card_id == "sword.strike"
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_card_browser_selects_first_match_when_selection_is_filtered_out() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_filters("all", "all", "all")
	screen.select_card("alchemy.toxic_pill")
	screen.set_filters("sword", "common", "attack")
	var passed: bool = screen.selected_card_id == "sword.flash_cut"
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_card_detail_text_includes_effects_and_presentation_cues() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var card = screen.catalog.get_card("sword.strike")
	var detail := screen.card_detail_text(card)
	var passed: bool = detail.contains("id: sword.strike") \
		and detail.contains("cost: 1") \
		and detail.contains("effect: damage target=enemy amount=6") \
		and detail.contains("cue: cinematic_slash target_mode=played_target")
	screen.free()
	assert(passed)
	return passed

func test_dev_tools_exposes_deferred_tool_placeholders() -> bool:
	var screen := DevToolsScreen.new()
	var tool_ids := screen.tool_ids()
	var passed: bool = tool_ids == [
		"card_browser",
		"enemy_sandbox",
		"event_tester",
		"reward_inspector",
		"save_inspector",
	] \
		and screen.placeholder_text("enemy_sandbox").contains("Enemy Sandbox") \
		and screen.placeholder_text("enemy_sandbox").contains("Planned tool")
	screen.free()
	assert(passed)
	return passed

func test_enemy_sandbox_exposes_deterministic_enemy_ids() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var enemy_ids: Array[String] = screen.enemy_sandbox_enemy_ids()
	var passed: bool = enemy_ids.size() == 16 \
		and enemy_ids.has("training_puppet") \
		and enemy_ids.find("training_puppet") < enemy_ids.find("forest_bandit") \
		and enemy_ids.find("forest_bandit") < enemy_ids.find("boss_heart_demon")
	screen.free()
	assert(passed)
	return passed

func test_enemy_sandbox_default_config_uses_sword_starter_and_training_puppet() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var config: Dictionary = screen.enemy_sandbox_config()
	var passed: bool = config.get("character_id") == "sword" \
		and config.get("deck_ids") == ["sword.strike", "sword.strike", "sword.strike"] \
		and config.get("enemy_ids") == ["training_puppet"] \
		and config.get("seed_value") == 1
	screen.free()
	assert(passed)
	return passed

func test_enemy_sandbox_selection_keeps_unique_valid_first_three_enemies() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_enemy_sandbox_enemies([
		"training_puppet",
		"missing_enemy",
		"training_puppet",
		"wild_fox_spirit",
		"ash_lantern_cultist",
		"stone_grove_guardian",
	])
	var passed: bool = screen.selected_sandbox_enemy_ids == [
		"training_puppet",
		"wild_fox_spirit",
		"ash_lantern_cultist",
	]
	screen.free()
	assert(passed)
	return passed

func test_enemy_sandbox_summary_includes_character_deck_and_enemy_details() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_enemy_sandbox_character("alchemy")
	screen.set_enemy_sandbox_enemies(["training_puppet"])
	var summary: String = screen.enemy_sandbox_summary_text()
	var passed: bool = summary.contains("character: alchemy") \
		and summary.contains("deck: alchemy.toxic_pill, alchemy.toxic_pill, alchemy.toxic_pill") \
		and summary.contains("enemy: training_puppet tier=normal hp=20 intents=attack_5")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_exposes_deterministic_event_ids() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var event_ids: Array[String] = screen.event_tester_event_ids()
	var passed: bool = event_ids.size() == 12 \
		and event_ids[0] == "alchemist_market" \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_default_config_uses_sword_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var config: Dictionary = screen.event_tester_config()
	var run: Variant = screen.event_tester_run
	var passed: bool = config.get("event_id") == "alchemist_market" \
		and config.get("character_id") == "sword" \
		and config.get("seed_value") == 1 \
		and config.get("gold") == 50 \
		and config.get("deck_ids") == ["sword.strike", "sword.strike", "sword.strike"] \
		and run != null \
		and run.character_id == "sword" \
		and run.current_hp == 72 \
		and run.max_hp == 72 \
		and run.current_node_id == "event_tester_node"
	screen.free()
	assert(passed)
	return passed

func test_event_tester_option_text_includes_availability_and_effects() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_event_tester_event("tea_house_rumor")
	var reward_text: String = screen.event_tester_option_text(1)
	screen.set_event_tester_event("forgotten_armory")
	var grant_text: String = screen.event_tester_option_text(0)
	screen.set_event_tester_event("withered_master")
	var remove_text: String = screen.event_tester_option_text(0)
	var passed: bool = reward_text.contains("option: buy_rumor") \
		and reward_text.contains("available") \
		and reward_text.contains("min_gold=18") \
		and reward_text.contains("gold_delta=-18") \
		and reward_text.contains("card_reward_count=3") \
		and grant_text.contains("grant_cards=sword.flash_cut") \
		and remove_text.contains("remove_card=sword.strike")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_apply_option_mutates_only_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var applied: bool = screen.apply_event_tester_option(0)
	var summary: String = screen.event_tester_run_summary_text()
	var passed: bool = applied \
		and screen.event_tester_option_applied \
		and screen.event_tester_result_text == "Applied option: buy_brew" \
		and screen.event_tester_run.gold == 30 \
		and screen.event_tester_run.current_hp == 72 \
		and summary.contains("gold: 30") \
		and summary.contains("pending_rewards: none")
	screen.free()
	assert(passed)
	return passed

func test_event_tester_pending_reward_and_reset_are_visible() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_event_tester_event("tea_house_rumor")
	var applied: bool = screen.apply_event_tester_option(1)
	var summary_after: String = screen.event_tester_run_summary_text()
	screen.reset_event_tester_run()
	var summary_reset: String = screen.event_tester_run_summary_text()
	var passed: bool = applied \
		and summary_after.contains("gold: 32") \
		and summary_after.contains("pending_rewards: 1") \
		and not screen.event_tester_option_applied \
		and screen.event_tester_result_text.is_empty() \
		and summary_reset.contains("gold: 50") \
		and summary_reset.contains("pending_rewards: none")
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_default_config_uses_sword_combat_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var config: Dictionary = screen.reward_inspector_config()
	var run: Variant = screen.reward_inspector_run
	var passed: bool = config.get("character_id") == "sword" \
		and config.get("node_type") == "combat" \
		and config.get("seed_value") == 1 \
		and config.get("deck_ids") == ["sword.strike", "sword.strike", "sword.strike"] \
		and run != null \
		and run.character_id == "sword" \
		and run.current_node_id == "reward_inspector_node" \
		and run.map_nodes.size() == 1 \
		and run.map_nodes[0].node_type == "combat"
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_rewards_match_resolver_for_current_config() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	screen.set_reward_inspector_node_type("boss")
	screen.set_reward_inspector_seed(222)
	var expected: Array[Dictionary] = RewardResolver.new().resolve(screen.catalog, screen.reward_inspector_run)
	var passed: bool = screen.reward_inspector_rewards == expected \
		and expected.size() == 3 \
		and screen.reward_inspector_reward_text(0).contains("type: card_choice") \
		and screen.reward_inspector_reward_text(1).contains("type: gold") \
		and screen.reward_inspector_reward_text(2).contains("type: relic")
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_claim_card_mutates_only_isolated_run() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var before_size: int = screen.reward_inspector_run.deck_ids.size()
	var claimed: bool = screen.claim_reward_inspector_card(0, 0)
	var summary: String = screen.reward_inspector_run_summary_text()
	var passed: bool = claimed \
		and screen.reward_inspector_run.deck_ids.size() == before_size + 1 \
		and screen.reward_inspector_reward_states[0] == "claimed" \
		and summary.contains("resolved: 1/2") \
		and summary.contains("deck_count: 4")
	screen.free()
	assert(passed)
	return passed

func test_reward_inspector_skip_and_reset_clear_reward_state() -> bool:
	var screen := DevToolsScreen.new()
	screen.load_default_catalog()
	var skipped: bool = screen.skip_reward_inspector_reward(1)
	screen.reset_reward_inspector_run()
	var passed: bool = skipped \
		and screen.reward_inspector_run.gold == 0 \
		and screen.reward_inspector_reward_states.size() == screen.reward_inspector_rewards.size() \
		and screen.reward_inspector_reward_states[0] == "available" \
		and screen.reward_inspector_run_summary_text().contains("resolved: 0/2")
	screen.free()
	assert(passed)
	return passed

func _ids(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		result.append(card.id)
	return result

func _all_cards_match(cards: Array, character_id: String, rarity: String, card_type: String) -> bool:
	for card in cards:
		if card.character_id != character_id or card.rarity != rarity or card.card_type != card_type:
			return false
	return true
