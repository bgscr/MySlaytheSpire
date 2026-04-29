extends RefCounted

const DevToolsScreen := preload("res://scripts/ui/dev_tools_screen.gd")

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
