extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")

func test_combat_node_generates_normal_enemy() -> bool:
	var catalog := _catalog()
	var encounter := EncounterGenerator.new().generate(catalog, 12, "node_1", "combat")
	var passed: bool = encounter.size() >= 1 \
		and encounter.size() <= 3 \
		and _all_unique(encounter) \
		and _all_ids_have_tier(catalog, encounter, "normal")
	assert(passed)
	return passed

func test_elite_node_generates_elite_enemy() -> bool:
	var catalog := _catalog()
	var encounter := EncounterGenerator.new().generate(catalog, 12, "node_2", "elite")
	var tier_sequence := _tiers_for_ids(catalog, encounter)
	var passed: bool = encounter.size() >= 1 \
		and encounter.size() <= 3 \
		and tier_sequence[0] == "elite" \
		and tier_sequence.count("elite") >= 1 \
		and tier_sequence.count("elite") <= 2 \
		and tier_sequence.count("normal") <= 2 \
		and _all_tiers_allowed(tier_sequence, ["elite", "normal"]) \
		and _primary_tiers_precede_support_tiers(tier_sequence, "elite") \
		and _all_unique(encounter)
	assert(passed)
	return passed

func test_boss_node_generates_boss_enemy() -> bool:
	var catalog := _catalog()
	var encounter := EncounterGenerator.new().generate(catalog, 12, "boss_0", "boss")
	var tier_sequence := _tiers_for_ids(catalog, encounter)
	var passed: bool = encounter.size() >= 1 \
		and encounter.size() <= 3 \
		and tier_sequence[0] == "boss" \
		and tier_sequence.count("boss") == 1 \
		and _all_support_tiers_allowed(tier_sequence, ["normal", "elite"]) \
		and _all_unique(encounter)
	assert(passed)
	return passed

func test_encounters_are_deterministic_for_same_seed_and_node() -> bool:
	var generator := EncounterGenerator.new()
	var first := generator.generate(_catalog(), 123, "node_3", "combat")
	var second := generator.generate(_catalog(), 123, "node_3", "combat")
	var passed: bool = first == second
	assert(passed)
	return passed

func test_empty_enemy_pool_returns_empty_encounter() -> bool:
	var catalog := _catalog()
	catalog.enemies_by_id.clear()
	var encounter := EncounterGenerator.new().generate(catalog, 12, "node_1", "combat")
	var passed: bool = encounter.is_empty()
	assert(passed)
	return passed

func test_combat_node_generates_one_to_three_normal_enemies() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
		{"id": "normal_c", "tier": "normal"},
	])
	var encounter := EncounterGenerator.new().generate(catalog, 12, "node_multi_combat", "combat")
	var passed: bool = encounter.size() >= 1 \
		and encounter.size() <= 3 \
		and _all_unique(encounter) \
		and _all_ids_have_tier(catalog, encounter, "normal")
	assert(passed)
	return passed

func test_elite_node_can_generate_pure_elite_and_mixed_support_groups() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "elite_a", "tier": "elite"},
		{"id": "elite_b", "tier": "elite"},
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
	])
	var generator := EncounterGenerator.new()
	var saw_pure_elite := false
	var saw_mixed_support := false
	for seed_value in range(1, 128):
		var encounter := generator.generate(catalog, seed_value, "elite_%s" % seed_value, "elite")
		if encounter.is_empty() or encounter.size() > 3 or not _all_unique(encounter):
			assert(false)
			return false
		var tier_sequence := _tiers_for_ids(catalog, encounter)
		var elite_count := tier_sequence.count("elite")
		var normal_count := tier_sequence.count("normal")
		if elite_count < 1 \
				or elite_count > 2 \
				or normal_count > 2 \
				or not _all_tiers_allowed(tier_sequence, ["elite", "normal"]):
			assert(false)
			return false
		if not _primary_tiers_precede_support_tiers(tier_sequence, "elite"):
			assert(false)
			return false
		if normal_count == 0:
			saw_pure_elite = true
		else:
			saw_mixed_support = true
	var passed: bool = saw_pure_elite and saw_mixed_support
	assert(passed)
	return passed

func test_boss_node_can_generate_solo_boss_and_boss_with_support() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "boss_a", "tier": "boss"},
		{"id": "elite_a", "tier": "elite"},
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
	])
	var generator := EncounterGenerator.new()
	var saw_solo_boss := false
	var saw_boss_with_support := false
	for seed_value in range(1, 128):
		var encounter := generator.generate(catalog, seed_value, "boss_%s" % seed_value, "boss")
		if encounter.is_empty() or encounter.size() > 3 or not _all_unique(encounter):
			assert(false)
			return false
		var tier_sequence := _tiers_for_ids(catalog, encounter)
		var boss_count := tier_sequence.count("boss")
		var support_count := encounter.size() - boss_count
		if tier_sequence[0] != "boss" or boss_count != 1 or support_count > 2:
			assert(false)
			return false
		if encounter.size() == 1:
			saw_solo_boss = true
		else:
			saw_boss_with_support = true
	var passed: bool = saw_solo_boss and saw_boss_with_support
	assert(passed)
	return passed

func test_multi_enemy_encounter_order_is_deterministic() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "boss_a", "tier": "boss"},
		{"id": "elite_a", "tier": "elite"},
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
	])
	var generator := EncounterGenerator.new()
	var first := generator.generate(catalog, 777, "boss_multi", "boss")
	var second := generator.generate(catalog, 777, "boss_multi", "boss")
	var passed: bool = first == second
	assert(passed)
	return passed

func test_different_node_ids_can_change_multi_enemy_order_or_composition() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
		{"id": "normal_c", "tier": "normal"},
	])
	var generator := EncounterGenerator.new()
	var saw_difference := false
	for seed_value in range(1, 64):
		var first := generator.generate(catalog, seed_value, "node_alpha", "combat")
		var second := generator.generate(catalog, seed_value, "node_beta", "combat")
		if first != second:
			saw_difference = true
			break
	var passed := saw_difference
	assert(passed)
	return passed

func test_missing_primary_pool_returns_empty_even_when_support_exists() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "normal_a", "tier": "normal"},
		{"id": "normal_b", "tier": "normal"},
	])
	var elite_encounter := EncounterGenerator.new().generate(catalog, 12, "elite_missing", "elite")
	var boss_encounter := EncounterGenerator.new().generate(catalog, 12, "boss_missing", "boss")
	var passed: bool = elite_encounter.is_empty() and boss_encounter.is_empty()
	assert(passed)
	return passed

func test_insufficient_support_pool_does_not_duplicate_enemy_ids() -> bool:
	var catalog := _catalog_with_enemies([
		{"id": "boss_a", "tier": "boss"},
		{"id": "normal_a", "tier": "normal"},
	])
	var generator := EncounterGenerator.new()
	for seed_value in range(1, 64):
		var encounter := generator.generate(catalog, seed_value, "boss_sparse_%s" % seed_value, "boss")
		if encounter.size() > 2 or not _all_unique(encounter):
			assert(false)
			return false
	var passed := true
	assert(passed)
	return passed

func test_default_catalog_has_wave_c_enemy_tier_composition() -> bool:
	var catalog := _catalog()
	var passed: bool = catalog.get_enemies_by_tier("normal").size() == 7 \
		and catalog.get_enemies_by_tier("elite").size() == 5 \
		and catalog.get_enemies_by_tier("boss").size() == 4
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _catalog_with_enemies(enemy_specs: Array) -> ContentCatalog:
	var catalog := ContentCatalog.new()
	for spec: Dictionary in enemy_specs:
		var enemy := EnemyDef.new()
		enemy.id = String(spec["id"])
		enemy.tier = String(spec["tier"])
		catalog.enemies_by_id[enemy.id] = enemy
	return catalog

func _all_ids_have_tier(catalog: ContentCatalog, enemy_ids: Array[String], tier: String) -> bool:
	for enemy_id in enemy_ids:
		var enemy := catalog.get_enemy(enemy_id)
		if enemy == null or enemy.tier != tier:
			return false
	return true

func _tiers_for_ids(catalog: ContentCatalog, enemy_ids: Array[String]) -> Array[String]:
	var tiers: Array[String] = []
	for enemy_id in enemy_ids:
		var enemy := catalog.get_enemy(enemy_id)
		if enemy == null:
			tiers.append("")
		else:
			tiers.append(enemy.tier)
	return tiers

func _primary_tiers_precede_support_tiers(tiers: Array[String], primary_tier: String) -> bool:
	var saw_support := false
	for tier in tiers:
		if tier == primary_tier:
			if saw_support:
				return false
		else:
			saw_support = true
	return true

func _all_support_tiers_allowed(tiers: Array[String], allowed_support_tiers: Array[String]) -> bool:
	for index in range(1, tiers.size()):
		if not allowed_support_tiers.has(tiers[index]):
			return false
	return true

func _all_tiers_allowed(tiers: Array[String], allowed_tiers: Array[String]) -> bool:
	for tier in tiers:
		if not allowed_tiers.has(tier):
			return false
	return true

func _all_unique(values: Array[String]) -> bool:
	var seen := {}
	for value in values:
		if seen.has(value):
			return false
		seen[value] = true
	return true

func _ids(resources: Array) -> Array[String]:
	var ids: Array[String] = []
	for resource in resources:
		ids.append(resource.id)
	return ids
