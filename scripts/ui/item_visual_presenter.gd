class_name ItemVisualPresenter
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
	root.name = "%sCardVisual_%s" % [prefix, suffix]
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(132, 86)
	root.set_meta("item_kind", "card")
	root.set_meta("item_id", String(visual.get("card_id", card_id)))
	root.set_meta("is_known", bool(visual.get("is_known", false)))
	parent.add_child(root)

	var frame := ColorRect.new()
	frame.name = "%sCardFrame_%s" % [prefix, suffix]
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(120, 5)
	frame.color = visual.get("accent_color", Color.WHITE)
	frame.set_meta("frame_style", String(visual.get("frame_style", "")))
	root.add_child(frame)

	var thumbnail := TextureRect.new()
	thumbnail.name = "%sCardThumbnail_%s" % [prefix, suffix]
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
	label.name = "%sCardText_%s" % [prefix, suffix]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _card_text(card_id, catalog)
	root.add_child(label)

	return root

static func add_relic_preview(
	parent: Control,
	prefix: String,
	suffix: String,
	relic_id: String,
	catalog: Object
) -> Control:
	var visual := _resolve_relic_visual(relic_id, catalog)
	var root := VBoxContainer.new()
	root.name = "%sRelicVisual_%s" % [prefix, suffix]
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(112, 86)
	root.set_meta("item_kind", "relic")
	root.set_meta("item_id", relic_id)
	root.set_meta("is_known", bool(visual.get("is_known", false)))
	parent.add_child(root)

	var frame := ColorRect.new()
	frame.name = "%sRelicFrame_%s" % [prefix, suffix]
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(96, 5)
	frame.color = visual.get("accent_color", Color.WHITE)
	frame.set_meta("frame_style", String(visual.get("frame_style", "")))
	root.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "%sRelicIcon_%s" % [prefix, suffix]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := String(visual.get("icon_path", ""))
	icon.texture = load(icon_path) as Texture2D if not icon_path.is_empty() else null
	icon.set_meta("relic_id", relic_id)
	icon.set_meta("tier_style", String(visual.get("tier_style", "")))
	icon.set_meta("is_known", bool(visual.get("is_known", false)))
	root.add_child(icon)

	var label := Label.new()
	label.name = "%sRelicText_%s" % [prefix, suffix]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _relic_text(relic_id, catalog)
	root.add_child(label)

	return root

static func _resolve_relic_visual(relic_id: String, catalog: Object) -> Dictionary:
	var relic = null
	var visual = null
	var fallback_path := "res://assets/presentation/relic_icons/fallback_relic.png"
	if catalog != null:
		if catalog.has_method("get_relic"):
			relic = catalog.get_relic(relic_id)
		if catalog.has_method("get_relic_visual"):
			visual = catalog.get_relic_visual(relic_id)
		if _object_has_property(catalog, "relic_fallback_icon_path"):
			fallback_path = String(catalog.relic_fallback_icon_path)
	if visual == null:
		return {
			"relic_id": relic_id,
			"icon_path": fallback_path,
			"frame_style": "fallback",
			"accent_color": Color(0.7, 0.7, 0.7, 1.0),
			"tier_style": "fallback",
			"icon_alt_label": "Fallback relic icon",
			"is_known": false,
		}
	return {
		"relic_id": relic_id,
		"icon_path": visual.icon_path,
		"frame_style": visual.frame_style,
		"accent_color": visual.accent_color,
		"tier_style": visual.tier_style,
		"icon_alt_label": visual.icon_alt_label,
		"is_known": relic != null,
	}

static func _card_text(card_id: String, catalog: Object) -> String:
	var card = null
	if catalog != null and catalog.has_method("get_card"):
		card = catalog.get_card(card_id)
	if card == null:
		return "%s (?)" % card_id
	return "%s [%s] (%s)" % [card.id, card.card_type, card.cost]

static func _relic_text(relic_id: String, catalog: Object) -> String:
	var relic = null
	if catalog != null and catalog.has_method("get_relic"):
		relic = catalog.get_relic(relic_id)
	if relic == null:
		return "%s (?)" % relic_id
	return "%s [%s]" % [relic.id, relic.tier]

static func _object_has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false
