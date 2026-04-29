extends RefCounted

const RewardApplier := preload("res://scripts/reward/reward_applier.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_claim_card_adds_selected_card_to_deck() -> bool:
	var run := RunState.new()
	run.deck_ids = ["sword.strike"]
	var reward := {
		"type": "card_choice",
		"card_ids": ["sword.guard", "sword.flash_cut"],
	}
	var applied := RewardApplier.new().claim_card(run, reward, 1)
	var passed: bool = applied \
		and run.deck_ids == ["sword.strike", "sword.flash_cut"]
	assert(passed)
	return passed

func test_claim_card_rejects_invalid_index_without_mutation() -> bool:
	var run := RunState.new()
	run.deck_ids = ["sword.strike"]
	var reward := {
		"type": "card_choice",
		"card_ids": ["sword.guard"],
	}
	var applied := RewardApplier.new().claim_card(run, reward, 3)
	var passed: bool = not applied and run.deck_ids == ["sword.strike"]
	assert(passed)
	return passed

func test_claim_gold_adds_amount_to_run_gold() -> bool:
	var run := RunState.new()
	run.gold = 7
	var reward := {
		"type": "gold",
		"amount": 12,
	}
	var applied := RewardApplier.new().claim_gold(run, reward)
	var passed: bool = applied and run.gold == 19
	assert(passed)
	return passed

func test_claim_relic_adds_unique_relic_only_once() -> bool:
	var run := RunState.new()
	run.relic_ids = ["jade_talisman"]
	var reward := {
		"type": "relic",
		"relic_id": "jade_talisman",
		"tier": "common",
	}
	var first := RewardApplier.new().claim_relic(run, reward)
	var second_reward := {
		"type": "relic",
		"relic_id": "moonwell_seed",
		"tier": "uncommon",
	}
	var second := RewardApplier.new().claim_relic(run, second_reward)
	var passed: bool = first \
		and second \
		and run.relic_ids == ["jade_talisman", "moonwell_seed"]
	assert(passed)
	return passed

func test_claim_relic_rejects_empty_relic_id() -> bool:
	var run := RunState.new()
	var reward := {
		"type": "relic",
		"relic_id": "",
	}
	var applied := RewardApplier.new().claim_relic(run, reward)
	var passed: bool = not applied and run.relic_ids.is_empty()
	assert(passed)
	return passed
