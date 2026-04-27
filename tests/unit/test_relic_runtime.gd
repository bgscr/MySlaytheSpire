extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const GameEvent := preload("res://scripts/core/game_event.gd")
const RelicDef := preload("res://scripts/data/relic_def.gd")
const RelicRuntime := preload("res://scripts/relic/relic_runtime.gd")
const RunState := preload("res://scripts/run/run_state.gd")

func test_combat_started_applies_matching_relic_block() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [_effect("block", 4, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_started"), catalog, _run_with_relics(["test.block"]), state)
	var passed: bool = state.player.block == 4
	assert(passed)
	return passed

func test_missing_relic_ids_are_ignored() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [_effect("block", 4, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_started"), catalog, _run_with_relics(["missing.relic", "test.block"]), state)
	var passed: bool = state.player.block == 4
	assert(passed)
	return passed

func test_non_matching_trigger_does_not_apply() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_won", [_effect("block", 4, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_started"), catalog, _run_with_relics(["test.block"]), state)
	var passed: bool = state.player.block == 0
	assert(passed)
	return passed

func test_combat_started_applies_only_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.block"] = _relic("test.block", "combat_started", [_effect("block", 4, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	var run := _run_with_relics(["test.block"])
	runtime.handle_event(GameEvent.new("combat_started"), catalog, run, state)
	runtime.handle_event(GameEvent.new("combat_started"), catalog, run, state)
	var passed: bool = state.player.block == 4
	assert(passed)
	return passed

func test_combat_won_applies_only_once() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.gold"] = _relic("test.gold", "combat_won", [_effect("gain_gold", 8, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	var run := _run_with_relics(["test.gold"])
	runtime.handle_event(GameEvent.new("combat_won"), catalog, run, state)
	runtime.handle_event(GameEvent.new("combat_won"), catalog, run, state)
	var passed: bool = state.gold_delta == 8
	assert(passed)
	return passed

func test_turn_started_applies_every_time() -> bool:
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.energy"] = _relic("test.energy", "turn_started", [_effect("gain_energy", 1, "player")])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	var run := _run_with_relics(["test.energy"])
	runtime.handle_event(GameEvent.new("turn_started"), catalog, run, state)
	runtime.handle_event(GameEvent.new("turn_started"), catalog, run, state)
	var passed: bool = state.energy == 5
	assert(passed)
	return passed

func test_apply_status_effects_stack_on_player() -> bool:
	var first_focus := _effect("apply_status", 1, "player")
	first_focus.status_id = "sword_focus"
	var second_focus := _effect("apply_status", 2, "player")
	second_focus.status_id = "sword_focus"
	var catalog := ContentCatalog.new()
	catalog.relics_by_id["test.focus_one"] = _relic("test.focus_one", "combat_started", [first_focus])
	catalog.relics_by_id["test.focus_two"] = _relic("test.focus_two", "combat_started", [second_focus])
	var state := _combat_state()
	var runtime := RelicRuntime.new()
	runtime.handle_event(GameEvent.new("combat_started"), catalog, _run_with_relics(["test.focus_one", "test.focus_two"]), state)
	var passed: bool = state.player.statuses.get("sword_focus", 0) == 3
	assert(passed)
	return passed

func _combat_state() -> CombatState:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 72)
	state.energy = 3
	return state

func _run_with_relics(relic_ids: Array[String]) -> RunState:
	var run := RunState.new()
	run.relic_ids = relic_ids
	return run

func _relic(relic_id: String, trigger_event: String, effects: Array[EffectDef]) -> RelicDef:
	var relic := RelicDef.new()
	relic.id = relic_id
	relic.trigger_event = trigger_event
	relic.effects = effects
	return relic

func _effect(effect_type: String, amount: int, target: String) -> EffectDef:
	var effect := EffectDef.new()
	effect.effect_type = effect_type
	effect.amount = amount
	effect.target = target
	return effect
