class_name UiStyle
extends RefCounted

const PANEL_COLOR := Color(0.08, 0.13, 0.11, 0.86)
const PANEL_BORDER := Color(0.48, 0.74, 0.62, 1.0)
const BUTTON_COLOR := Color(0.13, 0.28, 0.22, 1.0)
const BUTTON_HOVER := Color(0.18, 0.38, 0.30, 1.0)
const BUTTON_DISABLED := Color(0.12, 0.14, 0.13, 0.72)
const TEXT_COLOR := Color(0.92, 0.88, 0.76, 1.0)
const GOLD := Color(0.86, 0.70, 0.36, 1.0)

static func apply_panel(panel: Control) -> void:
	panel.set_meta("ui_style", "ink_jade_panel")
	panel.add_theme_stylebox_override("panel", _stylebox(PANEL_COLOR, PANEL_BORDER, 2, 8))

static func apply_primary_button(button: Button) -> void:
	button.set_meta("ui_style", "ink_jade_primary_button")
	button.custom_minimum_size = Vector2(120, 36)
	button.add_theme_stylebox_override("normal", _stylebox(BUTTON_COLOR, PANEL_BORDER, 1, 6))
	button.add_theme_stylebox_override("hover", _stylebox(BUTTON_HOVER, GOLD, 1, 6))
	button.add_theme_stylebox_override("disabled", _stylebox(BUTTON_DISABLED, Color(0.24, 0.30, 0.27, 1), 1, 6))
	button.add_theme_color_override("font_color", TEXT_COLOR)

static func apply_secondary_button(button: Button) -> void:
	apply_primary_button(button)
	button.set_meta("ui_style", "ink_jade_secondary_button")
	button.custom_minimum_size = Vector2(96, 32)

static func apply_title(label: Label) -> void:
	label.set_meta("ui_style", "ink_jade_title")
	label.add_theme_color_override("font_color", GOLD)

static func apply_body_label(label: Label) -> void:
	label.set_meta("ui_style", "ink_jade_body")
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func badge(text_key: String) -> Label:
	var label := Label.new()
	label.name = "Badge"
	label.text = _translate(text_key)
	label.custom_minimum_size = Vector2(72, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.set_meta("ui_style", "ink_jade_badge")
	return label

static func _stylebox(color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

static func _translate(key: String) -> String:
	return TranslationServer.translate(key)
