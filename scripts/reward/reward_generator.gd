class_name RewardGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CardDef := preload("res://scripts/data/card_def.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

func generate_card_reward(catalog: ContentCatalog, seed_value: int, character_id: String, context_key: String, count: int = 3) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:card:%s" % context_key)
	var pool := catalog.get_cards_for_character(character_id)
	var shuffled: Array = rng.shuffle_copy(pool)
	var card_ids: Array[String] = []
	for card: CardDef in shuffled:
		if card_ids.size() >= count:
			break
		card_ids.append(card.id)
	return {
		"type": "card",
		"character_id": character_id,
		"card_ids": card_ids,
	}

func generate_gold_reward(seed_value: int, context_key: String, tier: String) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:gold:%s" % context_key)
	var bounds := _gold_bounds_for_tier(tier)
	return {
		"type": "gold",
		"tier": tier,
		"amount": rng.next_int(bounds.x, bounds.y),
	}

func generate_relic_reward(catalog: ContentCatalog, seed_value: int, context_key: String, tier: String) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:relic:%s" % context_key)
	var relics := catalog.get_relics_by_tier(tier)
	if relics.is_empty():
		return {
			"type": "relic",
			"tier": tier,
			"relic_id": "",
		}
	var relic: RelicDef = rng.pick(relics)
	return {
		"type": "relic",
		"tier": tier,
		"relic_id": relic.id,
	}

func _gold_bounds_for_tier(tier: String) -> Vector2i:
	match tier:
		"elite":
			return Vector2i(18, 28)
		"boss":
			return Vector2i(40, 60)
		_:
			return Vector2i(8, 14)
