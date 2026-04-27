extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")

func _make_effect(effect_type: String, amount: int, target: String = "enemy") -> EffectDef:
	var effect := EffectDef.new()
	effect.effect_type = effect_type
	effect.amount = amount
	effect.target = target
	return effect

func _make_card(effects: Array[EffectDef]) -> CardDef:
	var card := CardDef.new()
	card.id = "test.card"
	card.cost = 1
	card.effects = effects
	return card

func test_damage_card_reduces_enemy_hp() -> bool:
	var damage := EffectDef.new()
	damage.effect_type = "damage"
	damage.amount = 6
	var card := CardDef.new()
	card.id = "sword.strike"
	card.cost = 1
	card.effects = [damage]
	var player := CombatantState.new("player", 50)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := enemy.current_hp == 14
	assert(passed)
	return passed

func test_block_prevents_damage() -> bool:
	var player := CombatantState.new("player", 50)
	player.block = 4
	player.take_damage(6)
	var passed := player.current_hp == 48 and player.block == 0
	assert(passed)
	return passed

func test_block_effect_through_engine_grants_block() -> bool:
	var block_effect := _make_effect("block", 5, "player")
	var effects: Array[EffectDef] = [block_effect]
	var card := _make_card(effects)
	var player := CombatantState.new("player", 50)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := player.block == 5 and enemy.block == 0
	assert(passed)
	return passed

func test_heal_effect_caps_at_max_hp() -> bool:
	var heal := _make_effect("heal", 10, "player")
	var effects: Array[EffectDef] = [heal]
	var card := _make_card(effects)
	var player := CombatantState.new("player", 20)
	player.current_hp = 18
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := player.current_hp == 20
	assert(passed)
	return passed

func test_effect_targets_route_to_declared_recipient() -> bool:
	var self_damage := _make_effect("damage", 3, "self")
	var target_block := _make_effect("block", 4, "target")
	var target_heal := _make_effect("heal", 2, "enemy")
	var effects: Array[EffectDef] = [self_damage, target_block, target_heal]
	var card := _make_card(effects)
	var player := CombatantState.new("player", 20)
	var enemy := CombatantState.new("enemy", 20)
	enemy.current_hp = 7
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := player.current_hp == 17 and player.block == 0 and enemy.current_hp == 9 and enemy.block == 4
	assert(passed)
	return passed

func test_negative_effect_amounts_do_not_mutate_state() -> bool:
	var negative_damage := _make_effect("damage", -4, "enemy")
	var negative_block := _make_effect("block", -5, "player")
	var negative_heal := _make_effect("heal", -6, "player")
	var effects: Array[EffectDef] = [negative_damage, negative_block, negative_heal]
	var card := _make_card(effects)
	var player := CombatantState.new("player", 20)
	player.current_hp = 10
	player.block = 5
	var enemy := CombatantState.new("enemy", 15)
	enemy.current_hp = 8
	enemy.block = 3
	var engine := CombatEngine.new()
	engine.play_card(card, player, enemy)
	var passed := player.current_hp == 10 and player.block == 5 and enemy.current_hp == 8 and enemy.block == 3
	assert(passed)
	return passed

func test_end_turn_resets_player_block_energy_and_advances_turn() -> bool:
	var state := CombatState.new()
	state.player = CombatantState.new("player", 50)
	state.player.block = 12
	state.turn = 2
	state.energy = 0
	var engine := CombatEngine.new()
	engine.end_turn(state)
	var passed := state.turn == 3 and state.energy == 3 and state.player.block == 0
	assert(passed)
	return passed

func test_take_damage_clamps_overkill_and_returns_hp_lost() -> bool:
	var player := CombatantState.new("player", 10)
	player.block = 3
	var hp_lost := player.take_damage(50)
	var passed := player.current_hp == 0 and player.block == 0 and hp_lost == 10
	assert(passed)
	return passed

func test_direct_negative_amount_guards_do_not_mutate_state() -> bool:
	var player := CombatantState.new("player", 12)
	player.block = 4
	var hp_lost := player.take_damage(-7)
	player.gain_block(-3)
	var passed := player.current_hp == 12 and player.block == 4 and hp_lost == 0
	assert(passed)
	return passed

func test_combat_instances_do_not_share_mutable_state() -> bool:
	var first_combatant := CombatantState.new("first", 10)
	var second_combatant := CombatantState.new("second", 10)
	first_combatant.statuses["weak"] = 2
	var first_state := CombatState.new()
	var second_state := CombatState.new()
	first_state.draw_pile.append("strike")
	first_state.hand.append("defend")
	first_state.enemies.append(first_combatant)
	var first_engine := CombatEngine.new()
	var second_engine := CombatEngine.new()
	var passed := not second_combatant.statuses.has("weak") \
		and second_state.draw_pile.is_empty() \
		and second_state.hand.is_empty() \
		and second_state.enemies.is_empty() \
		and first_engine.executor != second_engine.executor
	assert(passed)
	return passed

func test_stateful_effects_update_combat_state() -> bool:
	var draw := _make_effect("draw_card", 2, "player")
	var energy := _make_effect("gain_energy", 1, "player")
	var gold := _make_effect("gain_gold", 9, "player")
	var effects: Array[EffectDef] = [draw, energy, gold]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	state.energy = 0
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card_in_state(card, state, state.player, enemy)
	var passed: bool = state.pending_draw_count == 2 \
		and state.energy == 1 \
		and state.gold_delta == 9
	assert(passed)
	return passed

func test_apply_status_stacks_positive_amounts() -> bool:
	var poison := _make_effect("apply_status", 3, "enemy")
	poison.status_id = "poison"
	var repeat_poison := _make_effect("apply_status", 2, "target")
	repeat_poison.status_id = "poison"
	var ignored := _make_effect("apply_status", 0, "enemy")
	ignored.status_id = "burn"
	var effects: Array[EffectDef] = [poison, repeat_poison, ignored]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	var enemy := CombatantState.new("enemy", 20)
	var engine := CombatEngine.new()
	engine.play_card_in_state(card, state, state.player, enemy)
	var passed: bool = enemy.statuses.get("poison", 0) == 5 \
		and not enemy.statuses.has("burn")
	assert(passed)
	return passed

func test_stateful_damage_uses_sword_focus_and_broken_stance() -> bool:
	var damage := _make_effect("damage", 10, "enemy")
	var effects: Array[EffectDef] = [damage]
	var card := _make_card(effects)
	var state := CombatState.new()
	state.player = CombatantState.new("sword", 30)
	state.player.statuses["sword_focus"] = 2
	var enemy := CombatantState.new("enemy", 30)
	enemy.statuses["broken_stance"] = 3
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = enemy.current_hp == 15 \
		and state.player.statuses.get("sword_focus", 0) == 1 \
		and enemy.statuses.get("broken_stance", 0) == 2
	assert(passed)
	return passed

func test_stateless_damage_does_not_use_status_runtime() -> bool:
	var damage := _make_effect("damage", 10, "enemy")
	var effects: Array[EffectDef] = [damage]
	var card := _make_card(effects)
	var player := CombatantState.new("sword", 30)
	player.statuses["sword_focus"] = 2
	var enemy := CombatantState.new("enemy", 30)
	enemy.statuses["broken_stance"] = 3
	CombatEngine.new().play_card(card, player, enemy)
	var passed: bool = enemy.current_hp == 20 \
		and player.statuses.get("sword_focus", 0) == 2 \
		and enemy.statuses.get("broken_stance", 0) == 3
	assert(passed)
	return passed

func test_sword_flash_cut_resource_deals_damage_and_draws() -> bool:
	var card := load("res://resources/cards/sword/flash_cut.tres") as CardDef
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	var enemy := CombatantState.new("enemy", 20)
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = enemy.current_hp == 16 and state.pending_draw_count == 1
	assert(passed)
	return passed

func test_alchemy_inner_fire_pill_resource_gains_energy_and_draws() -> bool:
	var card := load("res://resources/cards/alchemy/inner_fire_pill.tres") as CardDef
	var state := CombatState.new()
	state.player = CombatantState.new("player", 30)
	state.energy = 0
	var enemy := CombatantState.new("enemy", 20)
	CombatEngine.new().play_card_in_state(card, state, state.player, enemy)
	var passed: bool = state.energy == 1 and state.pending_draw_count == 1 and enemy.current_hp == 20
	assert(passed)
	return passed
