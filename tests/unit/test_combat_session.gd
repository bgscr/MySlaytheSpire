extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RunState := preload("res://scripts/run/run_state.gd")
const CombatSession := preload("res://scripts/combat/combat_session.gd")

func test_session_initializes_from_run_current_node() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [
		"sword.strike",
		"sword.guard",
		"sword.flash_cut",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.focused_slash",
	])
	var session := CombatSession.new()
	session.start(catalog, run)
	var first_enemy_def: EnemyDef
	var expected_intent := ""
	if not session.state.enemies.is_empty():
		first_enemy_def = catalog.get_enemy(session.state.enemies[0].id)
		if first_enemy_def != null and not first_enemy_def.intent_sequence.is_empty():
			expected_intent = first_enemy_def.intent_sequence[0]

	var passed: bool = session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.id == "sword" \
		and session.state.player.max_hp == 72 \
		and session.state.player.current_hp == 65 \
		and session.state.energy == 3 \
		and session.state.turn == 1 \
		and session.state.hand.size() == 5 \
		and session.state.draw_pile.size() == 1 \
		and session.state.discard_pile.is_empty() \
		and session.state.enemies.size() >= 1 \
		and first_enemy_def != null \
		and session.get_enemy_intent(0) == expected_intent
	assert(passed)
	return passed

func test_session_invalid_when_current_node_is_missing() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("missing_node", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("current map node")
	assert(passed)
	return passed

func test_session_invalid_when_deck_is_empty() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", [])
	var session := CombatSession.new()
	session.start(catalog, run)

	var passed: bool = session.phase == CombatSession.PHASE_INVALID \
		and session.error_text.contains("deck")
	assert(passed)
	return passed

func test_enemy_intent_returns_empty_when_intent_indices_drift() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.enemy_intent_indices.clear()

	var passed: bool = session.get_enemy_intent(0) == ""
	assert(passed)
	return passed

func test_enemy_target_card_waits_for_enemy_and_can_cancel() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	var enemy_hp_before := session.state.enemies[0].current_hp
	var selected := session.select_card(0)
	var canceled := session.cancel_selection()

	var passed: bool = selected \
		and canceled \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.pending_hand_index == -1 \
		and session.pending_card == null \
		and session.state.energy == 3 \
		and session.state.hand == ["sword.strike"] \
		and session.state.discard_pile.is_empty() \
		and session.state.enemies[0].current_hp == enemy_hp_before
	assert(passed)
	return passed

func test_enemy_target_card_damages_selected_enemy_and_discards() -> bool:
	var catalog := _default_catalog()
	var strike_damage := _effect_amount(catalog, "sword.strike", "damage", ["enemy", "target"])
	var strike_cost := _card_cost(catalog, "sword.strike")
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.strike"]
	session.state.draw_pile.clear()
	session.state.discard_pile.clear()
	var enemies: Array[CombatantState] = [
		CombatantState.new("first_enemy", 30),
		CombatantState.new("second_enemy", 30),
	]
	session.state.enemies = enemies

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(1)

	var first_enemy_hp := session.state.enemies[0].current_hp
	var second_enemy_hp := session.state.enemies[1].current_hp
	var passed: bool = selected \
		and confirmed \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and first_enemy_hp == session.state.enemies[0].max_hp \
		and second_enemy_hp == session.state.enemies[1].max_hp - strike_damage \
		and session.state.energy == 3 - strike_cost \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.strike"] \
		and session.pending_card == null
	assert(passed)
	return passed

func test_player_target_card_requires_confirmation_and_can_cancel() -> bool:
	var catalog := _default_catalog()
	var guard_block := _effect_amount(catalog, "sword.guard", "block", ["player", "self", "source"])
	var guard_cost := _card_cost(catalog, "sword.guard")
	var run := _run_with_single_node("node_0", "combat", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)
	var selected := session.select_card(0)
	var canceled := session.cancel_selection()
	var cancel_cleared_pending := session.pending_hand_index == -1 and session.pending_card == null
	selected = selected and session.select_card(0)
	var confirmed := session.confirm_player_target()

	var passed: bool = selected \
		and canceled \
		and cancel_cleared_pending \
		and confirmed \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.player.block == guard_block \
		and session.state.energy == 3 - guard_cost \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.guard"] \
		and session.pending_card == null
	assert(passed)
	return passed

func test_mixed_target_card_affects_enemy_and_player() -> bool:
	var catalog := _default_catalog()
	var horizon_damage := _effect_amount(catalog, "sword.horizon_arc", "damage", ["enemy", "target"])
	var horizon_block := _effect_amount(catalog, "sword.horizon_arc", "block", ["player", "self", "source"])
	var horizon_cost := _card_cost(catalog, "sword.horizon_arc")
	var run := _run_with_single_node("node_0", "combat", ["sword.horizon_arc"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.horizon_arc"]
	session.state.energy = 3
	var enemy_hp_before := session.state.enemies[0].current_hp

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.state.enemies[0].current_hp == enemy_hp_before - horizon_damage \
		and session.state.player.block == horizon_block \
		and session.state.energy == 3 - horizon_cost \
		and session.pending_card == null
	assert(passed)
	return passed

func test_draw_effect_resolves_before_played_card_enters_discard() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.flash_cut"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.flash_cut"]
	session.state.draw_pile.clear()
	session.state.discard_pile.clear()

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.state.hand.is_empty() \
		and session.state.discard_pile == ["sword.flash_cut"] \
		and session.pending_card == null
	assert(passed)
	return passed

func test_insufficient_energy_keeps_card_in_hand() -> bool:
	var catalog := _default_catalog()
	var horizon_cost := _card_cost(catalog, "sword.horizon_arc")
	var energy_before := horizon_cost - 1
	var run := _run_with_single_node("node_0", "combat", ["sword.horizon_arc"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.energy = energy_before
	var selected := session.select_card(0)

	var passed: bool = not selected \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.error_text.contains("energy") \
		and session.state.energy == energy_before \
		and session.state.hand == ["sword.horizon_arc"] \
		and session.state.discard_pile.is_empty()
	assert(passed)
	return passed

func test_draw_reshuffles_discard_when_draw_pile_is_empty() -> bool:
	var catalog := _default_catalog()
	var run := _run_with_single_node("node_0", "combat", ["sword.strike"])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand.clear()
	session.state.draw_pile.clear()
	session.state.discard_pile = ["sword.guard", "sword.qi_surge"]

	session.draw_cards(2)

	var passed: bool = session.state.hand.size() == 2 \
		and session.state.draw_pile.is_empty() \
		and session.state.discard_pile.is_empty() \
		and _same_string_set(session.state.hand, ["sword.guard", "sword.qi_surge"])
	assert(passed)
	return passed

func test_end_turn_discards_hand_and_enemies_act_in_order() -> bool:
	var catalog := _catalog_with_ordered_enemies()
	var run := _run_with_single_node("node_0", "boss", [
		"sword.strike",
		"sword.guard",
		"sword.qi_surge",
		"sword.cloud_step",
		"sword.focused_slash",
	])
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["sword.guard", "sword.qi_surge"]
	session.state.draw_pile = [
		"sword.strike",
		"sword.flash_cut",
		"sword.cloud_step",
		"sword.focused_slash",
		"sword.guard",
	]
	session.state.player.block = 3
	var enemies: Array[CombatantState] = [
		CombatantState.new("first_attacker", 20),
		CombatantState.new("second_attacker", 20),
	]
	session.state.enemies = enemies
	session.enemy_defs_by_id.clear()
	session.enemy_defs_by_id["first_attacker"] = _enemy("first_attacker", "normal", 20, ["attack_5"])
	session.enemy_defs_by_id["second_attacker"] = _enemy("second_attacker", "normal", 20, ["attack_6"])
	var intent_indices: Array[int] = [0, 0]
	session.enemy_intent_indices = intent_indices
	var hp_before := session.state.player.current_hp

	var ended: bool = session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_PLAYER_TURN \
		and session.state.turn == 2 \
		and session.state.energy == 3 \
		and session.state.player.block == 0 \
		and session.state.player.current_hp == hp_before - 11 \
		and session.state.discard_pile.has("sword.guard") \
		and session.state.discard_pile.has("sword.qi_surge")
	assert(passed)
	return passed

func test_enemy_block_clears_at_start_of_next_enemy_turn() -> bool:
	var catalog := _catalog_with_blocking_enemy()
	var run := _run_with_single_node("node_0", "boss", ["sword.guard"])
	var session := CombatSession.new()
	session.start(catalog, run)

	session.end_player_turn()
	var block_after_first_enemy_turn := session.state.enemies[0].block
	session.end_player_turn()
	var block_after_second_enemy_turn := session.state.enemies[0].block

	var passed: bool = block_after_first_enemy_turn == 8 \
		and block_after_second_enemy_turn == 8
	assert(passed)
	return passed

func test_defeating_all_enemies_sets_won_and_writes_run() -> bool:
	var catalog := _catalog_with_low_hp_enemy()
	var run := _run_with_single_node("node_0", "combat", ["test.execute"])
	run.gold = 5
	var session := CombatSession.new()
	session.start(catalog, run)
	session.state.hand = ["test.execute"]
	session.state.draw_pile.clear()

	var selected := session.select_card(0)
	var confirmed := session.confirm_enemy_target(0)

	var passed: bool = selected \
		and confirmed \
		and session.phase == CombatSession.PHASE_WON \
		and run.current_hp == session.state.player.current_hp \
		and run.gold == 5
	assert(passed)
	return passed

func test_player_death_sets_lost_and_failed_run() -> bool:
	var catalog := _catalog_with_lethal_enemy()
	var run := _run_with_single_node("node_0", "boss", ["sword.guard"])
	run.current_hp = 4
	var session := CombatSession.new()
	session.start(catalog, run)

	var ended: bool = session.end_player_turn()

	var passed: bool = ended \
		and session.phase == CombatSession.PHASE_LOST \
		and run.failed \
		and run.current_hp == 0
	assert(passed)
	return passed

func _default_catalog() -> ContentCatalog:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	return catalog

func _run_with_single_node(current_node_id: String, node_type: String, deck_ids: Array[String]) -> RunState:
	var run := RunState.new()
	run.seed_value = 12345
	run.character_id = "sword"
	run.max_hp = 72
	run.current_hp = 65
	run.deck_ids = deck_ids
	run.current_node_id = current_node_id
	var node := MapNodeState.new("node_0", 0, node_type)
	node.unlocked = true
	run.map_nodes = [node]
	return run

func _card_cost(catalog: ContentCatalog, card_id: String) -> int:
	var card := catalog.get_card(card_id)
	assert(card != null)
	if card == null:
		return 0
	return card.cost

func _effect_amount(
	catalog: ContentCatalog,
	card_id: String,
	effect_type: String,
	targets: Array[String]
) -> int:
	var card := catalog.get_card(card_id)
	assert(card != null)
	if card == null:
		return 0
	var total := 0
	for effect: EffectDef in card.effects:
		if effect.effect_type == effect_type and targets.has(effect.target.to_lower()):
			total += effect.amount
	return total

func _same_string_set(values: Array[String], expected: Array[String]) -> bool:
	if values.size() != expected.size():
		return false
	for value in values:
		if not expected.has(value):
			return false
	for expected_value in expected:
		if not values.has(expected_value):
			return false
	return true

func _catalog_with_ordered_enemies() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_boss", "boss", 50, ["attack_5"])
	var elite := _enemy("test_elite", "elite", 40, ["attack_6"])
	catalog.enemies_by_id[boss.id] = boss
	catalog.enemies_by_id[elite.id] = elite
	return catalog

func _catalog_with_blocking_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_block_boss", "boss", 50, ["block_8"])
	catalog.enemies_by_id[boss.id] = boss
	return catalog

func _catalog_with_low_hp_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var enemy := _enemy("test_low_hp", "normal", 3, [])
	catalog.enemies_by_id[enemy.id] = enemy
	var card := CardDef.new()
	card.id = "test.execute"
	card.cost = 1
	card.effects = [_effect("damage", 99, "enemy")]
	catalog.cards_by_id[card.id] = card
	return catalog

func _catalog_with_lethal_enemy() -> ContentCatalog:
	var catalog := _default_catalog()
	catalog.enemies_by_id.clear()
	var boss := _enemy("test_lethal_boss", "boss", 50, ["attack_99"])
	catalog.enemies_by_id[boss.id] = boss
	return catalog

func _enemy(enemy_id: String, tier: String, hp: int, intents: Array[String]) -> EnemyDef:
	var enemy := EnemyDef.new()
	enemy.id = enemy_id
	enemy.tier = tier
	enemy.max_hp = hp
	enemy.intent_sequence = intents
	return enemy

func _effect(effect_type: String, amount: int, target: String) -> EffectDef:
	var effect := EffectDef.new()
	effect.effect_type = effect_type
	effect.amount = amount
	effect.target = target
	return effect
