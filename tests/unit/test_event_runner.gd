extends RefCounted

const EventOptionDef := preload("res://scripts/data/event_option_def.gd")
const EventRunner := preload("res://scripts/event/event_runner.gd")
const RunState := preload("res://scripts/run/run_state.gd")

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
