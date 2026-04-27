extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopResolver := preload("res://scripts/shop/shop_resolver.gd")

func test_shop_resolver_generates_deterministic_shop_state() -> bool:
	var catalog := _catalog()
	var first_run := _shop_run(707)
	var second_run := _shop_run(707)
	var first_resolver := ShopResolver.new()
	var second_resolver := ShopResolver.new()
	var first := first_resolver.resolve(catalog, first_run)
	var second := second_resolver.resolve(catalog, second_run)
	var passed: bool = first == second \
		and first_resolver.created_new_state \
		and second_resolver.created_new_state \
		and String(first.get("node_id", "")) == "node_0" \
		and first.get("refresh_used", true) == false \
		and _offers_of_type(first, "card").size() == 3 \
		and _offers_of_type(first, "relic").size() == 2 \
		and _offers_of_type(first, "heal").size() == 1 \
		and _offers_of_type(first, "remove").size() == 1
	assert(passed)
	return passed

func test_shop_resolver_resumes_matching_saved_state() -> bool:
	var run := _shop_run(808)
	run.current_shop_state = {
		"node_id": "node_0",
		"refresh_used": true,
		"offers": [
			_offer("card_0", "card", "sword.guard", 40, true),
		],
	}
	var resolver := ShopResolver.new()
	var state := resolver.resolve(_catalog(), run)
	var offers: Array = state.get("offers", [])
	var passed: bool = not resolver.created_new_state \
		and offers.size() == 1 \
		and (offers[0] as Dictionary).get("item_id") == "sword.guard" \
		and (offers[0] as Dictionary).get("sold") == true
	assert(passed)
	return passed

func test_shop_resolver_replaces_state_for_different_node() -> bool:
	var run := _shop_run(909)
	run.current_shop_state = {
		"node_id": "old_node",
		"refresh_used": true,
		"offers": [],
	}
	var resolver := ShopResolver.new()
	var state := resolver.resolve(_catalog(), run)
	var passed: bool = resolver.created_new_state \
		and state.get("node_id") == "node_0" \
		and state.get("refresh_used") == false \
		and not (state.get("offers", []) as Array).is_empty()
	assert(passed)
	return passed

func test_shop_resolver_returns_empty_for_non_shop_node() -> bool:
	var run := _shop_run(1001)
	run.map_nodes[0].node_type = "event"
	var state := ShopResolver.new().resolve(_catalog(), run)
	var passed: bool = state.is_empty()
	assert(passed)
	return passed

func test_shop_resolver_excludes_owned_relics() -> bool:
	var run := _shop_run(1002)
	run.relic_ids = [
		"jade_talisman",
		"bronze_incense_burner",
		"cracked_spirit_coin",
		"moonwell_seed",
		"thunderseal_charm",
	]
	var state := ShopResolver.new().resolve(_catalog(), run)
	var relic_offers := _offers_of_type(state, "relic")
	var passed: bool = relic_offers.size() == 1 \
		and not run.relic_ids.has(String((relic_offers[0] as Dictionary).get("item_id", "")))
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _shop_run(seed_value: int) -> RunState:
	var run := RunState.new()
	run.seed_value = seed_value
	run.character_id = "sword"
	run.current_hp = 50
	run.max_hp = 72
	run.gold = 300
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeState.new("node_0", 0, "shop")
	current.unlocked = true
	run.map_nodes = [current]
	return run

func _offer(offer_id: String, offer_type: String, item_id: String, price: int, sold: bool) -> Dictionary:
	return {
		"id": offer_id,
		"type": offer_type,
		"item_id": item_id,
		"price": price,
		"sold": sold,
	}

func _offers_of_type(state: Dictionary, offer_type: String) -> Array:
	var result := []
	for offer in state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("type", "") == offer_type:
			result.append(payload)
	return result
