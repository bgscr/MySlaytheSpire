class_name CombatVisualResolver
extends RefCounted

const FALLBACK_BACKGROUND_ID := "default_combat"
const FALLBACK_THUMBNAIL_PATH := "res://assets/presentation/card_thumbnails/fallback_card.png"
const FALLBACK_ENEMY_PORTRAIT_PATH := "res://assets/presentation/enemy_portraits/fallback_enemy.png"

func resolve_theme(character_id: String, catalog: Object) -> Dictionary:
	var theme = null
	if catalog != null and catalog.has_method("get_visual_theme"):
		theme = catalog.get_visual_theme(character_id)
	if theme == null:
		return {
			"theme_id": character_id,
			"character_id": character_id,
			"default_background_id": FALLBACK_BACKGROUND_ID,
			"frame_style": "neutral",
			"accent_color": Color.WHITE,
			"background_accent_color": Color.WHITE,
			"is_known": false,
		}
	return {
		"theme_id": theme.id,
		"character_id": theme.character_id,
		"default_background_id": theme.default_background_id,
		"frame_style": theme.card_frame_style,
		"accent_color": theme.card_accent_color,
		"background_accent_color": theme.background_accent_color,
		"is_known": true,
	}

func resolve_card_visual(card_id: String, catalog: Object, theme: Dictionary = {}) -> Dictionary:
	var visual = null
	if catalog != null and catalog.has_method("get_card_visual"):
		visual = catalog.get_card_visual(card_id)
	if visual == null:
		return {
			"card_id": card_id,
			"thumbnail_path": FALLBACK_THUMBNAIL_PATH,
			"frame_style": String(theme.get("frame_style", "neutral")),
			"accent_color": theme.get("accent_color", Color.WHITE),
			"element_tag": "fallback",
			"thumbnail_alt_label": "Fallback card thumbnail",
			"is_known": false,
		}
	var frame_style: String = visual.frame_style
	if frame_style.is_empty():
		frame_style = String(theme.get("frame_style", "neutral"))
	var accent_color: Color = visual.accent_color
	if accent_color == Color.WHITE and theme.has("accent_color"):
		accent_color = theme.get("accent_color", Color.WHITE)
	return {
		"card_id": visual.card_id,
		"thumbnail_path": visual.thumbnail_path,
		"frame_style": frame_style,
		"accent_color": accent_color,
		"element_tag": visual.element_tag,
		"thumbnail_alt_label": visual.thumbnail_alt_label,
		"is_known": true,
	}

func resolve_enemy_visual(enemy_id: String, catalog: Object) -> Dictionary:
	var visual = null
	if catalog != null and catalog.has_method("get_enemy_visual"):
		visual = catalog.get_enemy_visual(enemy_id)
	if visual == null:
		return {
			"enemy_id": enemy_id,
			"portrait_path": FALLBACK_ENEMY_PORTRAIT_PATH,
			"frame_style": "fallback",
			"accent_color": Color.WHITE,
			"silhouette_tag": "fallback",
			"portrait_alt_label": "Fallback enemy portrait",
			"is_known": false,
		}
	return {
		"enemy_id": visual.enemy_id,
		"portrait_path": visual.portrait_path,
		"frame_style": visual.frame_style,
		"accent_color": visual.accent_color,
		"silhouette_tag": visual.silhouette_tag,
		"portrait_alt_label": visual.portrait_alt_label,
		"is_known": true,
	}

func resolve_combat_background(character_id: String, catalog: Object) -> Dictionary:
	var theme := resolve_theme(character_id, catalog)
	var background_id := String(theme.get("default_background_id", FALLBACK_BACKGROUND_ID))
	var background = _background_for(catalog, background_id)
	var is_known := bool(theme.get("is_known", false)) and background != null
	if background == null:
		background = _background_for(catalog, FALLBACK_BACKGROUND_ID)
		background_id = FALLBACK_BACKGROUND_ID
	if background == null:
		return {
			"background_id": FALLBACK_BACKGROUND_ID,
			"texture_path": "",
			"environment_tag": "fallback",
			"accent_color": theme.get("background_accent_color", Color.WHITE),
			"dim_opacity": 0.35,
			"is_known": false,
		}
	return {
		"background_id": background_id,
		"texture_path": background.texture_path,
		"environment_tag": background.environment_tag,
		"accent_color": background.accent_color,
		"dim_opacity": background.dim_opacity,
		"is_known": is_known,
	}

func _background_for(catalog: Object, background_id: String):
	if catalog == null or not catalog.has_method("get_combat_background"):
		return null
	return catalog.get_combat_background(background_id)
