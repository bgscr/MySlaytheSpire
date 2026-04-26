extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")

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

func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids
