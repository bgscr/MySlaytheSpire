extends RefCounted

const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")

func test_poison_turn_start_loses_hp_ignores_block_and_decays() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.block = 99
	enemy.statuses["poison"] = 3
	CombatStatusRuntime.new().on_turn_started(enemy, state)
	var passed: bool = enemy.current_hp == 17 \
		and enemy.block == 99 \
		and enemy.statuses.get("poison", 0) == 2
	assert(passed)
	return passed

func test_poison_turn_start_removes_status_at_zero() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.statuses["poison"] = 1
	CombatStatusRuntime.new().on_turn_started(enemy, state)
	var passed: bool = enemy.current_hp == 19 \
		and not enemy.statuses.has("poison")
	assert(passed)
	return passed

func test_player_focus_and_target_broken_stance_modify_damage_then_decay() -> bool:
	var state := _state()
	var player := state.player
	var enemy := state.enemies[0]
	player.statuses["sword_focus"] = 2
	enemy.statuses["broken_stance"] = 3
	var runtime := CombatStatusRuntime.new()
	var modified := runtime.modify_damage(state, player, enemy, 10)
	var hp_lost := enemy.take_damage(modified)
	runtime.after_damage(state, player, enemy, modified, hp_lost)
	var passed: bool = modified == 15 \
		and enemy.current_hp == 5 \
		and player.statuses.get("sword_focus", 0) == 1 \
		and enemy.statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_non_player_sword_focus_does_not_modify_damage() -> bool:
	var state := _state()
	var enemy := state.enemies[0]
	enemy.statuses["sword_focus"] = 5
	var modified := CombatStatusRuntime.new().modify_damage(state, enemy, state.player, 7)
	var passed: bool = modified == 7 \
		and enemy.statuses.get("sword_focus", 0) == 5
	assert(passed)
	return passed

func test_non_positive_base_damage_stays_zero_and_does_not_decay() -> bool:
	var state := _state()
	state.player.statuses["sword_focus"] = 2
	state.enemies[0].statuses["broken_stance"] = 2
	var runtime := CombatStatusRuntime.new()
	var modified := runtime.modify_damage(state, state.player, state.enemies[0], -5)
	runtime.after_damage(state, state.player, state.enemies[0], modified, 0)
	var passed: bool = modified == 0 \
		and state.player.statuses.get("sword_focus", 0) == 2 \
		and state.enemies[0].statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_status_text_lists_positive_status_layers_in_key_order() -> bool:
	var combatant := CombatantState.new("sample", 10)
	combatant.statuses["sword_focus"] = 2
	combatant.statuses["poison"] = 3
	combatant.statuses["empty"] = 0
	var passed := CombatStatusRuntime.new().status_text(combatant) == "poison:3 sword_focus:2"
	assert(passed)
	return passed

func _state() -> CombatState:
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 30)
	var enemies: Array[CombatantState] = [CombatantState.new("enemy", 20)]
	state.enemies = enemies
	return state
