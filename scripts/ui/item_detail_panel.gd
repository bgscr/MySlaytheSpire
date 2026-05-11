class_name ItemDetailPanel
extends PanelContainer

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const ItemVisualPresenter := preload("res://scripts/ui/item_visual_presenter.gd")

var title_label: Label
var image_rect: TextureRect
var body_label: Label

func _init() -> void:
	name = "ItemDetailPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 220)
	_build_layout()

func show_card(card_id: String, catalog: Object, theme: Dictionary = {}) -> void:
	var card = catalog.get_card(card_id) if catalog != null and catalog.has_method("get_card") else null
	var visual := CombatVisualResolver.new().resolve_card_visual(card_id, catalog, theme)
	_show_common("card", card_id, _card_title(card_id, card), String(visual.get("thumbnail_path", "")), _card_body(card_id, card))

func show_relic(relic_id: String, catalog: Object) -> void:
	var relic = catalog.get_relic(relic_id) if catalog != null and catalog.has_method("get_relic") else null
	var visual := ItemVisualPresenter._resolve_relic_visual(relic_id, catalog)
	_show_common("relic", relic_id, _relic_title(relic_id, relic), String(visual.get("icon_path", "")), _relic_body(relic_id, relic))

func hide_detail() -> void:
	visible = false

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.name = "ItemDetailRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	title_label = Label.new()
	title_label.name = "ItemDetailTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_label)

	image_rect = TextureRect.new()
	image_rect.name = "ItemDetailImage"
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_rect.custom_minimum_size = Vector2(160, 96)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(image_rect)

	body_label = Label.new()
	body_label.name = "ItemDetailBody"
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(body_label)

func _show_common(kind: String, item_id: String, title: String, image_path: String, body: String) -> void:
	set_meta("item_kind", kind)
	set_meta("item_id", item_id)
	title_label.text = title
	image_rect.texture = load(image_path) as Texture2D if not image_path.is_empty() else null
	body_label.text = body
	visible = true

func _card_title(card_id: String, card) -> String:
	if card == null:
		return "%s (?)" % card_id
	return card.id

func _relic_title(relic_id: String, relic) -> String:
	if relic == null:
		return "%s (?)" % relic_id
	return relic.id

func _card_body(card_id: String, card) -> String:
	if card == null:
		return "Unknown card\nId: %s" % card_id
	return "Type: %s\nRarity: %s\nCost: %s\nCharacter: %s\nEffects:\n%s" % [
		card.card_type,
		card.rarity,
		card.cost,
		card.character_id,
		_effect_lines(card.effects),
	]

func _relic_body(relic_id: String, relic) -> String:
	if relic == null:
		return "Unknown relic\nId: %s" % relic_id
	return "Tier: %s\nTrigger: %s\nEffects:\n%s" % [
		relic.tier,
		relic.trigger_event,
		_effect_lines(relic.effects),
	]

func _effect_lines(effects: Array) -> String:
	if effects.is_empty():
		return "- none"
	var lines: Array[String] = []
	for effect in effects:
		if effect == null:
			lines.append("- empty")
			continue
		var parts: Array[String] = ["- %s" % effect.effect_type]
		if int(effect.amount) != 0:
			parts.append("amount=%s" % effect.amount)
		if not String(effect.status_id).is_empty():
			parts.append("status=%s" % effect.status_id)
		if not String(effect.target).is_empty():
			parts.append("target=%s" % effect.target)
		lines.append(" ".join(parts))
	return "\n".join(lines)
