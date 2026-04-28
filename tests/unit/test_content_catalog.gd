extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CardDef := preload("res://scripts/data/card_def.gd")
const CharacterDef := preload("res://scripts/data/character_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EventDef := preload("res://scripts/data/event_def.gd")

func test_default_catalog_loads_existing_resources() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var passed := catalog.get_card("sword.strike") != null \
		and catalog.get_card("alchemy.toxic_pill") != null \
		and catalog.get_character("sword") != null \
		and catalog.get_character("alchemy") != null \
		and catalog.get_enemy("training_puppet") != null \
		and catalog.get_enemy("boss_heart_demon") != null \
		and catalog.get_relic("jade_talisman") != null
	assert(passed)
	return passed

func test_catalog_queries_cards_by_character_and_rarity() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_cards := catalog.get_cards_for_character("sword")
	var alchemy_cards := catalog.get_cards_for_character("alchemy")
	var sword_common := catalog.get_cards_by_rarity("sword", "common")
	var passed := _ids(sword_cards).has("sword.strike") \
		and not _ids(sword_cards).has("alchemy.toxic_pill") \
		and _ids(alchemy_cards).has("alchemy.toxic_pill") \
		and _ids(sword_common).has("sword.strike")
	assert(passed)
	return passed

func test_catalog_queries_enemies_and_relics_by_tier() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_enemies := catalog.get_enemies_by_tier("normal")
	var boss_enemies := catalog.get_enemies_by_tier("boss")
	var common_relics := catalog.get_relics_by_tier("common")
	var passed := _ids(normal_enemies).has("training_puppet") \
		and _ids(boss_enemies).has("boss_heart_demon") \
		and _ids(common_relics).has("jade_talisman")
	assert(passed)
	return passed

func test_catalog_rejects_wrong_resource_type_for_card_paths() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_from_paths(
		["res://resources/characters/sword_cultivator.tres"],
		[],
		[],
		[]
	)
	var passed := catalog.cards_by_id.is_empty() \
		and catalog.get_card("sword") == null \
		and catalog.get_character("sword") == null \
		and catalog.load_errors.size() == 1 \
		and catalog.load_errors[0].contains("expected CardDef")
	assert(passed)
	return passed

func test_enemy_tier_query_uses_enemy_tier_metadata() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var boss := catalog.get_enemy("boss_heart_demon")
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed := boss != null \
		and boss.tier == "boss" \
		and boss.reward_tier == "boss" \
		and boss_ids.has("boss_heart_demon")
	assert(passed)
	return passed

func test_enemy_tier_query_ignores_reward_tier_metadata() -> bool:
	var catalog := ContentCatalog.new()
	var enemy := EnemyDef.new()
	enemy.id = "test.reward_boss_normal_tier"
	enemy.tier = "normal"
	enemy.reward_tier = "boss"
	catalog.enemies_by_id[enemy.id] = enemy
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var passed := normal_ids.has(enemy.id) and not boss_ids.has(enemy.id)
	assert(passed)
	return passed

func test_default_catalog_validation_passes() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var errors: Array[String] = catalog.validate()
	var passed: bool = errors.is_empty()
	if not passed:
		push_error("Catalog validation errors: %s" % str(errors))
	assert(passed)
	return passed

func test_validation_reports_unreadable_locale_file_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	catalog.locale_path = "res://localization/missing_zh_CN.po"
	var errors: Array[String] = catalog.validate()
	var passed: bool = errors.size() == 1 \
		and errors[0].contains("could not open localization file") \
		and errors[0].contains("missing_zh_CN.po")
	assert(passed)
	return passed

func test_default_catalog_loads_dual_starter_card_pool_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_ids := _ids(catalog.get_cards_for_character("sword"))
	var alchemy_ids := _ids(catalog.get_cards_for_character("alchemy"))
	var passed: bool = catalog.cards_by_id.size() == 40 \
		and sword_ids.size() == 20 \
		and alchemy_ids.size() == 20
	assert(passed)
	return passed

func test_dual_starter_card_pools_are_character_isolated() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var sword_ids := _ids(catalog.get_cards_for_character("sword"))
	var alchemy_ids := _ids(catalog.get_cards_for_character("alchemy"))
	var expected_sword: Array[String] = [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.break_stance",
		"sword.cloud_step",
		"sword.focused_slash",
		"sword.sword_resonance",
		"sword.horizon_arc",
		"sword.iron_wind_cut",
		"sword.rising_arc",
		"sword.guardian_stance",
		"sword.meridian_flash",
		"sword.heart_piercer",
		"sword.unbroken_focus",
		"sword.wind_splitting_step",
		"sword.clear_mind_guard",
		"sword.thread_the_needle",
		"sword.echoing_sword_heart",
		"sword.heaven_cutting_arc",
	]
	var expected_alchemy: Array[String] = [
		"alchemy.toxic_pill",
		"alchemy.healing_draught",
		"alchemy.poison_mist",
		"alchemy.inner_fire_pill",
		"alchemy.cauldron_burst",
		"alchemy.calming_powder",
		"alchemy.toxin_needle",
		"alchemy.spirit_distill",
		"alchemy.cinnabar_seal",
		"alchemy.bitter_extract",
		"alchemy.smoke_screen",
		"alchemy.quick_simmer",
		"alchemy.white_jade_paste",
		"alchemy.mercury_bloom",
		"alchemy.ninefold_refine",
		"alchemy.coiling_miasma",
		"alchemy.needle_rain",
		"alchemy.purifying_brew",
		"alchemy.cauldron_overflow",
		"alchemy.golden_core_detox",
	]
	var passed := _contains_all(sword_ids, expected_sword) \
		and _contains_all(alchemy_ids, expected_alchemy) \
		and not sword_ids.has("alchemy.toxic_pill") \
		and not alchemy_ids.has("sword.strike")
	assert(passed)
	return passed

func test_wave_c_catalog_loads_expanded_enemy_relic_and_event_counts() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var normal_ids := _ids(catalog.get_enemies_by_tier("normal"))
	var elite_ids := _ids(catalog.get_enemies_by_tier("elite"))
	var boss_ids := _ids(catalog.get_enemies_by_tier("boss"))
	var common_relic_ids := _ids(catalog.get_relics_by_tier("common"))
	var uncommon_relic_ids := _ids(catalog.get_relics_by_tier("uncommon"))
	var rare_relic_ids := _ids(catalog.get_relics_by_tier("rare"))
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.enemies_by_id.size() == 16 \
		and catalog.relics_by_id.size() == 20 \
		and catalog.events_by_id.size() == 12 \
		and normal_ids.size() == 7 \
		and elite_ids.size() == 5 \
		and boss_ids.size() == 4 \
		and common_relic_ids.size() == 9 \
		and uncommon_relic_ids.size() == 7 \
		and rare_relic_ids.size() == 4 \
		and normal_ids.has("plague_jade_imp") \
		and normal_ids.has("iron_oath_duelist") \
		and elite_ids.has("miasma_cauldron_elder") \
		and boss_ids.has("boss_sword_ghost") \
		and common_relic_ids.has("paper_lantern_charm") \
		and common_relic_ids.has("mothwing_sachet") \
		and common_relic_ids.has("rusted_meridian_ring") \
		and uncommon_relic_ids.has("silk_thread_prayer") \
		and uncommon_relic_ids.has("black_pill_vial") \
		and uncommon_relic_ids.has("cloudstep_sandals") \
		and rare_relic_ids.has("immortal_peach_core") \
		and rare_relic_ids.has("void_tiger_eye") \
		and event_ids.has("forgotten_armory") \
		and event_ids.has("jade_debt_collector") \
		and event_ids.has("moonlit_ferry") \
		and event_ids.has("spirit_compact") \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master")
	assert(passed)
	return passed

func test_default_catalog_loads_event_pool() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var event_ids := _ids(catalog.get_events())
	var passed: bool = catalog.events_by_id.size() == 12 \
		and event_ids.has("wandering_physician") \
		and event_ids.has("spirit_toll") \
		and event_ids.has("quiet_shrine") \
		and event_ids.has("sealed_sword_tomb") \
		and event_ids.has("alchemist_market") \
		and event_ids.has("spirit_beast_tracks") \
		and event_ids.has("forgotten_armory") \
		and event_ids.has("jade_debt_collector") \
		and event_ids.has("moonlit_ferry") \
		and event_ids.has("spirit_compact") \
		and event_ids.has("tea_house_rumor") \
		and event_ids.has("withered_master") \
		and catalog.get_event("withered_master") != null
	assert(passed)
	return passed

func test_catalog_rejects_wrong_resource_type_for_event_paths() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_from_paths([], [], [], [], ["res://resources/relics/jade_talisman.tres"])
	var passed := catalog.events_by_id.is_empty() \
		and catalog.load_errors.size() == 1 \
		and catalog.load_errors[0].contains("expected EventDef")
	assert(passed)
	return passed

func test_validation_reports_event_without_options() -> bool:
	var catalog := ContentCatalog.new()
	var event := EventDef.new()
	event.id = "empty_event"
	event.title_key = "event.empty.title"
	event.body_key = "event.empty.body"
	catalog.events_by_id[event.id] = event
	var errors := catalog.validate()
	var passed := _any_contains(errors, "empty_event has no options")
	assert(passed)
	return passed

func test_validation_reports_event_reward_references_missing_catalog_ids() -> bool:
	var catalog := ContentCatalog.new()
	var event := EventDef.new()
	event.id = "bad_rewards"
	event.title_key = "event.bad_rewards.title"
	event.body_key = "event.bad_rewards.body"
	var option := preload("res://scripts/data/event_option_def.gd").new()
	option.id = "bad"
	option.label_key = "event.bad_rewards.option.bad"
	option.grant_card_ids = ["missing.card"]
	option.grant_relic_ids = ["missing_relic"]
	option.remove_card_id = "missing.remove_card"
	event.options = [option]
	catalog.events_by_id[event.id] = event
	var errors := catalog.validate()
	var passed := _any_contains(errors, "missing card missing.card") \
		and _any_contains(errors, "missing relic missing_relic") \
		and _any_contains(errors, "missing remove card missing.remove_card")
	assert(passed)
	return passed

func test_loaded_character_card_pool_ids_exclude_unlisted_same_character_cards() -> bool:
	var catalog := ContentCatalog.new()
	var character := CharacterDef.new()
	character.id = "sword"
	character.card_pool_ids = ["sword.in_pool"]
	catalog.characters_by_id[character.id] = character

	var in_pool := CardDef.new()
	in_pool.id = "sword.in_pool"
	in_pool.character_id = "sword"
	catalog.cards_by_id[in_pool.id] = in_pool

	var excluded := CardDef.new()
	excluded.id = "sword.excluded"
	excluded.character_id = "sword"
	catalog.cards_by_id[excluded.id] = excluded

	var ids := _ids(catalog.get_cards_for_character("sword"))
	var passed: bool = ids.size() == 1 \
		and ids.has("sword.in_pool") \
		and not ids.has("sword.excluded")
	assert(passed)
	return passed

func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids

func _contains_all(values: Array[String], expected: Array[String]) -> bool:
	for value in expected:
		if not values.has(value):
			return false
	return true

func _any_contains(values: Array[String], text: String) -> bool:
	for value in values:
		if value.contains(text):
			return true
	return false
