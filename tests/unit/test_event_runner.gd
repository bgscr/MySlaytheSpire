extends RefCounted

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EventDef := preload("res://scripts/data/event_def.gd")

func test_runner_applies_hp_and_gold_deltas() -> bool:
	var run := _run(20, 40, 10)
	var option := _option(0, 0, 7, -5)
	var applied := EventRunner.new().apply_option(run, option)
	var passed: bool = applied and run.current_hp == 27 and run.gold == 5
	assert(passed)
	return passed

func test_runner_clamps_hp_and_gold() -> bool:
	var run := _run(4, 30, 2)
	var option := _option(0, 0, -99, -99)
	var applied := EventRunner.new().apply_option(run, option)
	var passed: bool = applied and run.current_hp == 1 and run.gold == 0
	assert(passed)
	return passed

func test_runner_rejects_unavailable_option_without_mutation() -> bool:
	var run := _run(5, 30, 10)
	var option := _option(7, 25, -6, 35)
	var runner := EventRunner.new()
	var applied := runner.apply_option(run, option)
	var reason := runner.unavailable_reason(run, option)
	var passed: bool = not applied \
		and run.current_hp == 5 \
		and run.gold == 10 \
		and reason.contains("Requires")
	assert(passed)
	return passed

func test_runner_grants_direct_cards_and_relics() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	var option := _option(0, 0, 0, 0)
	option.grant_card_ids = ["sword.flash_cut"]
	option.grant_relic_ids = ["jade_talisman"]
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = applied \
		and run.deck_ids.has("sword.flash_cut") \
		and run.relic_ids == ["jade_talisman"] \
		and run.current_reward_state.is_empty()
	assert(passed)
	return passed

func test_runner_rejects_duplicate_direct_relic_without_duplicate() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.relic_ids = ["jade_talisman"]
	var option := _option(0, 0, 0, 0)
	option.grant_relic_ids = ["jade_talisman"]
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = applied and run.relic_ids == ["jade_talisman"]
	assert(passed)
	return passed

func test_runner_remove_card_option_requires_card_and_removes_one_copy() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.deck_ids = ["sword.strike", "sword.strike", "sword.guard"]
	var option := _option(0, 0, 0, 0)
	option.remove_card_id = "sword.strike"
	var runner := EventRunner.new()
	var available_before := runner.is_option_available(run, option)
	var applied := runner.apply_event_option(catalog, run, _event("test_event", option), option)
	var passed: bool = available_before \
		and applied \
		and run.deck_ids == ["sword.strike", "sword.guard"]
	assert(passed)
	return passed

func test_runner_remove_card_option_unavailable_when_card_missing() -> bool:
	var run := _run(20, 40, 10)
	run.deck_ids = ["sword.guard"]
	var option := _option(0, 0, 0, 0)
	option.remove_card_id = "sword.strike"
	var runner := EventRunner.new()
	var available := runner.is_option_available(run, option)
	var reason := runner.unavailable_reason(run, option)
	var applied := runner.apply_event_option(_catalog(), run, _event("test_event", option), option)
	var passed: bool = not available \
		and not applied \
		and reason.contains("Requires card") \
		and run.deck_ids == ["sword.guard"]
	assert(passed)
	return passed

func test_runner_creates_deterministic_card_reward_state() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.seed_value = 777
	run.character_id = "sword"
	run.current_node_id = "node_event"
	var option := _option(0, 0, -3, 0)
	option.id = "train"
	option.card_reward_count = 2
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("forgotten_armory", option), option)
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var first_reward: Dictionary = rewards[0] if rewards.size() > 0 else {}
	var card_ids: Array = first_reward.get("card_ids", [])
	var passed: bool = applied \
		and run.current_hp == 17 \
		and run.current_reward_state.get("source") == "event" \
		and run.current_reward_state.get("node_id") == "node_event" \
		and first_reward.get("type") == "card_choice" \
		and card_ids.size() == 2
	assert(passed)
	return passed

func test_runner_creates_deterministic_relic_reward_state() -> bool:
	var catalog := _catalog()
	var run := _run(20, 40, 10)
	run.seed_value = 778
	run.current_node_id = "node_event"
	var option := _option(0, 0, 0, 0)
	option.id = "claim"
	option.relic_reward_tier = "common"
	var applied := EventRunner.new().apply_event_option(catalog, run, _event("moonlit_ferry", option), option)
	var rewards: Array = run.current_reward_state.get("rewards", [])
	var first_reward: Dictionary = rewards[0] if rewards.size() > 0 else {}
	var passed: bool = applied \
		and first_reward.get("type") == "relic" \
		and first_reward.get("tier") == "common" \
		and not String(first_reward.get("relic_id", "")).is_empty()
	assert(passed)
	return passed

func _run(current_hp: int, max_hp: int, gold: int) -> RunState:
	var run := RunState.new()
	run.current_hp = current_hp
	run.max_hp = max_hp
	run.gold = gold
	return run

func _option(min_hp: int, min_gold: int, hp_delta: int, gold_delta: int) -> EventOptionDef:
	var option := EventOptionDef.new()
	option.id = "test_option"
	option.min_hp = min_hp
	option.min_gold = min_gold
	option.hp_delta = hp_delta
	option.gold_delta = gold_delta
	return option

func _catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _event(event_id: String, option: EventOptionDef) -> EventDef:
	var event := EventDef.new()
	event.id = event_id
	event.options = [option]
	return event
