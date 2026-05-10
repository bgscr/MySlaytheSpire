extends RefCounted

const CombatVisualResolver := preload("res://scripts/presentation/combat_visual_resolver.gd")
const CardVisualPresenter := preload("res://scripts/ui/card_visual_presenter.gd")
const ItemVisualPresenter := preload("res://scripts/ui/item_visual_presenter.gd")
const ItemDetailPanel := preload("res://scripts/ui/item_detail_panel.gd")
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
		and String(visual.get("thumbnail_path", "")).ends_with("sword_strike.png") \
		and visual.get("frame_style") == "sword" \
		and visual.get("element_tag") == "blade" \
		and visual.get("thumbnail_alt_label") == "Sword strike thumbnail" \
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

func test_card_visual_presenter_creates_known_card_preview() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := CombatVisualResolver.new()
	var theme := resolver.resolve_theme("sword", catalog)
	var parent := VBoxContainer.new()
	var root := CardVisualPresenter.add_card_preview(parent, "RewardCard", "0_0", "sword.strike", catalog, theme)
	var frame := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardFrame_0_0") as ColorRect
	var thumbnail := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardThumbnail_0_0") as TextureRect
	var text := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardText_0_0") as Label
	var passed: bool = root != null \
		and root.name == "RewardCardVisual_0_0" \
		and root.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and frame != null \
		and frame.color.a > 0.0 \
		and frame.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and frame.get_meta("frame_style") == "sword" \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and thumbnail.get_meta("card_id") == "sword.strike" \
		and thumbnail.get_meta("element_tag") == "blade" \
		and thumbnail.get_meta("is_known") == true \
		and text != null \
		and text.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and text.text.contains("sword.strike") \
		and text.text.contains("attack")
	parent.free()
	assert(passed)
	return passed

func test_card_visual_presenter_falls_back_for_missing_card() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	CardVisualPresenter.add_card_preview(parent, "RewardCard", "missing", "missing.card", catalog)
	var thumbnail := parent.get_node_or_null("RewardCardVisual_missing/RewardCardThumbnail_missing") as TextureRect
	var text := parent.get_node_or_null("RewardCardVisual_missing/RewardCardText_missing") as Label
	var passed: bool = thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.get_meta("card_id") == "missing.card" \
		and thumbnail.get_meta("is_known") == false \
		and text != null \
		and text.text == "missing.card (?)"
	parent.free()
	assert(passed)
	return passed

func test_card_visual_presenter_uses_distinct_suffixes_for_duplicate_cards() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	CardVisualPresenter.add_card_preview(parent, "ShopRemoveCard", "0", "sword.strike", catalog)
	CardVisualPresenter.add_card_preview(parent, "ShopRemoveCard", "1", "sword.strike", catalog)
	var first := parent.get_node_or_null("ShopRemoveCardVisual_0/ShopRemoveCardThumbnail_0") as TextureRect
	var second := parent.get_node_or_null("ShopRemoveCardVisual_1/ShopRemoveCardThumbnail_1") as TextureRect
	var passed: bool = first != null \
		and second != null \
		and first != second \
		and first.get_meta("card_id") == "sword.strike" \
		and second.get_meta("card_id") == "sword.strike"
	parent.free()
	assert(passed)
	return passed

func test_item_visual_presenter_creates_known_card_preview() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var theme := CombatVisualResolver.new().resolve_theme("sword", catalog)
	var parent := VBoxContainer.new()
	var root := ItemVisualPresenter.add_card_preview(parent, "Reward", "0_0", "sword.strike", catalog, theme)
	var thumbnail := parent.get_node_or_null("RewardCardVisual_0_0/RewardCardThumbnail_0_0") as TextureRect
	var passed: bool = root != null \
		and root.name == "RewardCardVisual_0_0" \
		and root.get_meta("item_kind") == "card" \
		and root.get_meta("item_id") == "sword.strike" \
		and thumbnail != null \
		and thumbnail.texture != null \
		and thumbnail.mouse_filter == Control.MOUSE_FILTER_IGNORE
	parent.free()
	assert(passed)
	return passed

func test_item_visual_presenter_creates_known_relic_preview() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	var root := ItemVisualPresenter.add_relic_preview(parent, "Reward", "2", "jade_talisman", catalog)
	var icon := parent.get_node_or_null("RewardRelicVisual_2/RewardRelicIcon_2") as TextureRect
	var text := parent.get_node_or_null("RewardRelicVisual_2/RewardRelicText_2") as Label
	var passed: bool = root != null \
		and root.name == "RewardRelicVisual_2" \
		and root.get_meta("item_kind") == "relic" \
		and root.get_meta("item_id") == "jade_talisman" \
		and root.get_meta("is_known") == true \
		and icon != null \
		and icon.texture != null \
		and icon.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and icon.get_meta("relic_id") == "jade_talisman" \
		and text != null \
		and text.text.contains("jade_talisman")
	parent.free()
	assert(passed)
	return passed

func test_item_visual_presenter_falls_back_for_missing_relic() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	ItemVisualPresenter.add_relic_preview(parent, "Reward", "missing", "missing_relic", catalog)
	var icon := parent.get_node_or_null("RewardRelicVisual_missing/RewardRelicIcon_missing") as TextureRect
	var text := parent.get_node_or_null("RewardRelicVisual_missing/RewardRelicText_missing") as Label
	var passed: bool = icon != null \
		and icon.texture != null \
		and icon.get_meta("relic_id") == "missing_relic" \
		and icon.get_meta("is_known") == false \
		and text != null \
		and text.text == "missing_relic (?)"
	parent.free()
	assert(passed)
	return passed

func test_item_visual_presenter_uses_distinct_suffixes_for_duplicate_relics() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var parent := VBoxContainer.new()
	ItemVisualPresenter.add_relic_preview(parent, "ShopOffer", "0", "jade_talisman", catalog)
	ItemVisualPresenter.add_relic_preview(parent, "ShopOffer", "1", "jade_talisman", catalog)
	var first := parent.get_node_or_null("ShopOfferRelicVisual_0/ShopOfferRelicIcon_0") as TextureRect
	var second := parent.get_node_or_null("ShopOfferRelicVisual_1/ShopOfferRelicIcon_1") as TextureRect
	var passed: bool = first != null \
		and second != null \
		and first != second \
		and first.get_meta("relic_id") == "jade_talisman" \
		and second.get_meta("relic_id") == "jade_talisman"
	parent.free()
	assert(passed)
	return passed

func test_item_detail_panel_shows_and_hides_card_details() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var theme := CombatVisualResolver.new().resolve_theme("sword", catalog)
	var panel := ItemDetailPanel.new()
	panel.show_card("sword.strike", catalog, theme)
	var title := panel.get_node_or_null("ItemDetailTitle") as Label
	var image := panel.get_node_or_null("ItemDetailImage") as TextureRect
	var body := panel.get_node_or_null("ItemDetailBody") as Label
	var visible_after_show := panel.visible
	panel.hide_detail()
	var passed: bool = visible_after_show \
		and not panel.visible \
		and panel.get_meta("item_kind") == "card" \
		and panel.get_meta("item_id") == "sword.strike" \
		and title != null \
		and title.text.contains("sword.strike") \
		and image != null \
		and image.texture != null \
		and body != null \
		and body.text.contains("Cost: 1") \
		and body.text.contains("Effects:")
	panel.free()
	assert(passed)
	return passed

func test_item_detail_panel_shows_and_hides_relic_details() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var panel := ItemDetailPanel.new()
	panel.show_relic("jade_talisman", catalog)
	var title := panel.get_node_or_null("ItemDetailTitle") as Label
	var image := panel.get_node_or_null("ItemDetailImage") as TextureRect
	var body := panel.get_node_or_null("ItemDetailBody") as Label
	var visible_after_show := panel.visible
	panel.hide_detail()
	var passed: bool = visible_after_show \
		and not panel.visible \
		and panel.get_meta("item_kind") == "relic" \
		and panel.get_meta("item_id") == "jade_talisman" \
		and title != null \
		and title.text.contains("jade_talisman") \
		and image != null \
		and image.texture != null \
		and body != null \
		and body.text.contains("Tier: common") \
		and body.text.contains("Trigger: combat_started")
	panel.free()
	assert(passed)
	return passed

func test_item_detail_panel_falls_back_for_missing_items() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var panel := ItemDetailPanel.new()
	panel.show_relic("missing_relic", catalog)
	var title := panel.get_node_or_null("ItemDetailTitle") as Label
	var image := panel.get_node_or_null("ItemDetailImage") as TextureRect
	var body := panel.get_node_or_null("ItemDetailBody") as Label
	var passed: bool = panel.visible \
		and panel.get_meta("item_kind") == "relic" \
		and panel.get_meta("item_id") == "missing_relic" \
		and title != null \
		and title.text == "missing_relic (?)" \
		and image != null \
		and image.texture != null \
		and body != null \
		and body.text.contains("Unknown relic")
	panel.free()
	assert(passed)
	return passed
