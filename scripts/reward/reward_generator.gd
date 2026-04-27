class_name RewardGenerator
extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const CardDef := preload("res://scripts/data/card_def.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")

const WEIGHTED_RARITY_ORDER: Array[String] = ["common", "uncommon", "rare"]
const RARITY_FALLBACK_ORDER: Array[String] = ["rare", "uncommon", "common"]

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

func generate_weighted_card_reward(
	catalog: ContentCatalog,
	seed_value: int,
	character_id: String,
	context_key: String,
	rarity_weights: Dictionary,
	count: int = 3
) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:weighted_card:%s" % context_key)
	var candidates: Array = catalog.get_cards_for_character(character_id)
	var card_ids: Array[String] = []
	while card_ids.size() < count and not candidates.is_empty():
		var rarity := _pick_weighted_rarity(rng, rarity_weights)
		var matching := _cards_with_rarity(candidates, rarity)
		var card: CardDef = rng.pick(matching) if not matching.is_empty() else rng.pick(candidates)
		card_ids.append(card.id)
		candidates.erase(card)
	return {
		"type": "card",
		"character_id": character_id,
		"card_ids": card_ids,
	}

func generate_rare_preferred_card_reward(
	catalog: ContentCatalog,
	seed_value: int,
	character_id: String,
	context_key: String,
	count: int = 3
) -> Dictionary:
	var rng = RngService.new(seed_value).fork("reward:rare_preferred_card:%s" % context_key)
	var pool: Array = catalog.get_cards_for_character(character_id)
	var card_ids: Array[String] = []
	for rarity in RARITY_FALLBACK_ORDER:
		var cards := rng.shuffle_copy(_cards_with_rarity(pool, rarity))
		for card: CardDef in cards:
			if card_ids.size() >= count:
				break
			if not card_ids.has(card.id):
				card_ids.append(card.id)
		if card_ids.size() >= count:
			break
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

func _pick_weighted_rarity(rng: RngService, rarity_weights: Dictionary) -> String:
	var total := 0
	for rarity in WEIGHTED_RARITY_ORDER:
		total += max(0, int(rarity_weights.get(rarity, 0)))
	if total <= 0:
		return "common"
	var roll := rng.next_int(1, total)
	var cumulative := 0
	for rarity in WEIGHTED_RARITY_ORDER:
		cumulative += max(0, int(rarity_weights.get(rarity, 0)))
		if roll <= cumulative:
			return rarity
	return "common"

func _cards_with_rarity(cards: Array, rarity: String) -> Array:
	var result: Array = []
	for card: CardDef in cards:
		if card.rarity == rarity:
			result.append(card)
	return result

func _gold_bounds_for_tier(tier: String) -> Vector2i:
	match tier:
		"elite":
			return Vector2i(18, 28)
		"boss":
			return Vector2i(40, 60)
		_:
			return Vector2i(8, 14)
