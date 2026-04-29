class_name CombatSession
extends RefCounted

const CardDef := preload("res://scripts/data/card_def.gd")
const CombatEngine := preload("res://scripts/combat/combat_engine.gd")
const CombatState := preload("res://scripts/combat/combat_state.gd")
const CombatStatusRuntime := preload("res://scripts/combat/combat_status_runtime.gd")
const CombatantState := preload("res://scripts/combat/combatant_state.gd")
const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EffectDef := preload("res://scripts/data/effect_def.gd")
const EncounterGenerator := preload("res://scripts/run/encounter_generator.gd")
const EnemyDef := preload("res://scripts/data/enemy_def.gd")
const GameEvent := preload("res://scripts/core/game_event.gd")
const MapNodeState := preload("res://scripts/run/map_node_state.gd")
const RelicRuntime := preload("res://scripts/relic/relic_runtime.gd")
const RngService := preload("res://scripts/core/rng_service.gd")
const RunState := preload("res://scripts/run/run_state.gd")

const PHASE_INVALID := "invalid"
const PHASE_PLAYER_TURN := "player_turn"
const PHASE_SELECTING_ENEMY_TARGET := "selecting_enemy_target"
const PHASE_CONFIRMING_PLAYER_TARGET := "confirming_player_target"
const PHASE_ENEMY_TURN := "enemy_turn"
const PHASE_WON := "won"
const PHASE_LOST := "lost"

var catalog: ContentCatalog
var run: RunState
var state := CombatState.new()
var engine := CombatEngine.new()
var status_runtime := CombatStatusRuntime.new()
var relic_runtime := RelicRuntime.new()
var phase := PHASE_INVALID
var error_text := ""
var pending_hand_index := -1
var pending_card: CardDef
var enemy_defs_by_id: Dictionary = {}
var enemy_intent_indices: Array[int] = []
var rng := RngService.new(1)
var terminal_rewards_applied := false

func start(input_catalog: ContentCatalog, input_run: RunState) -> void:
	catalog = input_catalog
	run = input_run
	_reset_runtime_state()
	if run == null:
		_set_invalid("CombatSession cannot start without a run.")
		return
	if catalog == null:
		_set_invalid("CombatSession cannot start without a catalog.")
		return
	rng = RngService.new(run.seed_value).fork("combat:%s" % run.current_node_id)
	_initialize_from_run()

func start_sandbox(
	input_catalog: ContentCatalog,
	character_id: String,
	deck_ids: Array[String],
	enemy_ids: Array[String],
	seed_value: int = 1
) -> void:
	catalog = input_catalog
	run = null
	_reset_runtime_state()
	if catalog == null:
		_set_invalid("CombatSession sandbox cannot start without a catalog.")
		return
	if deck_ids.is_empty():
		_set_invalid("CombatSession sandbox cannot start with an empty deck.")
		return
	if enemy_ids.is_empty():
		_set_invalid("CombatSession sandbox cannot start without enemies.")
		return
	if enemy_ids.size() > 3:
		_set_invalid("CombatSession sandbox requires one to three enemies.")
		return
	var character := catalog.get_character(character_id)
	if character == null:
		_set_invalid("CombatSession sandbox character is missing: %s" % character_id)
		return
	rng = RngService.new(seed_value).fork("sandbox:%s:%s" % [character_id, ",".join(enemy_ids)])
	state.player = CombatantState.new(character.id, max(1, character.max_hp))
	state.energy = 3
	state.turn = 1
	state.draw_pile = _shuffle_card_ids(deck_ids)
	for enemy_id in enemy_ids:
		var enemy_def := catalog.get_enemy(enemy_id)
		if enemy_def == null:
			_set_invalid("CombatSession sandbox enemy is missing: %s" % enemy_id)
			return
		enemy_defs_by_id[enemy_id] = enemy_def
		state.enemies.append(CombatantState.new(enemy_id, enemy_def.max_hp))
		enemy_intent_indices.append(0)
	_start_player_turn()

func get_enemy_intent(enemy_index: int) -> String:
	if enemy_index < 0 or enemy_index >= state.enemies.size():
		return ""
	if enemy_index >= enemy_intent_indices.size():
		return ""
	var enemy := state.enemies[enemy_index]
	var enemy_def := enemy_defs_by_id.get(enemy.id) as EnemyDef
	if enemy_def == null or enemy_def.intent_sequence.is_empty():
		return ""
	var intent_index := enemy_intent_indices[enemy_index] % enemy_def.intent_sequence.size()
	return enemy_def.intent_sequence[intent_index]

func select_card(hand_index: int) -> bool:
	if phase != PHASE_PLAYER_TURN:
		error_text = "Cards can only be selected during the player turn."
		return false
	if hand_index < 0 or hand_index >= state.hand.size():
		error_text = "Card selection index is invalid: %d" % hand_index
		return false
	var card_id := state.hand[hand_index]
	var card: CardDef = null
	if catalog != null:
		card = catalog.get_card(card_id)
	if card == null:
		error_text = "Selected card is missing from catalog: %s" % card_id
		return false
	if state.energy < card.cost:
		error_text = "Not enough energy to play card: %s" % card_id
		return false

	pending_hand_index = hand_index
	pending_card = card
	error_text = ""
	if _card_requires_enemy_target(card):
		phase = PHASE_SELECTING_ENEMY_TARGET
	else:
		phase = PHASE_CONFIRMING_PLAYER_TARGET
	return true

func cancel_selection() -> bool:
	if phase != PHASE_SELECTING_ENEMY_TARGET and phase != PHASE_CONFIRMING_PLAYER_TARGET:
		error_text = "There is no pending card selection to cancel."
		return false
	_clear_pending_selection()
	phase = PHASE_PLAYER_TURN
	error_text = ""
	return true

func confirm_enemy_target(enemy_index: int) -> bool:
	if phase != PHASE_SELECTING_ENEMY_TARGET:
		error_text = "Enemy target confirmation is not currently pending."
		return false
	if enemy_index < 0 or enemy_index >= state.enemies.size():
		error_text = "Enemy target index is invalid: %d" % enemy_index
		return false
	var target := state.enemies[enemy_index]
	if target.is_defeated():
		error_text = "Enemy target is already defeated: %d" % enemy_index
		return false
	return _play_pending_card(target)

func confirm_player_target() -> bool:
	if phase != PHASE_CONFIRMING_PLAYER_TARGET:
		error_text = "Player target confirmation is not currently pending."
		return false
	return _play_pending_card(state.player)

func end_player_turn() -> bool:
	error_text = ""
	if phase != PHASE_PLAYER_TURN:
		error_text = "Cannot end turn outside the player turn."
		return false
	state.discard_pile.append_array(state.hand)
	state.hand.clear()
	engine.end_turn(state)
	phase = PHASE_ENEMY_TURN
	_run_enemy_turn()
	if phase == PHASE_LOST or phase == PHASE_WON:
		return true
	_start_player_turn()
	return true

func draw_cards(count: int) -> void:
	for _i in range(max(0, count)):
		if state.draw_pile.is_empty():
			if state.discard_pile.is_empty():
				return
			state.draw_pile = _shuffle_card_ids(state.discard_pile)
			state.discard_pile.clear()
		state.hand.append(state.draw_pile.pop_back())

func _reset_runtime_state() -> void:
	state = CombatState.new()
	engine = CombatEngine.new()
	status_runtime = CombatStatusRuntime.new()
	engine.executor.status_runtime = status_runtime
	relic_runtime.reset()
	phase = PHASE_INVALID
	error_text = ""
	pending_hand_index = -1
	pending_card = null
	enemy_defs_by_id.clear()
	enemy_intent_indices.clear()
	rng = RngService.new(1)
	terminal_rewards_applied = false

func _run_enemy_turn() -> void:
	_clear_enemy_blocks()
	for enemy_index in range(state.enemies.size()):
		var enemy := state.enemies[enemy_index]
		if enemy.is_defeated():
			continue
		status_runtime.on_turn_started(enemy, state)
		if _update_terminal_phase():
			return
		if enemy.is_defeated():
			continue
		_execute_enemy_intent(enemy_index)
		if state.player.is_defeated():
			_finish_loss()
			return

func _clear_enemy_blocks() -> void:
	for enemy in state.enemies:
		if not enemy.is_defeated():
			enemy.block = 0

func _execute_enemy_intent(enemy_index: int) -> void:
	var enemy: CombatantState = state.enemies[enemy_index]
	var intent := get_enemy_intent(enemy_index)
	if intent.is_empty():
		_advance_enemy_intent(enemy_index)
		return
	if intent.begins_with("apply_status_"):
		_execute_status_intent(enemy, enemy_index, intent.trim_prefix("apply_status_"), state.player)
		return
	if intent.begins_with("self_status_"):
		_execute_status_intent(enemy, enemy_index, intent.trim_prefix("self_status_"), enemy)
		return
	var parts := intent.split("_")
	if parts.size() != 2:
		push_error("Unknown enemy intent format: %s" % intent)
		_advance_enemy_intent(enemy_index)
		return
	var amount: int = max(0, int(parts[1]))
	match String(parts[0]).to_lower():
		"attack":
			state.player.take_damage(amount)
		"block":
			enemy.gain_block(amount)
		_:
			push_error("Unknown enemy intent action: %s" % intent)
	_advance_enemy_intent(enemy_index)

func _execute_status_intent(
	enemy: CombatantState,
	enemy_index: int,
	payload: String,
	recipient: CombatantState
) -> void:
	var normalized_payload := payload
	if recipient == state.player:
		if not normalized_payload.ends_with("_player"):
			push_error("Unknown enemy status intent target: %s" % payload)
			_advance_enemy_intent(enemy_index)
			return
		normalized_payload = normalized_payload.trim_suffix("_player")
	var parsed := _parse_status_intent_payload(normalized_payload)
	if parsed.is_empty():
		push_error("Unknown enemy status intent format: %s" % payload)
		_advance_enemy_intent(enemy_index)
		return
	var effect := EffectDef.new()
	effect.effect_type = "apply_status"
	effect.status_id = String(parsed.get("status_id", ""))
	effect.amount = int(parsed.get("amount", 0))
	effect.target = "target"
	engine.executor.execute_in_state(effect, state, enemy, recipient)
	_advance_enemy_intent(enemy_index)

func _parse_status_intent_payload(payload: String) -> Dictionary:
	var amount_separator := payload.rfind("_")
	if amount_separator <= 0 or amount_separator >= payload.length() - 1:
		return {}
	var status_id := payload.substr(0, amount_separator)
	var amount_text := payload.substr(amount_separator + 1)
	if status_id.is_empty() or not amount_text.is_valid_int():
		return {}
	var amount := int(amount_text)
	if amount <= 0:
		return {}
	return {
		"status_id": status_id,
		"amount": amount,
	}

func _advance_enemy_intent(enemy_index: int) -> void:
	if enemy_index >= 0 and enemy_index < enemy_intent_indices.size():
		enemy_intent_indices[enemy_index] += 1

func _card_requires_enemy_target(card: CardDef) -> bool:
	for effect in card.effects:
		var target := effect.target.to_lower()
		if target == "enemy" or target == "target":
			return true
	return false

func _play_pending_card(target: CombatantState) -> bool:
	if pending_card == null:
		error_text = "Pending card is missing."
		return false
	if pending_hand_index < 0 or pending_hand_index >= state.hand.size():
		error_text = "Pending card hand index is invalid: %d" % pending_hand_index
		return false
	var played_card_id := state.hand[pending_hand_index]
	if played_card_id != pending_card.id:
		error_text = "Pending card no longer matches hand card: %s" % played_card_id
		return false
	if state.energy < pending_card.cost:
		error_text = "Not enough energy to play card: %s" % pending_card.id
		return false

	state.energy -= pending_card.cost
	state.hand.remove_at(pending_hand_index)
	engine.play_card_in_state(pending_card, state, state.player, target)
	_resolve_pending_draws()
	state.discard_pile.append(pending_card.id)
	_clear_pending_selection()
	error_text = ""
	if not _update_terminal_phase():
		phase = PHASE_PLAYER_TURN
	return true

func _resolve_pending_draws() -> void:
	var draw_count: int = max(0, state.pending_draw_count)
	state.pending_draw_count = 0
	draw_cards(draw_count)

func _start_player_turn() -> void:
	status_runtime.on_turn_started(state.player, state)
	if _update_terminal_phase():
		return
	_handle_relic_event("turn_started")
	_resolve_pending_draws()
	if _update_terminal_phase():
		return
	draw_cards(5)
	phase = PHASE_PLAYER_TURN

func _handle_relic_event(event_type: String) -> void:
	relic_runtime.handle_event(GameEvent.new(event_type), catalog, run, state)

func _clear_pending_selection() -> void:
	pending_hand_index = -1
	pending_card = null

func _update_terminal_phase() -> bool:
	if state.player != null and state.player.is_defeated():
		_finish_loss()
		return true
	var has_living_enemy := false
	for enemy in state.enemies:
		if not enemy.is_defeated():
			has_living_enemy = true
			break
	if not has_living_enemy and not state.enemies.is_empty():
		_finish_win()
		return true
	return false

func _finish_win() -> void:
	phase = PHASE_WON
	if run == null:
		return
	run.current_hp = state.player.current_hp
	if not terminal_rewards_applied:
		_handle_relic_event("combat_won")
		_resolve_pending_draws()
		run.gold += state.gold_delta
		terminal_rewards_applied = true

func _finish_loss() -> void:
	phase = PHASE_LOST
	if run == null:
		return
	run.current_hp = 0
	run.failed = true

func _initialize_from_run() -> void:
	var node = _find_current_node()
	if node == null:
		_set_invalid("CombatSession current map node is missing: %s" % run.current_node_id)
		return
	if run.deck_ids.is_empty():
		_set_invalid("CombatSession cannot start with an empty deck.")
		return
	var character := catalog.get_character(run.character_id)
	if character == null:
		_set_invalid("CombatSession character is missing: %s" % run.character_id)
		return

	state.player = CombatantState.new(run.character_id, max(1, run.max_hp))
	state.player.current_hp = clamp(run.current_hp, 0, state.player.max_hp)
	state.energy = 3
	state.turn = 1
	state.draw_pile = _shuffle_card_ids(run.deck_ids)

	var encounter_ids := EncounterGenerator.new().generate(catalog, run.seed_value, node.id, node.node_type)
	if encounter_ids.is_empty():
		_set_invalid("CombatSession encounter is empty for node: %s" % node.id)
		return
	for enemy_id in encounter_ids:
		var enemy_def := catalog.get_enemy(enemy_id)
		if enemy_def == null:
			_set_invalid("CombatSession enemy is missing: %s" % enemy_id)
			return
		enemy_defs_by_id[enemy_id] = enemy_def
		state.enemies.append(CombatantState.new(enemy_id, enemy_def.max_hp))
		enemy_intent_indices.append(0)

	_handle_relic_event("combat_started")
	_resolve_pending_draws()
	_start_player_turn()

func _find_current_node() -> MapNodeState:
	for candidate in run.map_nodes:
		var node := candidate as MapNodeState
		if node == null:
			continue
		if node.id == run.current_node_id:
			return node
	return null

func _shuffle_card_ids(card_ids: Array[String]) -> Array[String]:
	var shuffled: Array = rng.shuffle_copy(card_ids)
	var result: Array[String] = []
	for card_id in shuffled:
		result.append(String(card_id))
	return result

func _set_invalid(message: String) -> void:
	phase = PHASE_INVALID
	error_text = message
