extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")

func test_combat_node_generates_normal_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "node_1", "combat")
	var passed: bool = encounter == ["training_puppet"]
	assert(passed)
	return passed

func test_elite_node_generates_elite_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "node_2", "elite")
	var passed: bool = encounter == ["forest_bandit"]
	assert(passed)
	return passed

func test_boss_node_generates_boss_enemy() -> bool:
	var encounter := EncounterGenerator.new().generate(_catalog(), 12, "boss_0", "boss")
	var passed: bool = encounter == ["boss_heart_demon"]
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

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog
