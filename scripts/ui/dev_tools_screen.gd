extends Control

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
const RewardResolver := preload("res://scripts/reward/reward_resolver.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const SaveService := preload("res://scripts/save/save_service.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

const TOOL_CARD_BROWSER := "card_browser"
const TOOL_ENEMY_SANDBOX := "enemy_sandbox"
const TOOL_EVENT_TESTER := "event_tester"
const TOOL_REWARD_INSPECTOR := "reward_inspector"
const TOOL_SAVE_INSPECTOR := "save_inspector"
const FILTER_ALL := "all"
const DEFAULT_SANDBOX_CHARACTER := "sword"
const DEFAULT_SANDBOX_ENEMY := "training_puppet"
const DEFAULT_EVENT_TESTER_CHARACTER := "sword"
const DEFAULT_EVENT_TESTER_GOLD := 50
const DEFAULT_EVENT_TESTER_SEED := 1
const EVENT_TESTER_NODE_ID := "event_tester_node"
const DEFAULT_REWARD_INSPECTOR_CHARACTER := "sword"
const DEFAULT_REWARD_INSPECTOR_NODE_TYPE := "combat"
const DEFAULT_REWARD_INSPECTOR_SEED := 1
const REWARD_INSPECTOR_NODE_ID := "reward_inspector_node"
const REWARD_INSPECTOR_NODE_TYPES: Array[String] = ["combat", "elite", "boss"]
const REWARD_STATE_AVAILABLE := "available"
const REWARD_STATE_CLAIMED := "claimed"
const REWARD_STATE_SKIPPED := "skipped"
const SAVE_STATUS_MISSING_SERVICE := "missing_service"
const SAVE_STATUS_NO_SAVE := "no_save"
const SAVE_STATUS_INVALID := "invalid"
const SAVE_STATUS_TERMINAL := "terminal"
const SAVE_STATUS_ACTIVE := "active"
const SAVE_RESUME_NONE := "none"
const SAVE_RESUME_INVALID_DELETE_ON_CONTINUE := "invalid_delete_on_continue"
const SAVE_RESUME_TERMINAL_DELETE_ON_CONTINUE := "terminal_delete_on_continue"
const SAVE_RESUME_REWARD := "reward"
const SAVE_RESUME_SHOP := "shop"
const SAVE_RESUME_MAP := "map"
const RARITY_ORDER := {"common": 0, "uncommon": 1, "rare": 2}
const TYPE_ORDER := {"attack": 0, "skill": 1, "power": 2}
const ENEMY_TIER_ORDER := {"normal": 0, "elite": 1, "boss": 2}
const TOOL_LABELS := {
	"card_browser": "Card Browser",
	"enemy_sandbox": "Enemy Sandbox",
	"event_tester": "Event Tester",
	"reward_inspector": "Reward Inspector",
	"save_inspector": "Save Inspector",
}

var catalog := ContentCatalog.new()
var active_tool_id := TOOL_CARD_BROWSER
var selected_card_id := ""
var character_filter := FILTER_ALL
var rarity_filter := FILTER_ALL
var card_type_filter := FILTER_ALL
var selected_sandbox_character_id := DEFAULT_SANDBOX_CHARACTER
var selected_sandbox_enemy_ids: Array[String] = []
var selected_event_tester_event_id := ""
var selected_event_tester_character_id := DEFAULT_EVENT_TESTER_CHARACTER
var event_tester_run: RunState
var event_tester_option_applied := false
var event_tester_result_text := ""
var selected_reward_inspector_character_id := DEFAULT_REWARD_INSPECTOR_CHARACTER
var selected_reward_inspector_node_type := DEFAULT_REWARD_INSPECTOR_NODE_TYPE
var selected_reward_inspector_seed := DEFAULT_REWARD_INSPECTOR_SEED
var reward_inspector_run: RunState
var reward_inspector_rewards: Array[Dictionary] = []
var reward_inspector_reward_states: Array[String] = []
var save_inspector_save_service_override: Variant
var save_inspector_current_snapshot: Dictionary = {}
var save_inspector_status_label: Label
var save_inspector_resume_target_label: Label
var save_inspector_run_summary_label: Label
var save_inspector_state_sections: VBoxContainer
var save_inspector_map_section_label: Label
var save_inspector_shop_section_label: Label
var save_inspector_reward_section_label: Label
var reward_applier := RewardApplier.new()
var tool_content: VBoxContainer
var card_list: VBoxContainer
var card_detail_label: Label
var character_filter_button: OptionButton
var rarity_filter_button: OptionButton
var type_filter_button: OptionButton
var enemy_sandbox_character_select: OptionButton
var enemy_sandbox_deck_label: Label
var enemy_sandbox_enemy_list: VBoxContainer
var enemy_sandbox_summary_label: Label
var event_tester_event_select: OptionButton
var event_tester_character_select: OptionButton
var event_tester_run_summary_label: Label
var event_tester_option_list: VBoxContainer
var event_tester_result_label: Label
var reward_inspector_character_select: OptionButton
var reward_inspector_node_type_select: OptionButton
var reward_inspector_seed_spin_box: SpinBox
var reward_inspector_run_summary_label: Label
var reward_inspector_reward_list: VBoxContainer

func _ready() -> void:
	if catalog.cards_by_id.is_empty():
		catalog.load_default()
	_ensure_enemy_sandbox_defaults()
	reset_event_tester_run()
	reset_reward_inspector_run()
	_build_layout()
	_show_tool(TOOL_CARD_BROWSER)

func load_default_catalog() -> void:
	catalog.load_default()
	_refresh_selected_card()
	_ensure_enemy_sandbox_defaults()
	reset_event_tester_run()
	reset_reward_inspector_run()

func tool_ids() -> Array[String]:
	return [
		TOOL_CARD_BROWSER,
		TOOL_ENEMY_SANDBOX,
		TOOL_EVENT_TESTER,
		TOOL_REWARD_INSPECTOR,
		TOOL_SAVE_INSPECTOR,
	]

func set_filters(character_id: String, rarity: String, card_type: String) -> void:
	character_filter = character_id
	rarity_filter = rarity
	card_type_filter = card_type
	_refresh_selected_card()
	_refresh_card_browser_if_ready()

func select_card(card_id: String) -> void:
	if catalog.get_card(card_id) == null:
		return
	selected_card_id = card_id
	_refresh_card_browser_if_ready()

func filtered_cards() -> Array[CardDef]:
	var result: Array[CardDef] = []
	for card: CardDef in catalog.cards_by_id.values():
		if _card_matches_filters(card):
			result.append(card)
	result.sort_custom(func(a: CardDef, b: CardDef): return _card_less(a, b))
	return result

func card_detail_text(card: CardDef) -> String:
	if card == null:
		return "No card selected"
	var lines: Array[String] = [
		"id: %s" % card.id,
		"name_key: %s" % card.name_key,
		"description_key: %s" % card.description_key,
		"character: %s" % card.character_id,
		"rarity: %s" % card.rarity,
		"type: %s" % card.card_type,
		"cost: %s" % card.cost,
		"tags: %s" % _join_string_array(card.tags),
		"pool_tags: %s" % _join_string_array(card.pool_tags),
		"reward_weight: %s" % card.reward_weight,
	]
	if card.effects.is_empty():
		lines.append("effects: none")
	else:
		for effect in card.effects:
			lines.append(_effect_text(effect))
	if card.presentation_cues.is_empty():
		lines.append("presentation_cues: none")
	else:
		for cue in card.presentation_cues:
			lines.append(_cue_text(cue))
	return "\n".join(lines)

func placeholder_text(tool_id: String) -> String:
	return "%s\nPlanned tool" % String(TOOL_LABELS.get(tool_id, tool_id))

func enemy_sandbox_enemy_ids() -> Array[String]:
	var enemies: Array[EnemyDef] = []
	for enemy: EnemyDef in catalog.enemies_by_id.values():
		enemies.append(enemy)
	enemies.sort_custom(func(a: EnemyDef, b: EnemyDef): return _enemy_less(a, b))
	var result: Array[String] = []
	for enemy in enemies:
		result.append(enemy.id)
	return result

func set_enemy_sandbox_character(character_id: String) -> void:
	if catalog.get_character(character_id) == null:
		return
	selected_sandbox_character_id = character_id
	_refresh_enemy_sandbox_if_ready()

func set_enemy_sandbox_enemies(enemy_ids: Array[String]) -> void:
	selected_sandbox_enemy_ids = _normalized_enemy_ids(enemy_ids)
	_refresh_enemy_sandbox_if_ready()

func toggle_enemy_sandbox_enemy(enemy_id: String) -> void:
	if catalog.get_enemy(enemy_id) == null:
		return
	if selected_sandbox_enemy_ids.has(enemy_id):
		if selected_sandbox_enemy_ids.size() > 1:
			selected_sandbox_enemy_ids.erase(enemy_id)
	elif selected_sandbox_enemy_ids.size() < 3:
		selected_sandbox_enemy_ids.append(enemy_id)
	_refresh_enemy_sandbox_if_ready()

func enemy_sandbox_config() -> Dictionary:
	_ensure_enemy_sandbox_defaults()
	var character := catalog.get_character(selected_sandbox_character_id)
	var deck_ids: Array[String] = []
	if character != null:
		deck_ids = _copy_string_array(character.starting_deck_ids)
	return {
		"character_id": selected_sandbox_character_id,
		"deck_ids": deck_ids,
		"enemy_ids": selected_sandbox_enemy_ids.duplicate(),
		"seed_value": 1,
	}

func enemy_sandbox_summary_text() -> String:
	_ensure_enemy_sandbox_defaults()
	var config := enemy_sandbox_config()
	var lines: Array[String] = [
		"character: %s" % String(config.get("character_id", "")),
		"deck: %s" % _join_string_array(config.get("deck_ids", [])),
	]
	for enemy_id: String in config.get("enemy_ids", []):
		var enemy := catalog.get_enemy(enemy_id)
		if enemy == null:
			continue
		lines.append("enemy: %s tier=%s hp=%s intents=%s" % [
			enemy.id,
			enemy.tier,
			enemy.max_hp,
			_join_string_array(enemy.intent_sequence),
		])
	return "\n".join(lines)

func event_tester_event_ids() -> Array[String]:
	var result: Array[String] = []
	for event_id in catalog.events_by_id.keys():
		result.append(String(event_id))
	result.sort()
	return result

func set_event_tester_event(event_id: String) -> void:
	if catalog.get_event(event_id) == null:
		return
	selected_event_tester_event_id = event_id
	reset_event_tester_run()
	_refresh_event_tester_if_ready()

func set_event_tester_character(character_id: String) -> void:
	if catalog.get_character(character_id) == null:
		return
	selected_event_tester_character_id = character_id
	reset_event_tester_run()
	_refresh_event_tester_if_ready()

func reset_event_tester_run() -> void:
	_ensure_event_tester_defaults()
	event_tester_run = _create_event_tester_run()
	event_tester_option_applied = false
	event_tester_result_text = ""

func event_tester_config() -> Dictionary:
	_ensure_event_tester_defaults()
	if event_tester_run == null:
		event_tester_run = _create_event_tester_run()
	return {
		"event_id": selected_event_tester_event_id,
		"character_id": selected_event_tester_character_id,
		"seed_value": event_tester_run.seed_value,
		"gold": event_tester_run.gold,
		"deck_ids": event_tester_run.deck_ids.duplicate(),
	}

func event_tester_run_summary_text() -> String:
	if event_tester_run == null:
		reset_event_tester_run()
	var pending_rewards: Array = event_tester_run.current_reward_state.get("rewards", [])
	return "\n".join([
		"event: %s" % selected_event_tester_event_id,
		"character: %s" % event_tester_run.character_id,
		"hp: %s/%s" % [event_tester_run.current_hp, event_tester_run.max_hp],
		"gold: %s" % event_tester_run.gold,
		"deck: %s" % _join_string_array(event_tester_run.deck_ids),
		"relics: %s" % _join_string_array(event_tester_run.relic_ids),
		"pending_rewards: %s" % ("none" if pending_rewards.is_empty() else str(pending_rewards.size())),
	])

func event_tester_option_text(index: int) -> String:
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null or index < 0 or index >= event.options.size():
		return "option: unavailable"
	if event_tester_run == null:
		reset_event_tester_run()
	var option: EventOptionDef = event.options[index]
	var runner := EventRunner.new()
	var available := runner.is_option_available(event_tester_run, option)
	var lines: Array[String] = [
		"option: %s" % option.id,
		"state: %s" % ("available" if available else "blocked"),
	]
	var reason := runner.unavailable_reason(event_tester_run, option)
	if not reason.is_empty():
		lines.append("reason=%s" % reason)
	if option.min_hp > 0:
		lines.append("min_hp=%s" % option.min_hp)
	if option.min_gold > 0:
		lines.append("min_gold=%s" % option.min_gold)
	if option.hp_delta != 0:
		lines.append("hp_delta=%s" % option.hp_delta)
	if option.gold_delta != 0:
		lines.append("gold_delta=%s" % option.gold_delta)
	if not option.remove_card_id.is_empty():
		lines.append("remove_card=%s" % option.remove_card_id)
	if not option.grant_card_ids.is_empty():
		lines.append("grant_cards=%s" % _join_string_array(option.grant_card_ids))
	if not option.grant_relic_ids.is_empty():
		lines.append("grant_relics=%s" % _join_string_array(option.grant_relic_ids))
	if option.card_reward_count > 0:
		lines.append("card_reward_count=%s" % option.card_reward_count)
	if not option.relic_reward_tier.is_empty():
		lines.append("relic_reward_tier=%s" % option.relic_reward_tier)
	return " | ".join(lines)

func apply_event_tester_option(index: int) -> bool:
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null or event_tester_run == null or event_tester_option_applied:
		return false
	if index < 0 or index >= event.options.size():
		return false
	var option: EventOptionDef = event.options[index]
	var applied := EventRunner.new().apply_event_option(catalog, event_tester_run, event, option)
	if applied:
		event_tester_option_applied = true
		event_tester_result_text = "Applied option: %s" % option.id
	else:
		event_tester_result_text = "Option failed: %s" % option.id
	_refresh_event_tester_after_apply()
	return applied

func set_reward_inspector_character(character_id: String) -> void:
	if catalog.get_character(character_id) == null:
		return
	selected_reward_inspector_character_id = character_id
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func set_reward_inspector_node_type(node_type: String) -> void:
	if not REWARD_INSPECTOR_NODE_TYPES.has(node_type):
		return
	selected_reward_inspector_node_type = node_type
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func set_reward_inspector_seed(seed_value: int) -> void:
	selected_reward_inspector_seed = max(1, seed_value)
	reset_reward_inspector_run()
	_refresh_reward_inspector_if_ready()

func reset_reward_inspector_run() -> void:
	_ensure_reward_inspector_defaults()
	reward_inspector_run = _create_reward_inspector_run()
	reward_inspector_rewards = RewardResolver.new().resolve(catalog, reward_inspector_run)
	reward_inspector_reward_states.clear()
	for _reward in reward_inspector_rewards:
		reward_inspector_reward_states.append(REWARD_STATE_AVAILABLE)

func reward_inspector_config() -> Dictionary:
	_ensure_reward_inspector_defaults()
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	return {
		"character_id": selected_reward_inspector_character_id,
		"node_type": selected_reward_inspector_node_type,
		"seed_value": selected_reward_inspector_seed,
		"deck_ids": reward_inspector_run.deck_ids.duplicate(),
	}

func reward_inspector_run_summary_text() -> String:
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	return "\n".join([
		"character: %s" % reward_inspector_run.character_id,
		"node_type: %s" % selected_reward_inspector_node_type,
		"seed: %s" % selected_reward_inspector_seed,
		"hp: %s/%s" % [reward_inspector_run.current_hp, reward_inspector_run.max_hp],
		"gold: %s" % reward_inspector_run.gold,
		"deck_count: %s" % reward_inspector_run.deck_ids.size(),
		"deck: %s" % _join_string_array(reward_inspector_run.deck_ids),
		"relics: %s" % _join_string_array(reward_inspector_run.relic_ids),
		"resolved: %s/%s" % [_resolved_reward_inspector_count(), reward_inspector_rewards.size()],
	])

func reward_inspector_reward_text(index: int) -> String:
	if index < 0 or index >= reward_inspector_rewards.size():
		return "reward: unavailable"
	var reward := reward_inspector_rewards[index]
	var lines: Array[String] = [
		"reward: %s" % String(reward.get("id", "")),
		"type: %s" % String(reward.get("type", "")),
		"state: %s" % reward_inspector_reward_states[index],
	]
	match String(reward.get("type", "")):
		"card_choice":
			var card_ids: Array = reward.get("card_ids", [])
			lines.append("cards: %s" % _join_variant_string_array(card_ids))
		"gold":
			lines.append("amount: %s" % int(reward.get("amount", 0)))
			lines.append("tier: %s" % String(reward.get("tier", "")))
		"relic":
			lines.append("relic: %s" % String(reward.get("relic_id", "")))
			lines.append("tier: %s" % String(reward.get("tier", "")))
	return " | ".join(lines)

func claim_reward_inspector_card(reward_index: int, card_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_card(reward_inspector_run, reward_inspector_rewards[reward_index], card_index):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_after_resolution(reward_index)
		return true
	return false

func claim_reward_inspector_gold(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_gold(reward_inspector_run, reward_inspector_rewards[reward_index]):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_after_resolution(reward_index)
		return true
	return false

func claim_reward_inspector_relic(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	if reward_applier.claim_relic(reward_inspector_run, reward_inspector_rewards[reward_index]):
		reward_inspector_reward_states[reward_index] = REWARD_STATE_CLAIMED
		_refresh_reward_inspector_after_resolution(reward_index)
		return true
	return false

func skip_reward_inspector_reward(reward_index: int) -> bool:
	if not _is_reward_inspector_reward_available(reward_index):
		return false
	reward_inspector_reward_states[reward_index] = REWARD_STATE_SKIPPED
	_refresh_reward_inspector_after_resolution(reward_index)
	return true

func set_save_inspector_save_service_override(service: Variant) -> void:
	save_inspector_save_service_override = service
	refresh_save_inspector()

func refresh_save_inspector() -> void:
	save_inspector_current_snapshot = _build_save_inspector_snapshot()
	_refresh_save_inspector_if_ready()

func save_inspector_snapshot() -> Dictionary:
	if save_inspector_current_snapshot.is_empty():
		save_inspector_current_snapshot = _build_save_inspector_snapshot()
	return save_inspector_current_snapshot

func save_inspector_resume_target() -> String:
	return String(save_inspector_snapshot().get("resume_target", SAVE_RESUME_NONE))

func save_inspector_status_text() -> String:
	var snapshot := save_inspector_snapshot()
	return "\n".join([
		"status: %s" % String(snapshot.get("status", SAVE_STATUS_MISSING_SERVICE)),
		"has_service: %s" % _bool_text(bool(snapshot.get("has_service", false))),
		"has_save: %s" % _bool_text(bool(snapshot.get("has_save", false))),
		"reason: %s" % String(snapshot.get("reason", "")),
	])

func save_inspector_summary_text() -> String:
	var snapshot := save_inspector_snapshot()
	var run: RunState = snapshot.get("run", null)
	if run == null:
		return "run: none"
	return "\n".join([
		"version: %s" % run.version,
		"seed: %s" % run.seed_value,
		"character: %s" % run.character_id,
		"hp: %s/%s" % [run.current_hp, run.max_hp],
		"gold: %s" % run.gold,
		"deck_count: %s" % run.deck_ids.size(),
		"relic_count: %s" % run.relic_ids.size(),
		"current_node_id: %s" % run.current_node_id,
		"current_node_type: %s" % _save_inspector_current_node_type(run),
		"completed: %s" % _bool_text(run.completed),
		"failed: %s" % _bool_text(run.failed),
	])

func save_inspector_map_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "map: none"
	var visited_count := 0
	var unlocked_count := 0
	for node in run.map_nodes:
		if node.visited:
			visited_count += 1
		if node.unlocked:
			unlocked_count += 1
	return "\n".join([
		"map_nodes: %s" % run.map_nodes.size(),
		"current_node_id: %s" % run.current_node_id,
		"current_node_type: %s" % _save_inspector_current_node_type(run),
		"visited_count: %s" % visited_count,
		"unlocked_count: %s" % unlocked_count,
	])

func save_inspector_shop_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "shop_state: none"
	if run.current_shop_state.is_empty():
		return "shop_state: empty"
	var offers: Array = run.current_shop_state.get("offers", [])
	var sold_count := 0
	for offer in offers:
		if not offer is Dictionary:
			continue
		var payload: Dictionary = offer
		if bool(payload.get("sold", false)):
			sold_count += 1
	var matching := _save_inspector_shop_state_matches(run)
	return "\n".join([
		"shop_state: %s" % ("matching" if matching else "mismatched"),
		"node_id: %s" % String(run.current_shop_state.get("node_id", "")),
		"offers: %s" % offers.size(),
		"sold: %s" % sold_count,
	])

func save_inspector_reward_text() -> String:
	var run: RunState = save_inspector_snapshot().get("run", null)
	if run == null:
		return "reward_state: none"
	if run.current_reward_state.is_empty():
		return "reward_state: empty"
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var matching := _save_inspector_reward_state_matches(run)
	return "\n".join([
		"reward_state: %s" % ("matching" if matching else "mismatched"),
		"source: %s" % String(run.current_reward_state.get("source", "")),
		"node_id: %s" % String(run.current_reward_state.get("node_id", "")),
		"event_id: %s" % String(run.current_reward_state.get("event_id", "")),
		"option_id: %s" % String(run.current_reward_state.get("option_id", "")),
		"rewards: %s" % rewards.size(),
	])

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.name = "DevToolsRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.name = "DevToolsTitle"
	title.text = "DevTools"
	root.add_child(title)

	var tool_nav := HBoxContainer.new()
	tool_nav.name = "ToolNav"
	root.add_child(tool_nav)
	for tool_id in tool_ids():
		var button := Button.new()
		button.name = "ToolButton_%s" % tool_id
		button.text = String(TOOL_LABELS.get(tool_id, tool_id))
		var selected_tool_id := tool_id
		button.pressed.connect(func(): _show_tool(selected_tool_id))
		tool_nav.add_child(button)

	tool_content = VBoxContainer.new()
	tool_content.name = "ToolContent"
	root.add_child(tool_content)

func _show_tool(tool_id: String) -> void:
	active_tool_id = tool_id
	_clear_save_inspector_refs()
	_clear_children(tool_content)
	if tool_id == TOOL_CARD_BROWSER:
		_build_card_browser()
	elif tool_id == TOOL_ENEMY_SANDBOX:
		_build_enemy_sandbox()
	elif tool_id == TOOL_EVENT_TESTER:
		_build_event_tester()
	elif tool_id == TOOL_REWARD_INSPECTOR:
		_build_reward_inspector()
	elif tool_id == TOOL_SAVE_INSPECTOR:
		_build_save_inspector()
	else:
		var placeholder := Label.new()
		placeholder.name = "ToolPlaceholder_%s" % tool_id
		placeholder.text = placeholder_text(tool_id)
		tool_content.add_child(placeholder)

func _build_card_browser() -> void:
	var panel := VBoxContainer.new()
	panel.name = "CardBrowserPanel"
	tool_content.add_child(panel)

	var filters := HBoxContainer.new()
	filters.name = "CardBrowserFilters"
	panel.add_child(filters)
	character_filter_button = _add_filter(filters, "CharacterFilter", ["all", "alchemy", "sword"], character_filter, _on_character_filter_selected)
	rarity_filter_button = _add_filter(filters, "RarityFilter", ["all", "common", "uncommon", "rare"], rarity_filter, _on_rarity_filter_selected)
	type_filter_button = _add_filter(filters, "TypeFilter", ["all", "attack", "skill", "power"], card_type_filter, _on_type_filter_selected)

	var body := HBoxContainer.new()
	body.name = "CardBrowserBody"
	panel.add_child(body)

	card_list = VBoxContainer.new()
	card_list.name = "CardList"
	body.add_child(card_list)

	card_detail_label = Label.new()
	card_detail_label.name = "CardDetailLabel"
	card_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(card_detail_label)

	_refresh_card_browser()

func _add_filter(parent: Node, node_name: String, values: Array[String], selected_value: String, callback: Callable) -> OptionButton:
	var filter := OptionButton.new()
	filter.name = node_name
	for value in values:
		filter.add_item(value)
		if value == selected_value:
			filter.select(filter.get_item_count() - 1)
	filter.item_selected.connect(callback)
	parent.add_child(filter)
	return filter

func _on_character_filter_selected(index: int) -> void:
	set_filters(character_filter_button.get_item_text(index), rarity_filter, card_type_filter)

func _on_rarity_filter_selected(index: int) -> void:
	set_filters(character_filter, rarity_filter_button.get_item_text(index), card_type_filter)

func _on_type_filter_selected(index: int) -> void:
	set_filters(character_filter, rarity_filter, type_filter_button.get_item_text(index))

func _refresh_card_browser_if_ready() -> void:
	if card_list != null and card_detail_label != null:
		_refresh_card_browser()

func _refresh_card_browser() -> void:
	var cards := filtered_cards()
	_clear_children(card_list)
	if cards.is_empty():
		var empty := Label.new()
		empty.name = "NoMatchingCardsLabel"
		empty.text = "No cards match filters"
		card_list.add_child(empty)
		selected_card_id = ""
		card_detail_label.text = card_detail_text(null)
		return
	if selected_card_id.is_empty() or not _card_id_in_cards(selected_card_id, cards):
		selected_card_id = cards[0].id
	for card in cards:
		var button := Button.new()
		button.name = "CardBrowserCard_%s" % card.id.replace(".", "_")
		button.text = "%s | %s | %s | %s | %s" % [card.id, card.character_id, card.rarity, card.card_type, card.cost]
		button.disabled = card.id == selected_card_id
		var selected_id := card.id
		button.pressed.connect(func(): select_card(selected_id))
		card_list.add_child(button)
	card_detail_label.text = card_detail_text(catalog.get_card(selected_card_id))

func _build_enemy_sandbox() -> void:
	_ensure_enemy_sandbox_defaults()
	var panel := VBoxContainer.new()
	panel.name = "EnemySandboxPanel"
	tool_content.add_child(panel)

	enemy_sandbox_character_select = OptionButton.new()
	enemy_sandbox_character_select.name = "EnemySandboxCharacterSelect"
	for character_id in _enemy_sandbox_character_ids():
		enemy_sandbox_character_select.add_item(character_id)
		if character_id == selected_sandbox_character_id:
			enemy_sandbox_character_select.select(enemy_sandbox_character_select.get_item_count() - 1)
	enemy_sandbox_character_select.item_selected.connect(_on_enemy_sandbox_character_selected)
	panel.add_child(enemy_sandbox_character_select)

	enemy_sandbox_deck_label = Label.new()
	enemy_sandbox_deck_label.name = "EnemySandboxDeckLabel"
	panel.add_child(enemy_sandbox_deck_label)

	enemy_sandbox_enemy_list = VBoxContainer.new()
	enemy_sandbox_enemy_list.name = "EnemySandboxEnemyList"
	panel.add_child(enemy_sandbox_enemy_list)

	enemy_sandbox_summary_label = Label.new()
	enemy_sandbox_summary_label.name = "EnemySandboxSummaryLabel"
	enemy_sandbox_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(enemy_sandbox_summary_label)

	var launch := Button.new()
	launch.name = "EnemySandboxLaunchButton"
	launch.text = "Launch Sandbox"
	launch.pressed.connect(_launch_enemy_sandbox)
	panel.add_child(launch)

	_refresh_enemy_sandbox_panel()

func _on_enemy_sandbox_character_selected(index: int) -> void:
	if enemy_sandbox_character_select == null:
		return
	set_enemy_sandbox_character(enemy_sandbox_character_select.get_item_text(index))

func _refresh_enemy_sandbox_if_ready() -> void:
	if enemy_sandbox_enemy_list != null and enemy_sandbox_summary_label != null:
		_refresh_enemy_sandbox_panel()

func _refresh_enemy_sandbox_panel() -> void:
	_ensure_enemy_sandbox_defaults()
	var character := catalog.get_character(selected_sandbox_character_id)
	var deck_ids: Array[String] = []
	if character != null:
		deck_ids = _copy_string_array(character.starting_deck_ids)
	if enemy_sandbox_deck_label != null:
		enemy_sandbox_deck_label.text = "Starter deck: %s" % _join_string_array(deck_ids)
	if enemy_sandbox_enemy_list != null:
		_clear_children(enemy_sandbox_enemy_list)
		for enemy_id in enemy_sandbox_enemy_ids():
			var enemy := catalog.get_enemy(enemy_id)
			if enemy == null:
				continue
			var button := Button.new()
			button.name = "EnemySandboxEnemy_%s" % enemy.id
			var selected := selected_sandbox_enemy_ids.has(enemy.id)
			var marker := "[x]" if selected else "[ ]"
			button.text = "%s %s | %s | HP %s | %s" % [
				marker,
				enemy.id,
				enemy.tier,
				enemy.max_hp,
				_join_string_array(enemy.intent_sequence),
			]
			button.disabled = not selected and selected_sandbox_enemy_ids.size() >= 3
			var selected_enemy_id := enemy.id
			button.pressed.connect(func(): toggle_enemy_sandbox_enemy(selected_enemy_id))
			enemy_sandbox_enemy_list.add_child(button)
	if enemy_sandbox_summary_label != null:
		enemy_sandbox_summary_label.text = enemy_sandbox_summary_text()

func _launch_enemy_sandbox() -> void:
	var app := _get_app()
	if app == null or app.get("game") == null:
		return
	if not app.game.has_method("set_debug_combat_sandbox_config"):
		return
	app.game.set_debug_combat_sandbox_config(enemy_sandbox_config())
	app.game.router.go_to(SceneRouterScript.COMBAT)

func _build_event_tester() -> void:
	_ensure_event_tester_defaults()
	if event_tester_run == null:
		reset_event_tester_run()
	var panel := VBoxContainer.new()
	panel.name = "EventTesterPanel"
	tool_content.add_child(panel)

	event_tester_event_select = OptionButton.new()
	event_tester_event_select.name = "EventTesterEventSelect"
	for event_id in event_tester_event_ids():
		event_tester_event_select.add_item(event_id)
		if event_id == selected_event_tester_event_id:
			event_tester_event_select.select(event_tester_event_select.get_item_count() - 1)
	event_tester_event_select.item_selected.connect(_on_event_tester_event_selected)
	panel.add_child(event_tester_event_select)

	event_tester_character_select = OptionButton.new()
	event_tester_character_select.name = "EventTesterCharacterSelect"
	for character_id in _dev_tools_character_ids(DEFAULT_EVENT_TESTER_CHARACTER):
		event_tester_character_select.add_item(character_id)
		if character_id == selected_event_tester_character_id:
			event_tester_character_select.select(event_tester_character_select.get_item_count() - 1)
	event_tester_character_select.item_selected.connect(_on_event_tester_character_selected)
	panel.add_child(event_tester_character_select)

	event_tester_run_summary_label = Label.new()
	event_tester_run_summary_label.name = "EventTesterRunSummaryLabel"
	event_tester_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(event_tester_run_summary_label)

	event_tester_option_list = VBoxContainer.new()
	event_tester_option_list.name = "EventTesterOptionList"
	panel.add_child(event_tester_option_list)

	event_tester_result_label = Label.new()
	event_tester_result_label.name = "EventTesterResultLabel"
	panel.add_child(event_tester_result_label)

	var reset := Button.new()
	reset.name = "EventTesterResetButton"
	reset.text = "Reset Test Run"
	reset.pressed.connect(_on_event_tester_reset_pressed)
	panel.add_child(reset)

	_refresh_event_tester_panel()

func _on_event_tester_event_selected(index: int) -> void:
	if event_tester_event_select == null:
		return
	set_event_tester_event(event_tester_event_select.get_item_text(index))

func _on_event_tester_character_selected(index: int) -> void:
	if event_tester_character_select == null:
		return
	set_event_tester_character(event_tester_character_select.get_item_text(index))

func _on_event_tester_reset_pressed() -> void:
	reset_event_tester_run()
	_refresh_event_tester_panel()

func _refresh_event_tester_panel() -> void:
	if event_tester_run == null:
		reset_event_tester_run()
	if event_tester_run_summary_label != null:
		event_tester_run_summary_label.text = event_tester_run_summary_text()
	if event_tester_result_label != null:
		event_tester_result_label.text = event_tester_result_text
	if event_tester_option_list == null:
		return
	_clear_children(event_tester_option_list)
	var event := catalog.get_event(selected_event_tester_event_id)
	if event == null:
		var empty := Label.new()
		empty.name = "EventTesterNoEventLabel"
		empty.text = "No event available"
		event_tester_option_list.add_child(empty)
		return
	for i in range(event.options.size()):
		var option: EventOptionDef = event.options[i]
		var button := Button.new()
		button.name = "EventTesterOption_%s" % i
		button.text = event_tester_option_text(i)
		button.disabled = event_tester_option_applied or not EventRunner.new().is_option_available(event_tester_run, option)
		var option_index := i
		button.pressed.connect(func(): apply_event_tester_option(option_index))
		event_tester_option_list.add_child(button)

func _refresh_event_tester_after_apply() -> void:
	if event_tester_run_summary_label != null:
		event_tester_run_summary_label.text = event_tester_run_summary_text()
	if event_tester_result_label != null:
		event_tester_result_label.text = event_tester_result_text
	if event_tester_option_list == null:
		return
	for child in event_tester_option_list.get_children():
		if child is Button:
			var button := child as Button
			button.disabled = event_tester_option_applied or button.disabled

func _build_reward_inspector() -> void:
	_ensure_reward_inspector_defaults()
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	var panel := VBoxContainer.new()
	panel.name = "RewardInspectorPanel"
	tool_content.add_child(panel)

	reward_inspector_character_select = OptionButton.new()
	reward_inspector_character_select.name = "RewardInspectorCharacterSelect"
	for character_id in _dev_tools_character_ids(DEFAULT_REWARD_INSPECTOR_CHARACTER):
		reward_inspector_character_select.add_item(character_id)
		if character_id == selected_reward_inspector_character_id:
			reward_inspector_character_select.select(reward_inspector_character_select.get_item_count() - 1)
	reward_inspector_character_select.item_selected.connect(_on_reward_inspector_character_selected)
	panel.add_child(reward_inspector_character_select)

	reward_inspector_node_type_select = OptionButton.new()
	reward_inspector_node_type_select.name = "RewardInspectorNodeTypeSelect"
	for node_type in REWARD_INSPECTOR_NODE_TYPES:
		reward_inspector_node_type_select.add_item(node_type)
		if node_type == selected_reward_inspector_node_type:
			reward_inspector_node_type_select.select(reward_inspector_node_type_select.get_item_count() - 1)
	reward_inspector_node_type_select.item_selected.connect(_on_reward_inspector_node_type_selected)
	panel.add_child(reward_inspector_node_type_select)

	reward_inspector_seed_spin_box = SpinBox.new()
	reward_inspector_seed_spin_box.name = "RewardInspectorSeedSpinBox"
	reward_inspector_seed_spin_box.min_value = 1
	reward_inspector_seed_spin_box.max_value = 999999
	reward_inspector_seed_spin_box.step = 1
	reward_inspector_seed_spin_box.value = selected_reward_inspector_seed
	reward_inspector_seed_spin_box.value_changed.connect(_on_reward_inspector_seed_changed)
	panel.add_child(reward_inspector_seed_spin_box)

	reward_inspector_run_summary_label = Label.new()
	reward_inspector_run_summary_label.name = "RewardInspectorRunSummaryLabel"
	reward_inspector_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(reward_inspector_run_summary_label)

	reward_inspector_reward_list = VBoxContainer.new()
	reward_inspector_reward_list.name = "RewardInspectorRewardList"
	panel.add_child(reward_inspector_reward_list)

	var reset := Button.new()
	reset.name = "RewardInspectorResetButton"
	reset.text = "Reset Reward Run"
	reset.pressed.connect(_on_reward_inspector_reset_pressed)
	panel.add_child(reset)

	_refresh_reward_inspector_panel()

func _on_reward_inspector_character_selected(index: int) -> void:
	if reward_inspector_character_select == null:
		return
	set_reward_inspector_character(reward_inspector_character_select.get_item_text(index))

func _on_reward_inspector_node_type_selected(index: int) -> void:
	if reward_inspector_node_type_select == null:
		return
	set_reward_inspector_node_type(reward_inspector_node_type_select.get_item_text(index))

func _on_reward_inspector_seed_changed(value: float) -> void:
	set_reward_inspector_seed(int(value))

func _on_reward_inspector_reset_pressed() -> void:
	reset_reward_inspector_run()
	_refresh_reward_inspector_panel()

func _add_reward_inspector_reward_row(reward_index: int) -> void:
	var reward := reward_inspector_rewards[reward_index]
	var item := VBoxContainer.new()
	item.name = "RewardInspectorReward_%s" % reward_index
	reward_inspector_reward_list.add_child(item)

	var label := Label.new()
	label.name = "RewardInspectorRewardLabel_%s" % reward_index
	label.text = reward_inspector_reward_text(reward_index)
	item.add_child(label)

	if reward_inspector_reward_states[reward_index] != REWARD_STATE_AVAILABLE:
		return

	match String(reward.get("type", "")):
		"card_choice":
			var card_ids: Array = reward.get("card_ids", [])
			for card_index in range(card_ids.size()):
				var button := Button.new()
				button.name = "RewardInspectorClaimCard_%s_%s" % [reward_index, card_index]
				button.text = "Claim %s" % String(card_ids[card_index])
				var selected_reward_index := reward_index
				var selected_card_index := card_index
				button.pressed.connect(func(): claim_reward_inspector_card(selected_reward_index, selected_card_index))
				item.add_child(button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		"gold":
			var gold_button := Button.new()
			gold_button.name = "RewardInspectorClaimGold_%s" % reward_index
			gold_button.text = "Claim %s gold" % int(reward.get("amount", 0))
			var selected_gold_reward_index := reward_index
			gold_button.pressed.connect(func(): claim_reward_inspector_gold(selected_gold_reward_index))
			item.add_child(gold_button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		"relic":
			var relic_button := Button.new()
			relic_button.name = "RewardInspectorClaimRelic_%s" % reward_index
			relic_button.text = "Claim %s" % String(reward.get("relic_id", ""))
			var selected_relic_reward_index := reward_index
			relic_button.pressed.connect(func(): claim_reward_inspector_relic(selected_relic_reward_index))
			item.add_child(relic_button)
			item.add_child(_reward_inspector_skip_button(reward_index))
		_:
			item.add_child(_reward_inspector_skip_button(reward_index))

func _reward_inspector_skip_button(reward_index: int) -> Button:
	var button := Button.new()
	button.name = "RewardInspectorSkip_%s" % reward_index
	button.text = "Skip"
	var selected_reward_index := reward_index
	button.pressed.connect(func(): skip_reward_inspector_reward(selected_reward_index))
	return button

func _refresh_reward_inspector_after_resolution(reward_index: int) -> void:
	if reward_inspector_run_summary_label != null:
		reward_inspector_run_summary_label.text = reward_inspector_run_summary_text()
	if reward_inspector_reward_list == null \
		or reward_index < 0 \
		or reward_index >= reward_inspector_reward_list.get_child_count():
		return
	var item := reward_inspector_reward_list.get_child(reward_index)
	var label := item.get_node_or_null("RewardInspectorRewardLabel_%s" % reward_index) as Label
	if label != null:
		label.text = reward_inspector_reward_text(reward_index)
	for child in item.get_children():
		if child is Button:
			(child as Button).disabled = true

func _refresh_selected_card() -> void:
	var cards := filtered_cards()
	if cards.is_empty():
		selected_card_id = ""
	elif selected_card_id.is_empty() or not _card_id_in_cards(selected_card_id, cards):
		selected_card_id = cards[0].id

func _card_matches_filters(card: CardDef) -> bool:
	if card == null:
		return false
	if character_filter != FILTER_ALL and card.character_id != character_filter:
		return false
	if rarity_filter != FILTER_ALL and card.rarity != rarity_filter:
		return false
	if card_type_filter != FILTER_ALL and card.card_type != card_type_filter:
		return false
	return true

func _card_less(a: CardDef, b: CardDef) -> bool:
	if a.character_id != b.character_id:
		return a.character_id < b.character_id
	var rarity_a := int(RARITY_ORDER.get(a.rarity, 99))
	var rarity_b := int(RARITY_ORDER.get(b.rarity, 99))
	if rarity_a != rarity_b:
		return rarity_a < rarity_b
	var type_a := int(TYPE_ORDER.get(a.card_type, 99))
	var type_b := int(TYPE_ORDER.get(b.card_type, 99))
	if type_a != type_b:
		return type_a < type_b
	return a.id < b.id

func _enemy_less(a: EnemyDef, b: EnemyDef) -> bool:
	var tier_a := int(ENEMY_TIER_ORDER.get(a.tier, 99))
	var tier_b := int(ENEMY_TIER_ORDER.get(b.tier, 99))
	if tier_a != tier_b:
		return tier_a < tier_b
	return a.id < b.id

func _card_id_in_cards(card_id: String, cards: Array[CardDef]) -> bool:
	for card in cards:
		if card.id == card_id:
			return true
	return false

func _effect_text(effect: EffectDef) -> String:
	if effect == null:
		return "effect: null"
	var text := "effect: %s target=%s amount=%s" % [effect.effect_type, effect.target, effect.amount]
	if not effect.status_id.is_empty():
		text += " status=%s" % effect.status_id
	return text

func _cue_text(cue: CardPresentationCueDef) -> String:
	if cue == null:
		return "cue: null"
	var text := "cue: %s target_mode=%s amount=%s intensity=%s" % [
		cue.event_type,
		cue.target_mode,
		cue.amount,
		cue.intensity,
	]
	if not cue.cue_id.is_empty():
		text += " cue_id=%s" % cue.cue_id
	if not cue.tags.is_empty():
		text += " tags=%s" % _join_string_array(cue.tags)
	return text

func _join_string_array(values: Array[String]) -> String:
	if values.is_empty():
		return "none"
	return ", ".join(values)

func _enemy_sandbox_character_ids() -> Array[String]:
	return _dev_tools_character_ids(DEFAULT_SANDBOX_CHARACTER)

func _ensure_enemy_sandbox_defaults() -> void:
	if catalog.get_character(selected_sandbox_character_id) == null:
		var character_ids := _enemy_sandbox_character_ids()
		selected_sandbox_character_id = character_ids[0] if not character_ids.is_empty() else ""
	selected_sandbox_enemy_ids = _normalized_enemy_ids(selected_sandbox_enemy_ids)

func _normalized_enemy_ids(enemy_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_ids:
		if result.size() >= 3:
			break
		if result.has(enemy_id) or catalog.get_enemy(enemy_id) == null:
			continue
		result.append(enemy_id)
	if result.is_empty():
		if catalog.get_enemy(DEFAULT_SANDBOX_ENEMY) != null:
			result.append(DEFAULT_SANDBOX_ENEMY)
		else:
			var available_enemy_ids := enemy_sandbox_enemy_ids()
			if not available_enemy_ids.is_empty():
				result.append(available_enemy_ids[0])
	return result

func _ensure_event_tester_defaults() -> void:
	if catalog.get_event(selected_event_tester_event_id) == null:
		var event_ids := event_tester_event_ids()
		selected_event_tester_event_id = event_ids[0] if not event_ids.is_empty() else ""
	if catalog.get_character(selected_event_tester_character_id) == null:
		var character_ids := _dev_tools_character_ids(DEFAULT_EVENT_TESTER_CHARACTER)
		selected_event_tester_character_id = character_ids[0] if not character_ids.is_empty() else ""

func _create_event_tester_run() -> RunState:
	var run := RunState.new()
	var character := catalog.get_character(selected_event_tester_character_id)
	run.seed_value = DEFAULT_EVENT_TESTER_SEED
	run.character_id = selected_event_tester_character_id
	run.gold = DEFAULT_EVENT_TESTER_GOLD
	run.current_node_id = EVENT_TESTER_NODE_ID
	run.map_nodes = [MapNodeState.new(EVENT_TESTER_NODE_ID, 0, "event")]
	if character != null:
		run.max_hp = character.max_hp
		run.current_hp = character.max_hp
		run.deck_ids = _copy_string_array(character.starting_deck_ids)
	return run

func _ensure_reward_inspector_defaults() -> void:
	if catalog.get_character(selected_reward_inspector_character_id) == null:
		var character_ids := _dev_tools_character_ids(DEFAULT_REWARD_INSPECTOR_CHARACTER)
		selected_reward_inspector_character_id = character_ids[0] if not character_ids.is_empty() else ""
	if not REWARD_INSPECTOR_NODE_TYPES.has(selected_reward_inspector_node_type):
		selected_reward_inspector_node_type = DEFAULT_REWARD_INSPECTOR_NODE_TYPE
	selected_reward_inspector_seed = max(1, selected_reward_inspector_seed)

func _create_reward_inspector_run() -> RunState:
	var run := RunState.new()
	var character := catalog.get_character(selected_reward_inspector_character_id)
	run.seed_value = selected_reward_inspector_seed
	run.character_id = selected_reward_inspector_character_id
	run.gold = 0
	run.current_node_id = REWARD_INSPECTOR_NODE_ID
	var node := MapNodeState.new(REWARD_INSPECTOR_NODE_ID, 0, selected_reward_inspector_node_type)
	node.unlocked = true
	run.map_nodes = [node]
	if character != null:
		run.max_hp = character.max_hp
		run.current_hp = character.max_hp
		run.deck_ids = _copy_string_array(character.starting_deck_ids)
	return run

func _is_reward_inspector_reward_available(reward_index: int) -> bool:
	return reward_inspector_run != null \
		and reward_index >= 0 \
		and reward_index < reward_inspector_reward_states.size() \
		and reward_inspector_reward_states[reward_index] == REWARD_STATE_AVAILABLE

func _resolved_reward_inspector_count() -> int:
	var result := 0
	for state in reward_inspector_reward_states:
		if state != REWARD_STATE_AVAILABLE:
			result += 1
	return result

func _dev_tools_character_ids(preferred_id: String) -> Array[String]:
	var result: Array[String] = []
	for character_id in catalog.characters_by_id.keys():
		result.append(String(character_id))
	result.sort()
	if result.has(preferred_id):
		result.erase(preferred_id)
		result.push_front(preferred_id)
	return result

func _refresh_event_tester_if_ready() -> void:
	if event_tester_option_list != null and event_tester_run_summary_label != null:
		_refresh_event_tester_panel()

func _join_variant_string_array(values: Array) -> String:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return _join_string_array(result)

func _refresh_reward_inspector_panel() -> void:
	if reward_inspector_run == null:
		reset_reward_inspector_run()
	if reward_inspector_run_summary_label != null:
		reward_inspector_run_summary_label.text = reward_inspector_run_summary_text()
	if reward_inspector_reward_list == null:
		return
	_clear_children(reward_inspector_reward_list)
	if reward_inspector_rewards.is_empty():
		var empty := Label.new()
		empty.name = "RewardInspectorNoRewardsLabel"
		empty.text = "No rewards"
		reward_inspector_reward_list.add_child(empty)
		return
	for i in range(reward_inspector_rewards.size()):
		_add_reward_inspector_reward_row(i)

func _refresh_reward_inspector_if_ready() -> void:
	if reward_inspector_reward_list != null and reward_inspector_run_summary_label != null:
		_refresh_reward_inspector_panel()

func _build_save_inspector_snapshot() -> Dictionary:
	var service: Variant = _save_inspector_save_service()
	var snapshot := {
		"has_service": service != null,
		"has_save": false,
		"status": SAVE_STATUS_MISSING_SERVICE,
		"resume_target": SAVE_RESUME_NONE,
		"reason": "save_service: missing",
		"run": null,
	}
	if service == null:
		return snapshot
	if not service.has_method("has_save") or not service.has_method("load_run"):
		return snapshot
	snapshot["has_save"] = service.has_save()
	if not bool(snapshot["has_save"]):
		snapshot["status"] = SAVE_STATUS_NO_SAVE
		snapshot["reason"] = "save_file: missing"
		return snapshot
	var loaded_run: RunState = service.load_run()
	if loaded_run == null:
		snapshot["status"] = SAVE_STATUS_INVALID
		snapshot["resume_target"] = SAVE_RESUME_INVALID_DELETE_ON_CONTINUE
		snapshot["reason"] = "load_run: invalid"
		return snapshot
	snapshot["run"] = loaded_run
	if loaded_run.failed or loaded_run.completed:
		snapshot["status"] = SAVE_STATUS_TERMINAL
		snapshot["resume_target"] = SAVE_RESUME_TERMINAL_DELETE_ON_CONTINUE
		snapshot["reason"] = "run: terminal"
		return snapshot
	var resume_target := _save_inspector_resume_target_for_run(loaded_run)
	snapshot["status"] = SAVE_STATUS_ACTIVE
	snapshot["resume_target"] = resume_target
	snapshot["reason"] = "continue_target: %s" % resume_target
	return snapshot

func _save_inspector_save_service() -> Variant:
	if save_inspector_save_service_override != null:
		return save_inspector_save_service_override
	var app := _get_app()
	if app == null or app.get("game") == null:
		return null
	return app.game.save_service

func _save_inspector_resume_target_for_run(run: RunState) -> String:
	if _save_inspector_reward_state_matches(run):
		return SAVE_RESUME_REWARD
	if _save_inspector_shop_state_matches(run):
		return SAVE_RESUME_SHOP
	return SAVE_RESUME_MAP

func _save_inspector_reward_state_matches(run: RunState) -> bool:
	if run == null or run.current_reward_state.is_empty():
		return false
	if String(run.current_reward_state.get("source", "")) != "event":
		return false
	if String(run.current_reward_state.get("node_id", "")) != run.current_node_id:
		return false
	return _save_inspector_current_node_type(run) == "event"

func _save_inspector_shop_state_matches(run: RunState) -> bool:
	if run == null or run.current_shop_state.is_empty():
		return false
	if String(run.current_shop_state.get("node_id", "")) != run.current_node_id:
		return false
	return _save_inspector_current_node_type(run) == "shop"

func _save_inspector_current_node_type(run: RunState) -> String:
	if run == null:
		return "none"
	for node in run.map_nodes:
		if node.id == run.current_node_id:
			return node.node_type
	return "missing"

func _refresh_save_inspector_if_ready() -> void:
	if save_inspector_status_label != null and save_inspector_resume_target_label != null:
		_refresh_save_inspector_panel()

func _build_save_inspector() -> void:
	var panel := VBoxContainer.new()
	panel.name = "SaveInspectorPanel"
	tool_content.add_child(panel)

	save_inspector_status_label = Label.new()
	save_inspector_status_label.name = "SaveInspectorStatusLabel"
	save_inspector_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(save_inspector_status_label)

	save_inspector_resume_target_label = Label.new()
	save_inspector_resume_target_label.name = "SaveInspectorResumeTargetLabel"
	panel.add_child(save_inspector_resume_target_label)

	save_inspector_run_summary_label = Label.new()
	save_inspector_run_summary_label.name = "SaveInspectorRunSummaryLabel"
	save_inspector_run_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(save_inspector_run_summary_label)

	save_inspector_state_sections = VBoxContainer.new()
	save_inspector_state_sections.name = "SaveInspectorStateSections"
	panel.add_child(save_inspector_state_sections)

	save_inspector_map_section_label = Label.new()
	save_inspector_map_section_label.name = "SaveInspectorMapSectionLabel"
	save_inspector_map_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_map_section_label)

	save_inspector_shop_section_label = Label.new()
	save_inspector_shop_section_label.name = "SaveInspectorShopSectionLabel"
	save_inspector_shop_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_shop_section_label)

	save_inspector_reward_section_label = Label.new()
	save_inspector_reward_section_label.name = "SaveInspectorRewardSectionLabel"
	save_inspector_reward_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_inspector_state_sections.add_child(save_inspector_reward_section_label)

	var action_bar := HBoxContainer.new()
	action_bar.name = "SaveInspectorActionBar"
	panel.add_child(action_bar)

	var reload := Button.new()
	reload.name = "SaveInspectorReloadButton"
	reload.text = "Reload"
	reload.pressed.connect(_on_save_inspector_reload_pressed)
	action_bar.add_child(reload)

	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorDeleteButton", "Delete"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorExportButton", "Export"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorCopyJsonButton", "Copy JSON"))
	action_bar.add_child(_disabled_save_inspector_action("SaveInspectorRepairButton", "Repair"))

	refresh_save_inspector()

func _disabled_save_inspector_action(node_name: String, label: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.disabled = true
	return button

func _on_save_inspector_reload_pressed() -> void:
	refresh_save_inspector()

func _refresh_save_inspector_panel() -> void:
	var snapshot := save_inspector_snapshot()
	if save_inspector_status_label != null:
		save_inspector_status_label.text = save_inspector_status_text()
	if save_inspector_resume_target_label != null:
		save_inspector_resume_target_label.text = "continue_target: %s\nreason: %s" % [
			String(snapshot.get("resume_target", SAVE_RESUME_NONE)),
			String(snapshot.get("reason", "")),
		]
	if save_inspector_run_summary_label != null:
		save_inspector_run_summary_label.text = save_inspector_summary_text()
	if save_inspector_map_section_label != null:
		save_inspector_map_section_label.text = save_inspector_map_text()
	if save_inspector_shop_section_label != null:
		save_inspector_shop_section_label.text = save_inspector_shop_text()
	if save_inspector_reward_section_label != null:
		save_inspector_reward_section_label.text = save_inspector_reward_text()

func _clear_save_inspector_refs() -> void:
	save_inspector_status_label = null
	save_inspector_resume_target_label = null
	save_inspector_run_summary_label = null
	save_inspector_state_sections = null
	save_inspector_map_section_label = null
	save_inspector_shop_section_label = null
	save_inspector_reward_section_label = null

func _bool_text(value: bool) -> String:
	return "true" if value else "false"

func _copy_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(value)
	return result

func _get_app() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("App")

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()
