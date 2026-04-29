extends Control

const CardDef := preload("res://scripts/data/card_def.gd")
const CardPresentationCueDef := preload("res://scripts/data/card_presentation_cue_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")

const TOOL_CARD_BROWSER := "card_browser"
const FILTER_ALL := "all"
const RARITY_ORDER := {"common": 0, "uncommon": 1, "rare": 2}
const TYPE_ORDER := {"attack": 0, "skill": 1, "power": 2}
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
var tool_content: VBoxContainer
var card_list: VBoxContainer
var card_detail_label: Label
var character_filter_button: OptionButton
var rarity_filter_button: OptionButton
var type_filter_button: OptionButton

func _ready() -> void:
	if catalog.cards_by_id.is_empty():
		catalog.load_default()
	_build_layout()
	_show_tool(TOOL_CARD_BROWSER)

func load_default_catalog_for_tests() -> void:
	catalog.load_default()
	_refresh_selected_card()

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

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()
