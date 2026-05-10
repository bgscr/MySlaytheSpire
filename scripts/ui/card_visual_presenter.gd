class_name CardVisualPresenter
extends RefCounted

const ItemVisualPresenter := preload("res://scripts/ui/item_visual_presenter.gd")

static func add_card_preview(
	parent: Control,
	prefix: String,
	suffix: String,
	card_id: String,
	catalog: Object,
	theme: Dictionary = {}
) -> Control:
	return ItemVisualPresenter.add_card_preview(parent, prefix.trim_suffix("Card"), suffix, card_id, catalog, theme)
