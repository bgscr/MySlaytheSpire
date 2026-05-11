extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")

func test_formats_card_and_relic_names_in_english() -> bool:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var passed := UiText.card_name(catalog, "sword.strike") == tr("card.sword.strike.name") \
		and UiText.relic_name(catalog, "jade_talisman") == tr("relic.jade_talisman.name")
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed

func test_formats_combat_summary_labels() -> bool:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var player := {"id": "sword", "hp": 60, "max_hp": 72, "block": 5, "energy": 2, "turn": 3}
	var text := UiText.player_summary(player)
	var passed := text.contains("HP 60/72") \
		and text.contains("Block 5") \
		and text.contains("Energy 2") \
		and text.contains("Turn 3")
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed

func test_debug_labels_preserve_ids_as_values() -> bool:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var text := UiText.key_value("character", "sword")
	var passed := text == "Character: sword"
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed
