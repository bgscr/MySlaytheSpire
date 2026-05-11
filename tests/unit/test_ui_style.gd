extends RefCounted

const UiStyle := preload("res://scripts/ui/ui_style.gd")

func test_style_applies_panel_and_button_metadata() -> bool:
	var panel := PanelContainer.new()
	var button := Button.new()
	UiStyle.apply_panel(panel)
	UiStyle.apply_primary_button(button)
	var passed: bool = panel.get_meta("ui_style") == "ink_jade_panel" \
		and button.get_meta("ui_style") == "ink_jade_primary_button" \
		and button.custom_minimum_size.x >= 120.0
	panel.free()
	button.free()
	assert(passed)
	return passed

func test_badge_has_stable_size_and_text() -> bool:
	var badge := UiStyle.badge("node_type.combat")
	var passed: bool = badge.text == tr("node_type.combat") \
		and badge.custom_minimum_size.x >= 72.0
	badge.free()
	assert(passed)
	return passed
