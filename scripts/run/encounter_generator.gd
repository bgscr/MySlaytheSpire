class_name EncounterGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

func generate(catalog: ContentCatalog, seed_value: int, node_id: String, node_type: String) -> Array[String]:
	var rng: RngService = RngService.new(seed_value).fork("encounter:%s" % node_id)
	match node_type:
		"elite":
			return _generate_elite_encounter(catalog, rng)
		"boss":
			return _generate_boss_encounter(catalog, rng)
		_:
			return _generate_combat_encounter(catalog, rng)

func _generate_combat_encounter(catalog: ContentCatalog, rng: RngService) -> Array[String]:
	var normal_pool := catalog.get_enemies_by_tier("normal")
	if normal_pool.is_empty():
		return []
	var selected_ids := {}
	return _take_unique_enemy_ids(normal_pool, rng.next_int(1, 3), rng, selected_ids)

func _generate_elite_encounter(catalog: ContentCatalog, rng: RngService) -> Array[String]:
	var elite_pool := catalog.get_enemies_by_tier("elite")
	if elite_pool.is_empty():
		return []
	var selected_ids := {}
	var encounter := _take_unique_enemy_ids(elite_pool, rng.next_int(1, 2), rng, selected_ids)
	var support_slots: int = 3 - encounter.size()
	var support_count: int = min(rng.next_int(0, 2), support_slots)
	var support_ids := _take_unique_enemy_ids(catalog.get_enemies_by_tier("normal"), support_count, rng, selected_ids)
	encounter.append_array(support_ids)
	return encounter

func _generate_boss_encounter(catalog: ContentCatalog, rng: RngService) -> Array[String]:
	var boss_pool := catalog.get_enemies_by_tier("boss")
	if boss_pool.is_empty():
		return []
	var selected_ids := {}
	var encounter := _take_unique_enemy_ids(boss_pool, 1, rng, selected_ids)
	var support_slots: int = 3 - encounter.size()
	var support_count: int = min(rng.next_int(0, 2), support_slots)
	var support_pool := _combined_enemy_pool(catalog, ["normal", "elite"])
	var support_ids := _take_unique_enemy_ids(support_pool, support_count, rng, selected_ids)
	encounter.append_array(support_ids)
	return encounter

func _combined_enemy_pool(catalog: ContentCatalog, tiers: Array[String]) -> Array[EnemyDef]:
	var result: Array[EnemyDef] = []
	for tier in tiers:
		result.append_array(catalog.get_enemies_by_tier(tier))
	return result

func _take_unique_enemy_ids(
	pool: Array[EnemyDef],
	desired_count: int,
	rng: RngService,
	selected_ids: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	if desired_count <= 0:
		return result
	var shuffled: Array = rng.shuffle_copy(pool)
	for item in shuffled:
		if result.size() >= desired_count:
			break
		var enemy := item as EnemyDef
		if enemy == null or selected_ids.has(enemy.id):
			continue
		result.append(enemy.id)
		selected_ids[enemy.id] = true
	return result
