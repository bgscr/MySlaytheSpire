class_name EncounterGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

func generate(catalog: ContentCatalog, seed_value: int, node_id: String, node_type: String) -> Array[String]:
	var tier := _tier_for_node_type(node_type)
	var pool := catalog.get_enemies_by_tier(tier)
	if pool.is_empty():
		return []
	var rng = RngService.new(seed_value).fork("encounter:%s" % node_id)
	var enemy: EnemyDef = rng.pick(pool)
	return [enemy.id]

func _tier_for_node_type(node_type: String) -> String:
	match node_type:
		"elite":
			return "elite"
		"boss":
			return "boss"
		_:
			return "normal"
