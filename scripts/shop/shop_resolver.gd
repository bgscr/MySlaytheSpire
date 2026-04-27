class_name ShopResolver
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RngService := preload("res://scripts/core/rng_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

const HEAL_PRICE := 45
const REMOVE_PRICE := 75
const REFRESH_PRICE := 35

var created_new_state := false

func resolve(catalog: ContentCatalog, run: RunState) -> Dictionary:
	created_new_state = false
	if catalog == null or run == null:
		return {}
	var node := _current_node(run)
	if node == null or node.node_type != "shop":
		return {}
	if _matches_current_shop(run.current_shop_state, node.id):
		return run.current_shop_state
	var rng := RngService.new(run.seed_value).fork("shop:%s" % node.id)
	var state := {
		"node_id": node.id,
		"refresh_used": false,
		"offers": _build_initial_offers(catalog, run, rng),
	}
	run.current_shop_state = state
	created_new_state = true
	return run.current_shop_state

func build_refreshed_item_offers(catalog: ContentCatalog, run: RunState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if catalog == null or run == null:
		return result
	var node := _current_node(run)
	if node == null:
		return result
	var rng := RngService.new(run.seed_value).fork("shop:refresh:%s" % node.id)
	result.append_array(_card_offers(catalog, run, rng))
	result.append_array(_relic_offers(catalog, run, rng))
	return result

func card_price(rarity: String) -> int:
	match rarity:
		"uncommon":
			return 60
		"rare":
			return 85
		_:
			return 40

func relic_price(tier: String) -> int:
	match tier:
		"uncommon":
			return 160
		"rare":
			return 220
		"boss":
			return 260
		_:
			return 120

func _build_initial_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	offers.append_array(_card_offers(catalog, run, rng))
	offers.append_array(_relic_offers(catalog, run, rng))
	offers.append({
		"id": "heal_0",
		"type": "heal",
		"item_id": "",
		"price": HEAL_PRICE,
		"sold": false,
	})
	offers.append({
		"id": "remove_0",
		"type": "remove",
		"item_id": "",
		"price": REMOVE_PRICE,
		"sold": false,
	})
	return offers

func _card_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var pool: Array = rng.shuffle_copy(catalog.get_cards_for_character(run.character_id))
	for card: CardDef in pool:
		if offers.size() >= 3:
			break
		offers.append({
			"id": "card_%s" % offers.size(),
			"type": "card",
			"item_id": card.id,
			"price": card_price(card.rarity),
			"sold": false,
		})
	return offers

func _relic_offers(catalog: ContentCatalog, run: RunState, rng: RngService) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var relics: Array = rng.shuffle_copy(catalog.relics_by_id.values())
	for relic: RelicDef in relics:
		if offers.size() >= 2:
			break
		if run.relic_ids.has(relic.id):
			continue
		offers.append({
			"id": "relic_%s" % offers.size(),
			"type": "relic",
			"item_id": relic.id,
			"price": relic_price(relic.tier),
			"sold": false,
		})
	return offers

func _matches_current_shop(state: Dictionary, node_id: String) -> bool:
	return not state.is_empty() and String(state.get("node_id", "")) == node_id

func _current_node(run: RunState) -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node != null and node.id == run.current_node_id:
			return node
	return null
