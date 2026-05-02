extends RefCounted

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")

func test_resolver_resolves_distinct_character_themes() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var sword := resolver.resolve_theme("sword", catalog)
	var alchemy := resolver.resolve_theme("alchemy", catalog)
	var passed: bool = sword.get("character_id") == "sword" \
		and sword.get("default_background_id") == "sword_training_ground" \
		and sword.get("frame_style") == "sword" \
		and sword.get("is_known") == true \
		and alchemy.get("character_id") == "alchemy" \
		and alchemy.get("default_background_id") == "alchemy_mist_grove" \
		and alchemy.get("frame_style") == "alchemy" \
		and alchemy.get("is_known") == true \
		and sword.get("accent_color") != alchemy.get("accent_color")
	assert(passed)
	return passed

func test_resolver_resolves_card_visual_with_theme_fallback() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var theme := resolver.resolve_theme("sword", catalog)
	var visual := resolver.resolve_card_visual("sword.strike", catalog, theme)
	var passed: bool = visual.get("card_id") == "sword.strike" \
		and String(visual.get("thumbnail_path", "")).ends_with("sword_attack.png") \
		and visual.get("frame_style") == "sword" \
		and visual.get("element_tag") == "blade" \
		and visual.get("thumbnail_alt_label") == "Sword attack thumbnail" \
		and visual.get("is_known") == true
	assert(passed)
	return passed

func test_resolver_resolves_enemy_visual() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var visual: Dictionary = resolver.resolve_enemy_visual("training_puppet", catalog)
	var boss_visual: Dictionary = resolver.resolve_enemy_visual("boss_storm_dragon", catalog)
	var passed: bool = visual.get("enemy_id") == "training_puppet" \
		and String(visual.get("portrait_path", "")).ends_with("construct_wood.png") \
		and visual.get("frame_style") == "normal" \
		and visual.get("silhouette_tag") == "construct" \
		and visual.get("portrait_alt_label") == "Training puppet portrait" \
		and visual.get("is_known") == true \
		and boss_visual.get("enemy_id") == "boss_storm_dragon" \
		and boss_visual.get("frame_style") == "boss" \
		and boss_visual.get("is_known") == true
	assert(passed)
	return passed

func test_resolver_falls_back_for_missing_enemy_visual() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var visual: Dictionary = resolver.resolve_enemy_visual("missing_enemy", catalog)
	var no_catalog: Dictionary = resolver.resolve_enemy_visual("training_puppet", null)
	var passed: bool = visual.get("enemy_id") == "missing_enemy" \
		and String(visual.get("portrait_path", "")).ends_with("fallback_enemy.png") \
		and visual.get("frame_style") == "fallback" \
		and visual.get("silhouette_tag") == "fallback" \
		and visual.get("is_known") == false \
		and no_catalog.get("enemy_id") == "training_puppet" \
		and no_catalog.get("is_known") == false
	assert(passed)
	return passed

func test_resolver_resolves_character_background() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var sword_background := resolver.resolve_combat_background("sword", catalog)
	var alchemy_background := resolver.resolve_combat_background("alchemy", catalog)
	var passed: bool = sword_background.get("background_id") == "sword_training_ground" \
		and String(sword_background.get("texture_path", "")).ends_with("sword_training_ground.png") \
		and sword_background.get("is_known") == true \
		and alchemy_background.get("background_id") == "alchemy_mist_grove" \
		and String(alchemy_background.get("texture_path", "")).ends_with("alchemy_mist_grove.png") \
		and alchemy_background.get("is_known") == true
	assert(passed)
	return passed

func test_resolver_falls_back_for_missing_visual_data() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var theme := resolver.resolve_theme("missing", catalog)
	var card_visual := resolver.resolve_card_visual("missing.card", catalog, theme)
	var enemy_visual: Dictionary = resolver.resolve_enemy_visual("missing_enemy", catalog)
	var background := resolver.resolve_combat_background("missing", catalog)
	var passed: bool = theme.get("character_id") == "missing" \
		and theme.get("default_background_id") == "default_combat" \
		and theme.get("is_known") == false \
		and card_visual.get("card_id") == "missing.card" \
		and String(card_visual.get("thumbnail_path", "")).ends_with("fallback_card.png") \
		and card_visual.get("is_known") == false \
		and enemy_visual.get("enemy_id") == "missing_enemy" \
		and String(enemy_visual.get("portrait_path", "")).ends_with("fallback_enemy.png") \
		and enemy_visual.get("is_known") == false \
		and background.get("background_id") == "default_combat" \
		and String(background.get("texture_path", "")).ends_with("default_combat.png")
	assert(passed)
	return passed
