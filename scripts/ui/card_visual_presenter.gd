class_name CardVisualPresenter
extends RefCounted

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")

static func add_card_preview(
	parent: Control,
	prefix: String,
	suffix: String,
	card_id: String,
	catalog: Object,
	theme: Dictionary = {}
) -> Control:
	var resolver := CombatVisualResolver.new()
	var visual := resolver.resolve_card_visual(card_id, catalog, theme)
	var root := VBoxContainer.new()
	root.name = "%sVisual_%s" % [prefix, suffix]
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(132, 86)
	parent.add_child(root)

	var frame := ColorRect.new()
	frame.name = "%sFrame_%s" % [prefix, suffix]
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(120, 5)
	frame.color = visual.get("accent_color", Color.WHITE)
	frame.set_meta("frame_style", String(visual.get("frame_style", "")))
	root.add_child(frame)

	var thumbnail := TextureRect.new()
	thumbnail.name = "%sThumbnail_%s" % [prefix, suffix]
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.custom_minimum_size = Vector2(120, 52)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := String(visual.get("thumbnail_path", ""))
	thumbnail.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	thumbnail.set_meta("card_id", String(visual.get("card_id", card_id)))
	thumbnail.set_meta("element_tag", String(visual.get("element_tag", "")))
	thumbnail.set_meta("is_known", bool(visual.get("is_known", false)))
	root.add_child(thumbnail)

	var label := Label.new()
	label.name = "%sText_%s" % [prefix, suffix]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _card_text(card_id, catalog)
	root.add_child(label)

	return root

static func _card_text(card_id: String, catalog: Object) -> String:
	var card = null
	if catalog != null and catalog.has_method("get_card"):
		card = catalog.get_card(card_id)
	if card == null:
		return "%s (?)" % card_id
	return "%s [%s] (%s)" % [card.id, card.card_type, card.cost]
