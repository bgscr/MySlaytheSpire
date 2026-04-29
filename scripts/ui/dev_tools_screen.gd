extends Control

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const SceneRouterScript := preload("res://scripts/app/scene_router.gd")

const TOOL_CARD_BROWSER := "card_browser"
const TOOL_ENEMY_SANDBOX := "enemy_sandbox"
const FILTER_ALL := "all"
const DEFAULT_SANDBOX_CHARACTER := "sword"
const DEFAULT_SANDBOX_ENEMY := "training_puppet"
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

func _ready() -> void:
	if catalog.cards_by_id.is_empty():
		catalog.load_default()
	_ensure_enemy_sandbox_defaults()
	_build_layout()
	_show_tool(TOOL_CARD_BROWSER)

func load_default_catalog() -> void:
	catalog.load_default()
	_refresh_selected_card()
	_ensure_enemy_sandbox_defaults()

func tool_ids() -> Array[String]:
	return [
		"card_browser",
		"enemy_sandbox",
		"event_tester",
		"reward_inspector",
		"save_inspector",
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
	_clear_children(tool_content)
	if tool_id == TOOL_CARD_BROWSER:
		_build_card_browser()
	elif tool_id == TOOL_ENEMY_SANDBOX:
		_build_enemy_sandbox()
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
	var result: Array[String] = []
	for character_id in catalog.characters_by_id.keys():
		result.append(String(character_id))
	result.sort()
	if result.has(DEFAULT_SANDBOX_CHARACTER):
		result.erase(DEFAULT_SANDBOX_CHARACTER)
		result.push_front(DEFAULT_SANDBOX_CHARACTER)
	return result

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

func _copy_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(value)
	return result

func _get_app() -> Node:
	return get_tree().root.get_node_or_null("App")

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()
