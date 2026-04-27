extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ShopRunner := preload("res://scripts/shop/shop_runner.gd")

func test_runner_buys_card_and_marks_offer_sold() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var deck_size_before := run.deck_ids.size()
	var flash_cut_count_before := _card_count(run, "sword.flash_cut")
	var applied := runner.buy_offer(_catalog(), run, "card_0")
	var offer := _offer(run, "card_0")
	var passed: bool = applied \
		and run.gold == 160 \
		and run.deck_ids.size() == deck_size_before + 1 \
		and _card_count(run, "sword.flash_cut") == flash_cut_count_before + 1 \
		and offer.get("sold") == true
	assert(passed)
	return passed

func test_runner_buys_relic_and_rejects_sold_relic() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var first := runner.buy_offer(_catalog(), run, "relic_0")
	var gold_after_first := run.gold
	var second := runner.buy_offer(_catalog(), run, "relic_0")
	var passed: bool = first \
		and not second \
		and run.relic_ids == ["jade_talisman"] \
		and run.gold == gold_after_first
	assert(passed)
	return passed

func test_runner_rejects_duplicate_relic_without_mutation() -> bool:
	var run := _run()
	run.relic_ids = ["jade_talisman"]
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "relic_0")
	var passed: bool = not applied \
		and run.gold == 200 \
		and run.relic_ids == ["jade_talisman"] \
		and _offer(run, "relic_0").get("sold") == false
	assert(passed)
	return passed

func test_runner_rejects_insufficient_gold_without_mutation() -> bool:
	var run := _run()
	run.gold = 10
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "card_0")
	var offer := _offer(run, "card_0")
	var passed: bool = not applied \
		and run.gold == 10 \
		and run.deck_ids == ["sword.strike", "sword.guard", "sword.flash_cut"] \
		and offer.get("sold") == false
	assert(passed)
	return passed

func test_runner_heals_with_clamp_and_rejects_sold_heal() -> bool:
	var run := _run()
	run.current_hp = 60
	run.max_hp = 72
	var runner := ShopRunner.new()
	var healed := runner.buy_offer(_catalog(), run, "heal_0")
	var hp_after_heal := run.current_hp
	var gold_after_heal := run.gold
	var second := runner.buy_offer(_catalog(), run, "heal_0")
	var passed: bool = healed \
		and hp_after_heal == 72 \
		and gold_after_heal == 155 \
		and not second \
		and run.current_hp == 72 \
		and run.gold == gold_after_heal
	assert(passed)
	return passed

func test_runner_rejects_full_hp_heal_without_mutation() -> bool:
	var run := _run()
	run.current_hp = 72
	run.max_hp = 72
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "heal_0")
	var passed: bool = not applied \
		and run.gold == 200 \
		and run.current_hp == 72 \
		and _offer(run, "heal_0").get("sold") == false
	assert(passed)
	return passed

func test_runner_removes_selected_card_once() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var removed := runner.buy_offer(_catalog(), run, "remove_0", "sword.guard")
	var second := runner.buy_offer(_catalog(), run, "remove_0", "sword.strike")
	var passed: bool = removed \
		and not second \
		and run.gold == 125 \
		and run.deck_ids == ["sword.strike", "sword.flash_cut"] \
		and _offer(run, "remove_0").get("sold") == true
	assert(passed)
	return passed

func test_runner_rejects_missing_remove_card_without_mutation() -> bool:
	var run := _run()
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "remove_0", "missing.card")
	var passed: bool = not applied \
		and run.gold == 200 \
		and run.deck_ids == ["sword.strike", "sword.guard", "sword.flash_cut"] \
		and _offer(run, "remove_0").get("sold") == false
	assert(passed)
	return passed

func test_runner_rejects_too_small_deck_removal_without_mutation() -> bool:
	var run := _run()
	run.deck_ids = ["sword.strike"]
	var applied := ShopRunner.new().buy_offer(_catalog(), run, "remove_0", "sword.strike")
	var passed: bool = not applied \
		and run.gold == 200 \
		and run.deck_ids == ["sword.strike"] \
		and _offer(run, "remove_0").get("sold") == false
	assert(passed)
	return passed

func test_runner_refreshes_once_and_preserves_sold_and_service_offers() -> bool:
	var run := _run()
	var runner := ShopRunner.new()
	var bought := runner.buy_offer(_catalog(), run, "card_0")
	var sold_card_item := String(_offer(run, "card_0").get("item_id", ""))
	var heal_before := (_offer(run, "heal_0") as Dictionary).duplicate(true)
	var remove_before := (_offer(run, "remove_0") as Dictionary).duplicate(true)
	var refreshed := runner.refresh(_catalog(), run)
	var second_refresh := runner.refresh(_catalog(), run)
	var passed: bool = bought \
		and refreshed \
		and not second_refresh \
		and run.gold == 125 \
		and run.current_shop_state.get("refresh_used") == true \
		and _offer(run, "card_0").get("sold") == true \
		and _offer(run, "card_0").get("item_id") == sold_card_item \
		and _offer(run, "card_1").get("sold") == false \
		and _offer(run, "heal_0") == heal_before \
		and _offer(run, "remove_0") == remove_before
	assert(passed)
	return passed

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run() -> RunState:
	var run := RunState.new()
	run.seed_value = 123
	run.character_id = "sword"
	run.current_hp = 40
	run.max_hp = 72
	run.gold = 200
	run.deck_ids = ["sword.strike", "sword.guard", "sword.flash_cut"]
	run.current_node_id = "node_0"
	var current := MapNodeState.new("node_0", 0, "shop")
	current.unlocked = true
	run.map_nodes = [current]
	run.current_shop_state = {
		"node_id": "node_0",
		"refresh_used": false,
		"offers": [
			{
				"id": "card_0",
				"type": "card",
				"item_id": "sword.flash_cut",
				"price": 40,
				"sold": false,
			},
			{
				"id": "card_1",
				"type": "card",
				"item_id": "sword.guardian_stance",
				"price": 60,
				"sold": false,
			},
			{
				"id": "relic_0",
				"type": "relic",
				"item_id": "jade_talisman",
				"price": 120,
				"sold": false,
			},
			{
				"id": "heal_0",
				"type": "heal",
				"item_id": "",
				"price": 45,
				"sold": false,
			},
			{
				"id": "remove_0",
				"type": "remove",
				"item_id": "",
				"price": 75,
				"sold": false,
			},
		],
	}
	return run

func _offer(run: RunState, offer_id: String) -> Dictionary:
	for offer in run.current_shop_state.get("offers", []):
		var payload := offer as Dictionary
		if payload.get("id") == offer_id:
			return payload
	return {}

func _card_count(run: RunState, card_id: String) -> int:
	var total := 0
	for existing_id in run.deck_ids:
		if existing_id == card_id:
			total += 1
	return total
